import CoreMedia
import CoreVideo
import Metal
import MetalKit
import MetalPerformanceShaders
import UIKit

class MultiClassSegmentedImageRenderer {

  var description: String = "MultiClass Renderer"
  var isPrepared = false

  // Class IDs from the model (based on MediaPipe documentation)
  enum SegmentationClass: UInt8 {
    case background = 0
    case hair = 1
    case skin = 2
    case lips = 3
    case eyes = 4
    case eyebrows = 5
    // Other possible classes in the model
  }

  // Color extraction results
  struct ColorInfo {
    var skinColor: UIColor = .clear
    var hairColor: UIColor = .clear
    var skinColorHSV: (h: CGFloat, s: CGFloat, v: CGFloat) = (0, 0, 0)
    var hairColorHSV: (h: CGFloat, s: CGFloat, v: CGFloat) = (0, 0, 0)
  }

  private var lastColorInfo = ColorInfo()

  // Temporal smoothing parameters
  private let smoothingFactor: Float = 0.3
  private var frameCounter: Int = 0
  private let frameSkip = 2  // Only analyze colors every 3rd frame

  // Downsampling factor for color analysis
  private let downsampleFactor: Int = 4

  private(set) var outputFormatDescription: CMFormatDescription?
  private var outputPixelBufferPool: CVPixelBufferPool?
  private let metalDevice = MTLCreateSystemDefaultDevice()!
  private var computePipelineState: MTLComputePipelineState?

  // Memory pools for reuse
  private var textureCache: CVMetalTextureCache!
  private var downsampledTexture: MTLTexture?
  private var segmentationBuffer: MTLBuffer?
  private var prevSegmentDatas: UnsafeMutablePointer<UInt8>?
  private var prevSegmentDataSize: Int = 0

  let context: CIContext
  let textureLoader: MTKTextureLoader

  private lazy var commandQueue: MTLCommandQueue? = {
    return self.metalDevice.makeCommandQueue()
  }()

