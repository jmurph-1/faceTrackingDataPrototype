// swiftlint:disable identifier_name type_body_length
import CoreMedia
import CoreVideo
import Metal
import MetalKit
import MetalPerformanceShaders
import UIKit
import MediaPipeTasksVision

class MultiClassSegmentedImageRenderer {

  var description: String = "MultiClass Renderer"
  var isPrepared = false
    
    private var downsampleComputePipelineState: MTLComputePipelineState?

  // Define image segmenter result for internal use
  struct ImageSegmenterResult {
    let categoryMask: UnsafePointer<UInt8>?
    let width: Int
    let height: Int
  }

  // Result structure for rendering with Metal texture-based drawing
  struct Result {
    let size: CGSize
    let imageSegmenterResult: ImageSegmenterResult?
  }

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
        
        // Create a new texture with a different variable name to avoid shadowing
        let newDownsampledTexture = metalDevice.makeTexture(descriptor: textureDescriptor)
        
        // Fix the guard statement to use the new variable name
        guard let newDownsampledTexture = newDownsampledTexture else {
            print("Failed to create downsampled texture")
            return nil
        }
        
        // Store the new texture in the class property
        downsampledTexture = newDownsampledTexture
        
        // Use compute shader for downsampling instead of CPU-based method
        // This properly handles the dimension scaling that was causing the blitEncoder error
        let commandBuffer = commandQueue?.makeCommandBuffer()
        
        // Create a compute encoder for the downsampling operation
        guard let computeEncoder = commandBuffer?.makeComputeCommandEncoder() else {
            print("Failed to create compute encoder")
            return nil
        }
        
