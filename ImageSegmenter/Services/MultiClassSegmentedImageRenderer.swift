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
  
  enum LogLevel: Int {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    case verbose = 5
  }
  
  // Current log level - set to info by default
  private var logLevel: LogLevel = .info

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
  private let logFrameInterval = 30  // Only log every 30th frame

  // Downsampling factor for color analysis
  private let downsampleFactor: Int = 4

  private(set) var outputFormatDescription: CMFormatDescription?
  private var outputPixelBufferPool: CVPixelBufferPool?
  private let metalDevice = MTLCreateSystemDefaultDevice()!
  private var computePipelineState: MTLComputePipelineState?
  private var downsampleComputePipelineState: MTLComputePipelineState?

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
      log("Could not create pipeline state: \(error)", level: .error)
    }
    context = CIContext(mtlDevice: metalDevice)
    textureLoader = MTKTextureLoader(device: metalDevice)
  }
  
  func setLogLevel(_ level: LogLevel) {
    logLevel = level
  }
  
  private func log(_ message: String, level: LogLevel) {
    if level.rawValue <= logLevel.rawValue {
      print(message)
    }
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
    
    if let texture = downsampledTexture {
      TexturePoolManager.shared.recycleTexture(texture)
    }
    downsampledTexture = nil
    
    if let buffer = segmentationBuffer {
      BufferPoolManager.shared.recycleBuffer(buffer)
    }
    segmentationBuffer = nil

    // Free memory for previous segmentation data
    if let prevData = prevSegmentDatas {
      prevData.deallocate()
      prevSegmentDatas = nil
      prevSegmentDataSize = 0
    }

    isPrepared = false
  }
  
  func handleMemoryWarning() {
    log("Handling memory warning in MultiClassSegmentedImageRenderer", level: .warning)
    
    // Recycle the downsampled texture
    if let texture = downsampledTexture {
      TexturePoolManager.shared.recycleTexture(texture)
      downsampledTexture = nil
    }
    
    if let buffer = segmentationBuffer {
      BufferPoolManager.shared.recycleBuffer(buffer)
      segmentationBuffer = nil
    }
    
    TexturePoolManager.shared.clearPool()
    BufferPoolManager.shared.clearPool()
    PixelBufferPoolManager.shared.clearPools()
    
    if textureCache != nil {
      CVMetalTextureCacheFlush(textureCache, 0)
    }
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

    let newDownsampledTexture = TexturePoolManager.shared.getTexture(
      pixelFormat: texture.pixelFormat,
      width: width,
      height: height,
      usage: [.shaderRead, .shaderWrite],
      device: metalDevice
    )
    
    downsampledTexture = newDownsampledTexture
    
    guard let newDownsampledTexture = newDownsampledTexture else { 
      log("Failed to create downsampled texture", level: .error)
      return nil 
    }
    
    // Set up the compute shader for downsampling
    if downsampleComputePipelineState == nil {
      let defaultLibrary = metalDevice.makeDefaultLibrary()
      let kernelFunction = defaultLibrary?.makeFunction(name: "downsampleTexture")
      
      if kernelFunction == nil {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        kernel void downsampleTexture(
            texture2d<float, access::read> sourceTexture [[texture(0)]],
            texture2d<float, access::write> destinationTexture [[texture(1)]],
            uint2 gid [[thread_position_in_grid]],
            constant int &scale [[buffer(0)]])
        {
            if (gid.x >= destinationTexture.get_width() || gid.y >= destinationTexture.get_height()) {
                return;
            }
            
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
          log("Failed to create downsample pipeline: \(error)", level: .error)
          return nil
        }
      } else {
        do {
          downsampleComputePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction!)
        } catch {
          log("Failed to create downsample pipeline: \(error)", level: .error)
          return nil
        }
      }
    }
    
    guard let pipelineState = downsampleComputePipelineState else {
      log("Downsample pipeline state is nil", level: .error)
      return nil
    }
    
    // Create a command buffer for the downsampling operation
    guard let commandBuffer = commandQueue?.makeCommandBuffer(),
          let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
      log("Failed to create compute encoder", level: .error)
      return nil
    }
    
    // Set up the compute encoder
    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setTexture(texture, index: 0)
    computeEncoder.setTexture(newDownsampledTexture, index: 1)
    
    // Pass the scale factor to the shader
    var scaleFactor = scale
    computeEncoder.setBytes(&scaleFactor, length: MemoryLayout<Int>.size, index: 0)
    
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
    commandBuffer.commit()
    
    return newDownsampledTexture
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
    // Create a Result object from the parameters
    let pixelBufferWidth = CVPixelBufferGetWidth(pixelBuffer)
    let pixelBufferHeight = CVPixelBufferGetHeight(pixelBuffer)
    
    if frameCounter % logFrameInterval == 0 {
      log("Rendering segmentation for buffer: \(pixelBufferWidth)x\(pixelBufferHeight)", level: .info)
      log("Render input dimensions: \(pixelBufferWidth)x\(pixelBufferHeight)", level: .debug)
      log("Output buffer dimensions: \(pixelBufferWidth)x\(pixelBufferHeight)", level: .debug)
      log("Video buffer dimensions: \(pixelBufferWidth)x\(pixelBufferHeight)", level: .debug)
    }
    
    let result = Result(
      size: CGSize(width: pixelBufferWidth, height: pixelBufferHeight),
      imageSegmenterResult: ImageSegmenterResult(
        categoryMask: segmentDatas,
        width: pixelBufferWidth,
        height: pixelBufferHeight
      )
    )
    
    // Only continue if we're properly prepared
    guard isPrepared else {
      log("MultiClassSegmentedImageRenderer not prepared", level: .error)
      return nil
    }
    
    var outputPixelBuffer: CVPixelBuffer?
    
    outputPixelBuffer = PixelBufferPoolManager.shared.getPixelBuffer(
      width: pixelBufferWidth,
      height: pixelBufferHeight
    )
    
    // Fall back to the standard pool if needed
    if outputPixelBuffer == nil {
      let status = CVPixelBufferPoolCreatePixelBuffer(
        kCFAllocatorDefault, outputPixelBufferPool!, &outputPixelBuffer)
      
      if status != kCVReturnSuccess {
        log("Cannot get pixel buffer from the pool. Status: \(status)", level: .error)
        return nil
      }
    }
    
    guard let outputBuffer = outputPixelBuffer else {
      log("Failed to get output pixel buffer", level: .error)
      return nil
    }
    
    // Check if GPU processing is available
    if isGPUProcessingAvailable() {
      // Try GPU processing
      if !processWithGPU(inputBuffer: pixelBuffer, outputBuffer: outputBuffer, segmentDatas: segmentDatas, width: pixelBufferWidth, height: pixelBufferHeight) {
        // Fall back to CPU if GPU processing fails
        log("GPU processing failed, falling back to CPU", level: .warning)
        processFallbackCPU(inputBuffer: pixelBuffer, outputBuffer: outputBuffer, segmentDatas: segmentDatas)
      }
    } else {
      // Use CPU processing directly
      log("GPU processing not available, using CPU", level: .warning)
      processFallbackCPU(inputBuffer: pixelBuffer, outputBuffer: outputBuffer, segmentDatas: segmentDatas)
    }
    
    // Extract and display color information (using a less CPU-intensive approach)
    if frameCounter % frameSkip == 0 {
      extractColorInformation(from: result.imageSegmenterResult!)
    }
    frameCounter += 1
    
    return outputBuffer
  }

  // Process using GPU
  private func processWithGPU(inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>, width: Int, height: Int) -> Bool {
    // Create Metal textures from pixel buffers
    guard let inputTexture = makeTextureFromCVPixelBuffer(pixelBuffer: inputBuffer, textureFormat: .bgra8Unorm),
          let outputTexture = makeTextureFromCVPixelBuffer(pixelBuffer: outputBuffer, textureFormat: .bgra8Unorm) else {
      log("Failed to create Metal textures from pixel buffers", level: .error)
      return false
    }
    
    // Set up command queue, buffer, and encoder
    guard let commandQueue = commandQueue,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
      log("Failed to create a Metal command queue or encoder", level: .error)
      CVMetalTextureCacheFlush(textureCache!, 0)
      return false
    }
    
    do {
      // Set up compute pipeline with kernel function
      commandEncoder.label = "MultiClass Segmentation"
      commandEncoder.setComputePipelineState(computePipelineState!)
      commandEncoder.setTexture(inputTexture, index: 0)
      commandEncoder.setTexture(outputTexture, index: 1)
      
      let bufferSize = width * height * MemoryLayout<UInt8>.size
      let segBuffer: MTLBuffer
      
      if let pooledBuffer = BufferPoolManager.shared.getBuffer(length: bufferSize, options: .storageModeShared) {
        // Copy the segmentation data to the pooled buffer
        memcpy(pooledBuffer.contents(), segmentDatas, bufferSize)
        segBuffer = pooledBuffer
      } else {
        // Fall back to creating a new buffer if the pool is empty
        guard let newBuffer = metalDevice.makeBuffer(bytes: segmentDatas, length: bufferSize) else {
          log("Failed to create segmentation buffer", level: .error)
          return false
        }
        segBuffer = newBuffer
      }
      
      segmentationBuffer = segBuffer
      
      commandEncoder.setBuffer(segBuffer, offset: 0, index: 0)
      
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
      
      commandBuffer.addCompletedHandler { [weak self] buffer in
        // Recycle the segmentation buffer when done
        if let segBuffer = self?.segmentationBuffer {
          BufferPoolManager.shared.recycleBuffer(segBuffer)
          self?.segmentationBuffer = nil
        }
        
        if buffer.status != .completed {
          self?.log("Metal command buffer execution failed with status: \(buffer.status)", level: .error)
        }
      }
      
      // Commit the command buffer
      commandBuffer.commit()
      
      return true
    } catch {
      log("Exception during GPU processing: \(error)", level: .error)
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
        extractColorInformation(from: segmenterResult)
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
    
    guard let textureBuffer = BufferPoolManager.shared.getBuffer(
      length: bufferSize,
      options: .storageModeShared
    ) else {
      // Recycle the downsampled texture before returning
      TexturePoolManager.shared.recycleTexture(downsampledTexture)
      log("Failed to get buffer from pool", level: .error)
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
    
    commandBuffer?.addCompletedHandler { [weak self] _ in
      guard let self = self else {
        BufferPoolManager.shared.recycleBuffer(textureBuffer)
        TexturePoolManager.shared.recycleTexture(downsampledTexture)
        return
      }
      
      // Analyze the pixel data from the buffer
      let pixelData = textureBuffer.contents().bindMemory(to: UInt8.self, capacity: bufferSize)
      
      var skinPixels = [(r: Float, g: Float, b: Float)]()
      skinPixels.reserveCapacity(dsWidth * dsHeight / 4) // Estimate capacity
      
      var hairPixels = [(r: Float, g: Float, b: Float)]()
      hairPixels.reserveCapacity(dsWidth * dsHeight / 4) // Estimate capacity
      
      // Stride for sampling segmentation mask (scaling from downsampled to original)
      let strideX = width / dsWidth
      let strideY = height / dsHeight
      
      // Process the downsampled image - optimize by processing in chunks
      let chunkSize = 16 // Process 16 pixels at a time
      
      for y in 0..<dsHeight {
        var x = 0
        while x < dsWidth {
          let remainingPixels = dsWidth - x
          let pixelsToProcess = min(chunkSize, remainingPixels)
          
          for i in 0..<pixelsToProcess {
            // Get corresponding index in full segmentation mask
            let segY = min(y * strideY, height - 1)
            let segX = min((x + i) * strideX, width - 1)
            let segIndex = segY * width + segX
            let segmentClass = segmentMask[segIndex]
            
            // Get pixel from downsampled texture
            let pixelOffset = (y * dsWidth + (x + i)) * 4
            
            // BGRA format
            let b = Float(pixelData[pixelOffset])
            let g = Float(pixelData[pixelOffset + 1])
            let r = Float(pixelData[pixelOffset + 2])
            
            // Store pixel values based on segment class
            if segmentClass == SegmentationClass.skin.rawValue {
              skinPixels.append((r: r, g: g, b: b))
            } else if segmentClass == SegmentationClass.hair.rawValue {
              hairPixels.append((r: r, g: g, b: b))
            }
          }
          
          x += pixelsToProcess
        }
      }
      
      var colorInfo = ColorInfo()
      
      // Process skin pixels
      if !skinPixels.isEmpty {
        let skinPixelCount = skinPixels.count
        
        let skinTotals = skinPixels.reduce((r: 0.0, g: 0.0, b: 0.0)) { result, pixel in
          return (r: result.r + pixel.r, g: result.g + pixel.g, b: result.b + pixel.b)
        }
        
        let avgR = skinTotals.r / Float(skinPixelCount)
        let avgG = skinTotals.g / Float(skinPixelCount)
        let avgB = skinTotals.b / Float(skinPixelCount)
        
        let newSkinColor = UIColor(
          red: CGFloat(avgR / 255.0), green: CGFloat(avgG / 255.0), blue: CGFloat(avgB / 255.0),
          alpha: 1.0)
        
        // Temporal smoothing for stable color values
        if self.lastColorInfo.skinColor != .clear {
          colorInfo.skinColor = self.blendColors(
            newColor: newSkinColor, oldColor: self.lastColorInfo.skinColor, factor: self.smoothingFactor)
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
        colorInfo.skinColor = self.lastColorInfo.skinColor
        colorInfo.skinColorHSV = self.lastColorInfo.skinColorHSV
      }
      
      // Process hair pixels
      if !hairPixels.isEmpty {
        let hairPixelCount = hairPixels.count
        
        let hairTotals = hairPixels.reduce((r: 0.0, g: 0.0, b: 0.0)) { result, pixel in
          return (r: result.r + pixel.r, g: result.g + pixel.g, b: result.b + pixel.b)
        }
        
        let avgR = hairTotals.r / Float(hairPixelCount)
        let avgG = hairTotals.g / Float(hairPixelCount)
        let avgB = hairTotals.b / Float(hairPixelCount)
        
        let newHairColor = UIColor(
          red: CGFloat(avgR / 255.0), green: CGFloat(avgG / 255.0), blue: CGFloat(avgB / 255.0),
          alpha: 1.0)
        
        // Temporal smoothing for stable color values
        if self.lastColorInfo.hairColor != .clear {
          colorInfo.hairColor = self.blendColors(
            newColor: newHairColor, oldColor: self.lastColorInfo.hairColor, factor: self.smoothingFactor)
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
        colorInfo.hairColor = self.lastColorInfo.hairColor
        colorInfo.hairColorHSV = self.lastColorInfo.hairColorHSV
      }
      
      // If we have valid data, update the lastColorInfo
      if !skinPixels.isEmpty || !hairPixels.isEmpty {
        self.lastColorInfo = colorInfo
      }
      
      // Recycle resources when done
      BufferPoolManager.shared.recycleBuffer(textureBuffer)
      TexturePoolManager.shared.recycleTexture(downsampledTexture)
    }
    
    // Commit the command buffer
    commandBuffer?.commit()
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

  // Process segmentation results to extract color information
  private func extractColorInformation(from segmenterResult: ImageSegmenterResult) {
    // Implementation would analyze the segmentation mask and extract colors
    // Currently just using placeholders for demonstration purposes
    
    // Sample skin color (this would be calculated from the actual segmentation)
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