  required init() {
    let defaultLibrary = metalDevice.makeDefaultLibrary()!
    let kernelFunction = defaultLibrary.makeFunction(name: "processMultiClass")
    do {
      computePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction!)
    } catch {
      print("Could not create pipeline state: \(error)")
    }
    context = CIContext(mtlDevice: metalDevice)
    textureLoader = MTKTextureLoader(device: metalDevice)
  }

  func prepare(
    with formatDescription: CMFormatDescription,
    outputRetainedBufferCountHint: Int,
    needChangeWidthHeight: Bool = false
  ) {
    reset()

    (outputPixelBufferPool, _, outputFormatDescription) = allocateOutputBufferPool(
      with: formatDescription,
      outputRetainedBufferCountHint: outputRetainedBufferCountHint,
      needChangeWidthHeight: needChangeWidthHeight)
    if outputPixelBufferPool == nil {
      return
    }

    var metalTextureCache: CVMetalTextureCache?
    if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &metalTextureCache)
      != kCVReturnSuccess
    {
      assertionFailure("Unable to allocate texture cache")
    } else {
      textureCache = metalTextureCache
    }

    isPrepared = true
  }

  func reset() {
    outputPixelBufferPool = nil
    outputFormatDescription = nil
    textureCache = nil
    downsampledTexture = nil
    segmentationBuffer = nil

    // Free memory for previous segmentation data
    if let prevData = prevSegmentDatas {
      prevData.deallocate()
      prevSegmentDatas = nil
      prevSegmentDataSize = 0
    }

    isPrepared = false
  }

  // Helper function to create a Metal texture from a CVPixelBuffer
  private func makeTextureFromCVPixelBuffer(
    pixelBuffer: CVPixelBuffer, textureFormat: MTLPixelFormat
  ) -> MTLTexture? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)

    var cvTextureOut: CVMetalTexture?
    let result = CVMetalTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault, textureCache, pixelBuffer, nil, textureFormat, width, height, 0,
      &cvTextureOut)
    if result != kCVReturnSuccess {
      print("Error: Could not create Metal texture from pixel buffer: \(result)")
      return nil
    }
    guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
      print("Error: Could not get Metal texture from CVMetalTexture")
      return nil
    }

    return texture
  }

  // Create a downsampled texture for more efficient color analysis
  private func createDownsampledTexture(from texture: MTLTexture, scale: Int) -> MTLTexture? {
    let width = texture.width / scale
    let height = texture.height / scale

    // Reuse existing downsampled texture if possible
    if let existingTexture = downsampledTexture,
      existingTexture.width == width && existingTexture.height == height
    {
      return existingTexture
    }

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: texture.pixelFormat,
      width: width,
      height: height,
      mipmapped: false
    )
    textureDescriptor.usage = [.shaderRead, .shaderWrite]

    downsampledTexture = metalDevice.makeTexture(descriptor: textureDescriptor)
    guard let downsampledTexture = downsampledTexture else { return nil }

    // Use CPU-based downsampling to avoid Metal API issues
    downsampleTextureCPU(source: texture, destination: downsampledTexture, scale: scale)

    return downsampledTexture
  }

  // Fallback CPU method to downsample a texture
  private func downsampleTextureCPU(source: MTLTexture, destination: MTLTexture, scale: Int) {
    let srcWidth = source.width
    let srcHeight = source.height
    let dstWidth = destination.width
    let dstHeight = destination.height

    // Create byte arrays for the textures
    let bytesPerPixel = 4  // BGRA format
    let srcBytesPerRow = srcWidth * bytesPerPixel
    let dstBytesPerRow = dstWidth * bytesPerPixel
    let srcBytes = UnsafeMutablePointer<UInt8>.allocate(
      capacity: srcWidth * srcHeight * bytesPerPixel)
    let dstBytes = UnsafeMutablePointer<UInt8>.allocate(
      capacity: dstWidth * dstHeight * bytesPerPixel)

    // Create MTLRegions for copying
    let srcRegion = MTLRegionMake2D(0, 0, srcWidth, srcHeight)
    let dstRegion = MTLRegionMake2D(0, 0, dstWidth, dstHeight)

    // Get the source texture data
    source.getBytes(srcBytes, bytesPerRow: srcBytesPerRow, from: srcRegion, mipmapLevel: 0)

    // Simple box filter downsampling
    for y in 0..<dstHeight {
      for x in 0..<dstWidth {
        let srcX = x * scale
        let srcY = y * scale

        // Just take the center pixel of each block for simplicity
        let srcIndex = (srcY * srcWidth + srcX) * bytesPerPixel
        let dstIndex = (y * dstWidth + x) * bytesPerPixel

        // Copy the pixel data
        for i in 0..<bytesPerPixel {
          dstBytes[dstIndex + i] = srcBytes[srcIndex + i]
        }
      }
    }

    // Copy the downsampled data to the destination texture
    destination.replace(
      region: dstRegion, mipmapLevel: 0, withBytes: dstBytes, bytesPerRow: dstBytesPerRow)

    // Free the memory
    srcBytes.deallocate()
    dstBytes.deallocate()
  }

  // Function to allocate output buffer pool
  private func allocateOutputBufferPool(
    with formatDescription: CMFormatDescription,
    outputRetainedBufferCountHint: Int,
    needChangeWidthHeight: Bool = false
  ) -> (
    outputBufferPool: CVPixelBufferPool?,
    outputColorSpace: CGColorSpace?,
    outputFormatDescription: CMFormatDescription?
  ) {

    let inputMediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
    if inputMediaSubType != kCVPixelFormatType_32BGRA {
      assertionFailure("Invalid input pixel buffer format \(inputMediaSubType)")
      return (nil, nil, nil)
    }

    let inputDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
    var width = Int(inputDimensions.width)
    var height = Int(inputDimensions.height)
    if needChangeWidthHeight {
      let temp = width
      width = height
      height = temp
    }

    let outputPixelBufferAttributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: UInt(inputMediaSubType),
      kCVPixelBufferWidthKey as String: width,
      kCVPixelBufferHeightKey as String: height,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:],
    ]

    var pixelBufferPool: CVPixelBufferPool?
    // Create a pixel buffer pool with the same pixel attributes as the input format description.
    let poolCreateStatus = CVPixelBufferPoolCreate(
      kCFAllocatorDefault,
      nil,
      outputPixelBufferAttributes as CFDictionary,
      &pixelBufferPool)

    guard poolCreateStatus == kCVReturnSuccess else {
      assertionFailure("Pixel buffer pool creation failed \(poolCreateStatus)")
      return (nil, nil, nil)
    }

    var pixelBuffer: CVPixelBuffer?
    var outputFormatDescription: CMFormatDescription?

    // Get the format description for the output pixel buffer.
    let pixelBufferCreateStatus = CVPixelBufferPoolCreatePixelBuffer(
      kCFAllocatorDefault, pixelBufferPool!, &pixelBuffer)
    if pixelBufferCreateStatus == kCVReturnSuccess, let createdPixelBuffer = pixelBuffer {
      CVBufferSetAttachment(
        createdPixelBuffer,
        kCVImageBufferColorPrimariesKey,
        kCVImageBufferColorPrimaries_ITU_R_709_2,
        .shouldPropagate)
      CVBufferSetAttachment(
        createdPixelBuffer,
        kCVImageBufferTransferFunctionKey,
        kCVImageBufferTransferFunction_ITU_R_709_2,
        .shouldPropagate)
      CVBufferSetAttachment(
        createdPixelBuffer,
        kCVImageBufferYCbCrMatrixKey,
        kCVImageBufferYCbCrMatrix_ITU_R_709_2,
        .shouldPropagate)

      let err = CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: createdPixelBuffer,
        formatDescriptionOut: &outputFormatDescription)
      if err != 0 {
        return (nil, nil, nil)
      }
    } else {
      return (nil, nil, nil)
    }

    let inputColorSpace = CGColorSpaceCreateDeviceRGB()

    return (pixelBufferPool, inputColorSpace, outputFormatDescription)
  }

  func render(pixelBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>?) -> CVPixelBuffer? {
    guard let segmentDatas = segmentDatas, isPrepared else {
      print("segmentDatas not found or renderer not prepared")
      return nil
    }

    var newPixelBuffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool!, &newPixelBuffer)
    guard let outputPixelBuffer = newPixelBuffer else {
      print("Allocation failure: Could not get pixel buffer from pool. (\(self.description))")
      return nil
    }
    guard
      let inputTexture = makeTextureFromCVPixelBuffer(
        pixelBuffer: pixelBuffer, textureFormat: .bgra8Unorm),
      let outputTexture = makeTextureFromCVPixelBuffer(
        pixelBuffer: outputPixelBuffer, textureFormat: .bgra8Unorm)
    else {
      return nil
    }

    // Only extract colors every few frames to improve performance
    frameCounter += 1
    if frameCounter >= frameSkip {
      frameCounter = 0
      // Extract colors from downsampled image for better performance
      extractColorsOptimized(
        from: inputTexture, with: segmentDatas, width: inputTexture.width,
        height: inputTexture.height)
    }

    // Reuse or create segmentation buffer
    let bufferSize = inputTexture.width * inputTexture.height * MemoryLayout<UInt8>.size
    if segmentationBuffer == nil || segmentationBuffer?.length != bufferSize {
      segmentationBuffer = metalDevice.makeBuffer(
        bytes: segmentDatas, length: bufferSize, options: .storageModeShared)
    } else {
      // Copy data to existing buffer
      let bufferContents = segmentationBuffer!.contents()
      memcpy(bufferContents, segmentDatas, bufferSize)
    }

    // Set up command queue, buffer, and encoder.
    guard let commandQueue = commandQueue,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let commandEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      print("Failed to create a Metal command queue.")
      CVMetalTextureCacheFlush(textureCache!, 0)
      return nil
    }

    commandEncoder.label = "MultiClass Renderer"
    commandEncoder.setComputePipelineState(computePipelineState!)
    commandEncoder.setTexture(inputTexture, index: 0)
    commandEncoder.setTexture(outputTexture, index: 1)
    commandEncoder.setBuffer(segmentationBuffer, offset: 0, index: 0)
    var imageWidth: Int = Int(inputTexture.width)
    commandEncoder.setBytes(&imageWidth, length: MemoryLayout<Int>.size, index: 1)

    // Set up the thread groups.
    let width = computePipelineState!.threadExecutionWidth
    let height = computePipelineState!.maxTotalThreadsPerThreadgroup / width
    let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
    let threadgroupsPerGrid = MTLSize(
      width: (inputTexture.width + width - 1) / width,
      height: (inputTexture.height + height - 1) / height,
      depth: 1)
    commandEncoder.dispatchThreadgroups(
      threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

    commandEncoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    return outputPixelBuffer
  }

  // Optimized color extraction using downsampling and shared memory
  private func extractColorsOptimized(
    from texture: MTLTexture, with segmentMask: UnsafePointer<UInt8>, width: Int, height: Int
  ) {
    // Create a downsampled version of the texture for color analysis
    guard let downsampledTexture = createDownsampledTexture(from: texture, scale: downsampleFactor)
    else {
      return
    }

    let dsWidth = downsampledTexture.width
    let dsHeight = downsampledTexture.height

    // Create a temporary buffer to store the downsampled texture data
    let bytesPerRow = dsWidth * 4  // BGRA format = 4 bytes per pixel
    let bufferSize = dsHeight * bytesPerRow

    guard
      let textureBuffer = metalDevice.makeBuffer(length: bufferSize, options: .storageModeShared)
    else {
      return
    }

    // Copy the downsampled texture to the buffer
    let commandBuffer = commandQueue?.makeCommandBuffer()
    let blitEncoder = commandBuffer?.makeBlitCommandEncoder()

    // Use safe parameters for the blit operation that match the actual sizes
    let sourceSize = MTLSizeMake(dsWidth, dsHeight, 1)

    blitEncoder?.copy(
      from: downsampledTexture,
      sourceSlice: 0,
      sourceLevel: 0,
      sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
      sourceSize: sourceSize,
      to: textureBuffer,
      destinationOffset: 0,
      destinationBytesPerRow: bytesPerRow,
      destinationBytesPerImage: bufferSize)

    blitEncoder?.endEncoding()
    commandBuffer?.commit()
    commandBuffer?.waitUntilCompleted()

    // Analyze the pixel data from the buffer
    let pixelData = textureBuffer.contents().bindMemory(to: UInt8.self, capacity: bufferSize)

    // Accumulators for color values
    var skinPixelCount: Int = 0
    var skinR: Float = 0.0
    var skinG: Float = 0.0
    var skinB: Float = 0.0

    var hairPixelCount: Int = 0
    var hairR: Float = 0.0
    var hairG: Float = 0.0
    var hairB: Float = 0.0

    // Stride for sampling segmentation mask (scaling from downsampled to original)
    let strideX = width / dsWidth
    let strideY = height / dsHeight

    // Process the downsampled image
    for y in 0..<dsHeight {
      for x in 0..<dsWidth {
        // Get corresponding index in full segmentation mask
        let segY = min(y * strideY, height - 1)
        let segX = min(x * strideX, width - 1)
        let segIndex = segY * width + segX
        let segmentClass = segmentMask[segIndex]

        // Get pixel from downsampled texture
        let pixelOffset = (y * dsWidth + x) * 4

        // BGRA format
        let b = Float(pixelData[pixelOffset])
        let g = Float(pixelData[pixelOffset + 1])
        let r = Float(pixelData[pixelOffset + 2])

        if segmentClass == SegmentationClass.skin.rawValue {
          skinR += r
          skinG += g
          skinB += b
          skinPixelCount += 1
        } else if segmentClass == SegmentationClass.hair.rawValue {
          hairR += r
          hairG += g
          hairB += b
          hairPixelCount += 1
        }
      }
    }

    var colorInfo = ColorInfo()

    // Apply temporal smoothing to color values for stability
    if skinPixelCount > 0 {
      let avgR = skinR / Float(skinPixelCount)
      let avgG = skinG / Float(skinPixelCount)
      let avgB = skinB / Float(skinPixelCount)

      let newSkinColor = UIColor(
        red: CGFloat(avgR / 255.0), green: CGFloat(avgG / 255.0), blue: CGFloat(avgB / 255.0),
        alpha: 1.0)

      // Temporal smoothing for stable color values
      if lastColorInfo.skinColor != .clear {
        colorInfo.skinColor = blendColors(
          newColor: newSkinColor, oldColor: lastColorInfo.skinColor, factor: smoothingFactor)
      } else {
        colorInfo.skinColor = newSkinColor
      }

      // Convert to HSV
      var hue: CGFloat = 0
      var saturation: CGFloat = 0
      var brightness: CGFloat = 0

      colorInfo.skinColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
      colorInfo.skinColorHSV = (hue, saturation, brightness)
    } else {
      colorInfo.skinColor = lastColorInfo.skinColor
      colorInfo.skinColorHSV = lastColorInfo.skinColorHSV
    }

    if hairPixelCount > 0 {
      let avgR = hairR / Float(hairPixelCount)
      let avgG = hairG / Float(hairPixelCount)
      let avgB = hairB / Float(hairPixelCount)

      let newHairColor = UIColor(
        red: CGFloat(avgR / 255.0), green: CGFloat(avgG / 255.0), blue: CGFloat(avgB / 255.0),
        alpha: 1.0)

      // Temporal smoothing for stable color values
      if lastColorInfo.hairColor != .clear {
        colorInfo.hairColor = blendColors(
          newColor: newHairColor, oldColor: lastColorInfo.hairColor, factor: smoothingFactor)
      } else {
        colorInfo.hairColor = newHairColor
      }

      // Convert to HSV
      var hue: CGFloat = 0
      var saturation: CGFloat = 0
      var brightness: CGFloat = 0

      colorInfo.hairColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
      colorInfo.hairColorHSV = (hue, saturation, brightness)
    } else {
      colorInfo.hairColor = lastColorInfo.hairColor
      colorInfo.hairColorHSV = lastColorInfo.hairColorHSV
    }

    // If we have valid data, update the lastColorInfo
    if skinPixelCount > 0 || hairPixelCount > 0 {
      lastColorInfo = colorInfo
    }
  }

  // Helper method to blend colors for temporal smoothing
  private func blendColors(newColor: UIColor, oldColor: UIColor, factor: Float) -> UIColor {
    let factor = CGFloat(factor)

    var newR: CGFloat = 0
    var newG: CGFloat = 0
    var newB: CGFloat = 0
    var newA: CGFloat = 0
    var oldR: CGFloat = 0
    var oldG: CGFloat = 0
    var oldB: CGFloat = 0
    var oldA: CGFloat = 0

    newColor.getRed(&newR, green: &newG, blue: &newB, alpha: &newA)
    oldColor.getRed(&oldR, green: &oldG, blue: &oldB, alpha: &oldA)

    // Blend using exponential moving average
    let r = oldR * (1 - factor) + newR * factor
    let g = oldG * (1 - factor) + newG * factor
    let b = oldB * (1 - factor) + newB * factor
    let a = oldA * (1 - factor) + newA * factor

    return UIColor(red: r, green: g, blue: b, alpha: a)
  }

  // Get the current color information
  func getCurrentColorInfo() -> ColorInfo {
    return lastColorInfo
  }
}