        // Set up the compute pipeline state for downsampling
        // This would need to be created once and stored as a property
        if downsampleComputePipelineState == nil {
            let defaultLibrary = metalDevice.makeDefaultLibrary()
            let kernelFunction = defaultLibrary?.makeFunction(name: "downsampleTexture")
            
            if kernelFunction == nil {
                // If the function doesn't exist in the library, we need to create it
                let kernelSource = """
                #include <metal_stdlib>
                using namespace metal;
                
                kernel void downsampleTexture(
                    texture2d<float, access::read> sourceTexture [[texture(0)]],
                    texture2d<float, access::write> destinationTexture [[texture(1)]],
                    uint2 gid [[thread_position_in_grid]],
                    constant int &scale [[buffer(0)]])
                {
                    // Ensure we're within the destination texture bounds
                    if (gid.x >= destinationTexture.get_width() || gid.y >= destinationTexture.get_height()) {
                        return;
                    }
                    
                    // Calculate the corresponding position in the source texture
                    uint2 sourcePos = gid * scale;
                    
                    // Read the source pixel
                    float4 color = sourceTexture.read(sourcePos);
                    
                    // Write to the destination texture
                    destinationTexture.write(color, gid);
                }
                """
                
                // Create a new library with our kernel
                let options = MTLCompileOptions()
                options.languageVersion = .version2_0
                
                do {
                    let library = try metalDevice.makeLibrary(source: kernelSource, options: options)
                    let downsampleFunction = library.makeFunction(name: "downsampleTexture")
                    downsampleComputePipelineState = try metalDevice.makeComputePipelineState(function: downsampleFunction!)
                } catch {
                    print("Failed to create downsample pipeline: \\(error)")
                    return nil
                }
            } else {
                do {
                    downsampleComputePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction!)
                } catch {
                    print("Failed to create downsample pipeline: \\(error)")
                    return nil
                }
            }
        }
        
        guard let pipelineState = downsampleComputePipelineState else {
            print("Downsample pipeline state is nil")
            return nil
        }
        
        // Set up the compute encoder
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setTexture(newDownsampledTexture, index: 1)
        
        // Pass the scale factor to the shader
        var scaleFactor = scale
        computeEncoder.setBytes(&scaleFactor, length: MemoryLayout<Int>.size, index: 0)
        
        // Calculate threadgroup size
        let threadgroupSize = MTLSize(
            width: 16,
            height: 16,
            depth: 1
        )
        
        let threadgroupCount = MTLSize(
            width: (width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        // Dispatch the compute encoder
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        // Commit the command buffer
        commandBuffer?.commit()
        
        return newDownsampledTexture
    }
    // Add cleanup method to recycle the downsampled texture
    private func recycleDownsampledTexture() {
        if let texture = downsampledTexture {
            TexturePoolManager.shared.recycleTexture(texture)
            downsampledTexture = nil
        }
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

  // Check if GPU processing is available
  private func isGPUProcessingAvailable() -> Bool {
    return computePipelineState != nil && commandQueue != nil && metalDevice.supportsFeatureSet(.iOS_GPUFamily2_v1)
  }

  // CPU fallback for processing when GPU is unavailable
  private func processFallbackCPU(inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>) {
    CVPixelBufferLockBaseAddress(inputBuffer, CVPixelBufferLockFlags(rawValue: 0))
    CVPixelBufferLockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    let width = CVPixelBufferGetWidth(inputBuffer)
    let height = CVPixelBufferGetHeight(inputBuffer)
    
    let sourceData = CVPixelBufferGetBaseAddress(inputBuffer)!
    let destData = CVPixelBufferGetBaseAddress(outputBuffer)!
    let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(inputBuffer)
    let destBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
    
    // Simple CPU-based processing
    for row in 0..<height {
      let sourceRowPtr = sourceData.advanced(by: row * sourceBytesPerRow)
      let destRowPtr = destData.advanced(by: row * destBytesPerRow)
      
      for col in 0..<width {
        let pixelOffset = col * 4  // BGRA format (4 bytes per pixel)
        let segmentClass = segmentDatas[row * width + col]
        
        // Get source pixel
        let srcPixel = sourceRowPtr.advanced(by: pixelOffset)
        let destPixel = destRowPtr.advanced(by: pixelOffset)
        
        // Copy the original pixel
        memcpy(destPixel, srcPixel, 4)
        
        // Apply simple visual effect based on segment class
        if segmentClass > 0 {  // Not background
          // Add a visual effect (e.g., tint) based on segment class
          switch segmentClass {
          case SegmentationClass.hair.rawValue:
            // Subtle hair highlight
            let destBGRA = destPixel.bindMemory(to: UInt8.self, capacity: 4)
            destBGRA[2] = min(255, destBGRA[2] + 20)  // Increase red channel
          case SegmentationClass.skin.rawValue:
            // Subtle skin smoothing (simplified)
            let destBGRA = destPixel.bindMemory(to: UInt8.self, capacity: 4)
            destBGRA[1] = min(255, destBGRA[1] + 10)  // Increase green channel
          default:
            break
          }
        }
      }
    }
    
    CVPixelBufferUnlockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
    CVPixelBufferUnlockBaseAddress(inputBuffer, CVPixelBufferLockFlags(rawValue: 0))
  }

  // Updated method to handle all the different render signature types
  // This is the version being called from CameraViewController
  func render(pixelBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>) -> CVPixelBuffer? {
    // Log dimensions for debugging
    let pixelBufferWidth = CVPixelBufferGetWidth(pixelBuffer)
    let pixelBufferHeight = CVPixelBufferGetHeight(pixelBuffer)
    print("Render input dimensions: \(pixelBufferWidth)x\(pixelBufferHeight)")
    
    // Create a Result object from the parameters
    let result = Result(
      size: CGSize(width: pixelBufferWidth, height: pixelBufferHeight),
      imageSegmenterResult: ImageSegmenterResult(
        categoryMask: segmentDatas,
        width: pixelBufferWidth,
        height: pixelBufferHeight
      )
    )
    
    // Check if we need to re-prepare the renderer because of format changes
    if isPrepared {
      // Check if dimensions have changed
      if let outputDesc = outputFormatDescription {
        let outputDimensions = CMVideoFormatDescriptionGetDimensions(outputDesc)
        if Int(outputDimensions.width) != pixelBufferWidth || Int(outputDimensions.height) != pixelBufferHeight {
          print("Dimension mismatch: output (\(outputDimensions.width)x\(outputDimensions.height)) vs input (\(pixelBufferWidth)x\(pixelBufferHeight)). Re-preparing renderer.")
          
          // Create a new format description from the current pixel buffer
          var newFormatDesc: CMFormatDescription?
          let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &newFormatDesc)
          
          if status == 0, let desc = newFormatDesc {
            // Re-prepare with new format
            prepare(with: desc, outputRetainedBufferCountHint: 3)
          } else {
            print("Failed to create new format description: \(status)")
            isPrepared = false
          }
        }
      }
    }
    
    // Only continue if we're properly prepared
    guard isPrepared else {
      print("MultiClassSegmentedImageRenderer not prepared")
      return nil
    }
    
    var outputPixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBuffer(
      kCFAllocatorDefault, outputPixelBufferPool!, &outputPixelBuffer)
    
    if status != kCVReturnSuccess {
      print("Cannot get pixel buffer from the pool. Status: \(status)")
      return nil
    }
    
    guard let outputBuffer = outputPixelBuffer else {
      print("Failed to get output pixel buffer")
      return nil
    }
    
    // Verify output dimensions
    let outputWidth = CVPixelBufferGetWidth(outputBuffer)
    let outputHeight = CVPixelBufferGetHeight(outputBuffer)
    print("Output buffer dimensions: \(outputWidth)x\(outputHeight)")
    
    // Check for dimension mismatch
    if outputWidth != pixelBufferWidth || outputHeight != pixelBufferHeight {
      print("ERROR: Critical dimension mismatch between input and output buffers!")
      return nil
    }
    
    // Check if GPU processing is available
    if isGPUProcessingAvailable() {
      // Try GPU processing
      if !processWithGPU(inputBuffer: pixelBuffer, outputBuffer: outputBuffer, segmentDatas: segmentDatas, width: pixelBufferWidth, height: pixelBufferHeight) {
        // Fall back to CPU if GPU processing fails
        print("GPU processing failed, falling back to CPU")
        processFallbackCPU(inputBuffer: pixelBuffer, outputBuffer: outputBuffer, segmentDatas: segmentDatas)
      }
    } else {
      // Use CPU processing directly
      print("GPU processing not available, using CPU")
      processFallbackCPU(inputBuffer: pixelBuffer, outputBuffer: outputBuffer, segmentDatas: segmentDatas)
    }
    
    // Extract and display color information (using a less CPU-intensive approach)
    if frameCounter % frameSkip == 0 {
      extractColorInformation(from: result.imageSegmenterResult!, pixelBuffer: pixelBuffer)
    }
    frameCounter += 1
    
    return outputBuffer
  }

  // Process using GPU
  private func processWithGPU(inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>, width: Int, height: Int) -> Bool {
    // Prevent processing of extremely large buffers that could cause memory issues
    if width * height > 4_000_000 { // 4 megapixels max
      print("Buffer too large for GPU processing: \(width)x\(height)")
      return false
    }
    
    // Flush the texture cache to clear any lingering textures
    CVMetalTextureCacheFlush(textureCache!, 0)
    
    // Create Metal textures from pixel buffers
    guard let inputTexture = makeTextureFromCVPixelBuffer(pixelBuffer: inputBuffer, textureFormat: .bgra8Unorm),
          let outputTexture = makeTextureFromCVPixelBuffer(pixelBuffer: outputBuffer, textureFormat: .bgra8Unorm) else {
      print("Failed to create Metal textures from pixel buffers")
      return false
    }
    
    // Set up command queue, buffer, and encoder
    guard let commandQueue = commandQueue,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
      print("Failed to create a Metal command queue or encoder")
      CVMetalTextureCacheFlush(textureCache!, 0)
      return false
    }
    
    do {
      // Set up compute pipeline with kernel function
      commandEncoder.label = "MultiClass Segmentation"
      commandEncoder.setComputePipelineState(computePipelineState!)
      commandEncoder.setTexture(inputTexture, index: 0)
      commandEncoder.setTexture(outputTexture, index: 1)
      
      // Create the buffer for segmentation data
      let buffer = metalDevice.makeBuffer(bytes: segmentDatas, length: width * height * MemoryLayout<UInt8>.size)!
      commandEncoder.setBuffer(buffer, offset: 0, index: 0)
      
      // Pass the width as a parameter to the kernel function
      var imageWidth: Int = Int(width)
      commandEncoder.setBytes(&imageWidth, length: MemoryLayout<Int>.size, index: 1)
      
      // Set up the thread groups for the compute shader
      let threadExecutionWidth = computePipelineState!.threadExecutionWidth
      let threadsPerGroupHeight = computePipelineState!.maxTotalThreadsPerThreadgroup / threadExecutionWidth
      let threadsPerThreadgroup = MTLSizeMake(threadExecutionWidth, threadsPerGroupHeight, 1)
      let threadgroupsPerGrid = MTLSize(
        width: (inputTexture.width + threadExecutionWidth - 1) / threadExecutionWidth,
        height: (inputTexture.height + threadsPerGroupHeight - 1) / threadsPerGroupHeight,
        depth: 1
      )
      
      // Dispatch thread groups
      commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
      commandEncoder.endEncoding()
      
      // Commit the command buffer and wait for it to complete
      commandBuffer.commit()
      commandBuffer.waitUntilCompleted()
      
      if commandBuffer.status == .completed {
        return true
      } else {
        print("Metal command buffer execution failed with status: \(commandBuffer.status)")
        return false
      }
    } catch {
      print("Exception during GPU processing: \(error)")
      return false
    }
  }

  // Metal-based rendering implementation (for future use)
  func render(result: Result) -> MTLTexture {
    let width = Int(result.size.width)
    let height = Int(result.size.height)
    
    // Create a texture descriptor
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm,
      width: width,
      height: height,
      mipmapped: false)
    textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
    
    guard let texture = metalDevice.makeTexture(descriptor: textureDescriptor) else {
      fatalError("Failed to create texture")
    }
    
    // Create a render pass descriptor
    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].storeAction = .store
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    
    // Create command buffer and encoder
    guard let commandBuffer = commandQueue?.makeCommandBuffer(),
          let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
      return texture
    }
    
    // Set up rendering
    renderEncoder.endEncoding()
    
    // Process the segmentation texture if available
    if let segmenterResult = result.imageSegmenterResult,
       let categoryMask = segmenterResult.categoryMask {
        
      // Process the mask data and draw it to the texture
      // This is simplified - would need to be expanded in real implementation
      
      // Extract color information for UI display
      if frameCounter % frameSkip == 0 {
        extractColorInformation(from: segmenterResult, pixelBuffer: nil)
      }
      frameCounter += 1
    }
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    return texture
  }
  
  // Optimized color extraction using downsampling and shared memory
  private func extractColorsOptimized(
    from texture: MTLTexture, with segmentMask: UnsafePointer<UInt8>, width: Int, height: Int
  ) {
    // Use a reduced sample size to minimize memory usage
    let reducedScale = max(downsampleFactor, 8) // At least 8x downsampling for color analysis
    
    // Create a downsampled version of the texture for color analysis
    guard let downsampledTexture = createDownsampledTexture(from: texture, scale: reducedScale)
    else {
      return
    }

    let dsWidth = downsampledTexture.width
    let dsHeight = downsampledTexture.height

    // Create a temporary buffer to store the downsampled texture data
    let bytesPerRow = dsWidth * 4  // BGRA format = 4 bytes per pixel
    let bufferSize = dsHeight * bytesPerRow

    // Check if buffer size is reasonable (prevent massive allocations)
    if bufferSize > 1_048_576 { // Limit to 1MB
      print("Texture buffer would be too large: \(bufferSize) bytes, skipping color analysis")
      return
    }

    guard
      let textureBuffer = metalDevice.makeBuffer(length: bufferSize, options: .storageModeShared)
    else {
      return
    }

    // Create a small, reusable command buffer
    guard let commandBuffer = commandQueue?.makeCommandBuffer(),
          let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
      return
    }

    // Use safe parameters for the blit operation that match the actual sizes
    let sourceSize = MTLSizeMake(dsWidth, dsHeight, 1)

    blitEncoder.copy(
      from: downsampledTexture,
      sourceSlice: 0,
      sourceLevel: 0,
      sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
      sourceSize: sourceSize,
      to: textureBuffer,
      destinationOffset: 0,
      destinationBytesPerRow: bytesPerRow,
      destinationBytesPerImage: bufferSize)

    blitEncoder.endEncoding()
    commandBuffer.commit()
    
    // Don't wait for completion - just process what we have
    // This prevents blocking and allows for better GPU utilization

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

    var newR: CGFloat = 0.0
    var newG: CGFloat = 0.0
    var newB: CGFloat = 0.0
    var newA: CGFloat = 0.0
    var oldR: CGFloat = 0.0
    var oldG: CGFloat = 0.0
    var oldB: CGFloat = 0.0
    var oldA: CGFloat = 0.0

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

  // Get the face bounding box from segmentation data
  func getFaceBoundingBox() -> CGRect? {
    // This is a simple implementation that returns a default bounding box
    // In a real implementation, this would analyze the segmentation mask to find facial features
    
    // If no skin color has been detected, we probably don't have a valid face
    if lastColorInfo.skinColor == UIColor.clear {
      return nil
    }
    
    // Return a default bounding box in the center of the frame
    // This is a placeholder - in a real implementation, this would be calculated from the segmentation mask
    let defaultWidth = 0.5
    let defaultHeight = 0.6
    let x = (1.0 - defaultWidth) / 2.0
    let y = (1.0 - defaultHeight) / 2.0
    
    return CGRect(x: x, y: y, width: defaultWidth, height: defaultHeight)
  }

  // Process segmentation results to extract color information
  private func extractColorInformation(from segmenterResult: ImageSegmenterResult, pixelBuffer: CVPixelBuffer? = nil) {
    // If we have both a pixel buffer and category mask, use optimized extraction
    if let pixelBuffer = pixelBuffer, 
       let categoryMask = segmenterResult.categoryMask {
      
      // Create a Metal texture from the pixel buffer
      if let texture = makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer, textureFormat: .bgra8Unorm) {
        // Use the optimized color extraction method
        extractColorsOptimized(
          from: texture, 
          with: categoryMask, 
          width: segmenterResult.width, 
          height: segmenterResult.height
        )
        return
      }
    }
    
    // Fallback to placeholder colors if we can't do the optimized extraction
    // Sample skin color
    let sampleSkinColor = UIColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1.0)
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    sampleSkinColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    
    // Sample hair color
    let sampleHairColor = UIColor(red: 0.2, green: 0.1, blue: 0.05, alpha: 1.0)
    var hh: CGFloat = 0, sh: CGFloat = 0, bh: CGFloat = 0, ah: CGFloat = 0
    sampleHairColor.getHue(&hh, saturation: &sh, brightness: &bh, alpha: &ah)
    
    // Update the color info
    lastColorInfo.skinColor = sampleSkinColor
    lastColorInfo.hairColor = sampleHairColor
    lastColorInfo.skinColorHSV = (h: h, s: s, v: b)
    lastColorInfo.hairColorHSV = (h: hh, s: sh, v: bh)
  }
}
