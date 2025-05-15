import CoreMedia
import CoreVideo
import MediaPipeTasksVision
import Metal
import MetalKit
import MetalPerformanceShaders
import UIKit

class MultiClassSegmentedImageRenderer: RendererProtocol {

  var description: String = "MultiClass Renderer"
  var isPrepared = false
  
  // Current log level - set to info by default
  private var logLevel: LogLevel = .info

  enum LogLevel: Int {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    case verbose = 5
  }


  struct ImageSegmenterResult {
    let categoryMask: UnsafePointer<UInt8>?
    let width: Int
    let height: Int
  }

  struct Result {
    let size: CGSize
    let imageSegmenterResult: ImageSegmenterResult?
  }

  enum SegmentationClass: UInt8 {
    case background = 0
    case hair = 1
    case skin = 2
    case lips = 3
    case eyes = 4
    case eyebrows = 5
  }

  struct ColorInfo {
    var skinColor: UIColor = .clear
    var hairColor: UIColor = .clear
    var skinColorHSV: (h: CGFloat, s: CGFloat, v: CGFloat) = (0, 0, 0)
    var hairColorHSV: (h: CGFloat, s: CGFloat, v: CGFloat) = (0, 0, 0)
  }

  private var lastColorInfo = ColorInfo()
  
  private var lastFaceLandmarks: [NormalizedLandmark]?

  private let smoothingFactor: Float = 0.3
  private var frameCounter: Int = 0
    private var frameSkip = 15  // Start with higher skip rate, will adjust dynamically
    private let logFrameInterval = 60  // Reduced logging frequency
    private var lastProcessingTime: CFTimeInterval = 0
    private var processingStartTime: CFTimeInterval = 0
    private var isProcessingHeavyLoad: Bool = false

  private let downsampleFactor: Int = 4

  private(set) var outputFormatDescription: CMFormatDescription?
  private var outputPixelBufferPool: CVPixelBufferPool?
  private let metalDevice = MTLCreateSystemDefaultDevice()!
  private var computePipelineState: MTLComputePipelineState?
  private var downsampleComputePipelineState: MTLComputePipelineState?

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
  
  func setLogLevel(_ level: LogLevel) {
    logLevel = level
  }

  private func log(_ message: String, level: LogLevel) {
    if level.rawValue <= logLevel.rawValue {
      switch level {
      case .error:
        LoggingService.error(message)
      case .warning:
        LoggingService.warning(message)
      case .info:
        LoggingService.info(message)
      case .debug:
        LoggingService.debug(message)
      case .verbose:
        LoggingService.verbose(message)
      case .none:
        break
      }
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
      != kCVReturnSuccess {
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

              float4 color = sourceTexture.read(sourcePos);

              destinationTexture.write(color, gid);
          }
          """

        let options = MTLCompileOptions()
        options.languageVersion = .version2_0

        do {
          let library = try metalDevice.makeLibrary(source: kernelSource, options: options)
          let downsampleFunction = library.makeFunction(name: "downsampleTexture")
          downsampleComputePipelineState = try metalDevice.makeComputePipelineState(
            function: downsampleFunction!)
        } catch {
          log("Failed to create downsample pipeline: \(error)", level: .error)
          return nil
        }
      } else {
        do {
          downsampleComputePipelineState = try metalDevice.makeComputePipelineState(
            function: kernelFunction!)
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

    guard let commandBuffer = commandQueue?.makeCommandBuffer(),
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      log("Failed to create compute encoder", level: .error)
      return nil
    }

    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setTexture(texture, index: 0)
    computeEncoder.setTexture(newDownsampledTexture, index: 1)

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

    computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
    computeEncoder.endEncoding()

    commandBuffer.commit()

    return newDownsampledTexture
  }

  private func downsampleTextureCPU(source: MTLTexture, destination: MTLTexture, scale: Int) {
    let srcWidth = source.width
    let srcHeight = source.height
    let dstWidth = destination.width
    let dstHeight = destination.height

    let bytesPerPixel = 4  // BGRA format
    let srcBytesPerRow = srcWidth * bytesPerPixel
    let dstBytesPerRow = dstWidth * bytesPerPixel
    let srcBytes = UnsafeMutablePointer<UInt8>.allocate(
      capacity: srcWidth * srcHeight * bytesPerPixel)
    let dstBytes = UnsafeMutablePointer<UInt8>.allocate(
      capacity: dstWidth * dstHeight * bytesPerPixel)

    let srcRegion = MTLRegionMake2D(0, 0, srcWidth, srcHeight)
    let dstRegion = MTLRegionMake2D(0, 0, dstWidth, dstHeight)

    source.getBytes(srcBytes, bytesPerRow: srcBytesPerRow, from: srcRegion, mipmapLevel: 0)

    for y in 0..<dstHeight {
      for x in 0..<dstWidth {
        let srcX = x * scale
        let srcY = y * scale

        let srcIndex = (srcY * srcWidth + srcX) * bytesPerPixel
        let dstIndex = (y * dstWidth + x) * bytesPerPixel

        for i in 0..<bytesPerPixel {
          dstBytes[dstIndex + i] = srcBytes[srcIndex + i]
        }
      }
    }

    destination.replace(
      region: dstRegion, mipmapLevel: 0, withBytes: dstBytes, bytesPerRow: dstBytesPerRow)

    srcBytes.deallocate()
    dstBytes.deallocate()
  }

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
      kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ]

    var pixelBufferPool: CVPixelBufferPool?
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

  private func isGPUProcessingAvailable() -> Bool {
    return computePipelineState != nil && commandQueue != nil
      && metalDevice.supportsFeatureSet(.iOS_GPUFamily2_v1)
  }

  private func processFallbackCPU(
    inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>
  ) {
    CVPixelBufferLockBaseAddress(inputBuffer, CVPixelBufferLockFlags(rawValue: 0))
    CVPixelBufferLockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))

    let width = CVPixelBufferGetWidth(inputBuffer)
    let height = CVPixelBufferGetHeight(inputBuffer)

    let sourceData = CVPixelBufferGetBaseAddress(inputBuffer)!
    let destData = CVPixelBufferGetBaseAddress(outputBuffer)!
    let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(inputBuffer)
    let destBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)

    for row in 0..<height {
      let sourceRowPtr = sourceData.advanced(by: row * sourceBytesPerRow)
      let destRowPtr = destData.advanced(by: row * destBytesPerRow)

      for col in 0..<width {
        let pixelOffset = col * 4  // BGRA format (4 bytes per pixel)
        let segmentClass = segmentDatas[row * width + col]

        let srcPixel = sourceRowPtr.advanced(by: pixelOffset)
        let destPixel = destRowPtr.advanced(by: pixelOffset)

        memcpy(destPixel, srcPixel, 4)

        if segmentClass > 0 {  // Not background
          switch segmentClass {
          case SegmentationClass.hair.rawValue:
            let destBGRA = destPixel.bindMemory(to: UInt8.self, capacity: 4)
            destBGRA[0] = UInt8(min(255, Int(Float(destBGRA[0]) * 1.1)))  // B
            destBGRA[1] = UInt8(min(255, Int(Float(destBGRA[1]) * 1.1)))  // G
            destBGRA[2] = UInt8(min(255, Int(Float(destBGRA[2]) * 1.1)))  // R
          case SegmentationClass.skin.rawValue:
            let destBGRA = destPixel.bindMemory(to: UInt8.self, capacity: 4)
            destBGRA[0] = UInt8(min(255, Int(Float(destBGRA[0]) * 1.05)))  // B
            destBGRA[1] = UInt8(min(255, Int(Float(destBGRA[1]) * 1.05)))  // G
            destBGRA[2] = UInt8(min(255, Int(Float(destBGRA[2]) * 1.05)))  // R
          default:
            break
          }
        }
      }
    }

    CVPixelBufferUnlockBaseAddress(inputBuffer, CVPixelBufferLockFlags(rawValue: 0))
    CVPixelBufferUnlockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
  }

  func render(pixelBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>?) -> CVPixelBuffer? {
    guard isPrepared, let segmentDatas = segmentDatas else {
      return nil
    }

    processingStartTime = CACurrentMediaTime()

    let pixelBufferWidth = CVPixelBufferGetWidth(pixelBuffer)
    let pixelBufferHeight = CVPixelBufferGetHeight(pixelBuffer)

    if frameCounter % logFrameInterval == 0 {
      //log("Rendering segmentation for buffer: \(pixelBufferWidth)x\(pixelBufferHeight)", level: .info)
    }

    var outputBuffer: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBuffer(
      kCFAllocatorDefault, outputPixelBufferPool!, &outputBuffer)
    if status != kCVReturnSuccess {
      log("Failed to create output pixel buffer: \(status)", level: .error)
      return nil
    }

    guard let outputBuffer = outputBuffer else {
      return nil
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

    if frameCounter % frameSkip == 0 {
      extractColorInformation(from: result.imageSegmenterResult!, pixelBuffer: pixelBuffer)
    }
    frameCounter += 1

    let currentProcessingTime = CACurrentMediaTime() - processingStartTime
    lastProcessingTime = currentProcessingTime

    if currentProcessingTime > 0.1 { // More than 100ms per frame
      frameSkip = min(frameSkip + 1, 30) // Increase skip rate up to max of 30
      isProcessingHeavyLoad = true
    } else if currentProcessingTime < 0.05 && frameSkip > 15 { // Less than 50ms per frame
      frameSkip = max(frameSkip - 1, 15) // Decrease skip rate down to min of 15
      isProcessingHeavyLoad = false
    }

    return outputBuffer
  }

  private func processWithGPU(
    inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>,
    width: Int, height: Int
  ) -> Bool {
    guard
      let inputTexture = makeTextureFromCVPixelBuffer(
        pixelBuffer: inputBuffer, textureFormat: .bgra8Unorm),
      let outputTexture = makeTextureFromCVPixelBuffer(
        pixelBuffer: outputBuffer, textureFormat: .bgra8Unorm)
    else {
      log("Failed to create Metal textures from pixel buffers", level: .error)
      return false
    }

    guard let commandQueue = commandQueue,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let commandEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      log("Failed to create a Metal command queue or encoder", level: .error)
      CVMetalTextureCacheFlush(textureCache!, 0)
      return false
    }

    commandEncoder.label = "MultiClass Segmentation"
    commandEncoder.setComputePipelineState(computePipelineState!)
    commandEncoder.setTexture(inputTexture, index: 0)
    commandEncoder.setTexture(outputTexture, index: 1)

    let bufferSize = width * height * MemoryLayout<UInt8>.size
    let segBuffer: MTLBuffer

    if let pooledBuffer = BufferPoolManager.shared.getBuffer(
      length: bufferSize, options: .storageModeShared) {
      memcpy(pooledBuffer.contents(), segmentDatas, bufferSize)
      segBuffer = pooledBuffer
    } else {
      guard let newBuffer = metalDevice.makeBuffer(bytes: segmentDatas, length: bufferSize) else {
        log("Failed to create segmentation buffer", level: .error)
        return false
      }
      segBuffer = newBuffer
    }

    segmentationBuffer = segBuffer

    commandEncoder.setBuffer(segBuffer, offset: 0, index: 0)

    var imageWidth: Int = Int(width)
    commandEncoder.setBytes(&imageWidth, length: MemoryLayout<Int>.size, index: 1)

    let threadExecutionWidth = computePipelineState!.threadExecutionWidth
    let threadsPerGroupHeight =
      computePipelineState!.maxTotalThreadsPerThreadgroup / threadExecutionWidth
    let threadsPerThreadgroup = MTLSizeMake(threadExecutionWidth, threadsPerGroupHeight, 1)
    let threadgroupsPerGrid = MTLSize(
      width: (inputTexture.width + threadExecutionWidth - 1) / threadExecutionWidth,
      height: (inputTexture.height + threadsPerGroupHeight - 1) / threadsPerGroupHeight,
      depth: 1
    )

    commandEncoder.dispatchThreadgroups(
      threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    commandEncoder.endEncoding()

    commandBuffer.addCompletedHandler { [weak self] (buffer: MTLCommandBuffer) in
      if let segBuffer = self?.segmentationBuffer {
        BufferPoolManager.shared.recycleBuffer(segBuffer)
        self?.segmentationBuffer = nil
      }

      if buffer.status != .completed {
        self?.log(
          "Metal command buffer execution failed with status: \(buffer.status)", level: .error)
      }
    }

    commandBuffer.commit()

    return true
  }

  func render(result: Result) -> MTLTexture {
    let width = Int(result.size.width)
    let height = Int(result.size.height)

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm,
      width: width,
      height: height,
      mipmapped: false)
    textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]

    guard let texture = metalDevice.makeTexture(descriptor: textureDescriptor) else {
      fatalError("Failed to create texture")
    }

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].storeAction = .store
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
      red: 0, green: 0, blue: 0, alpha: 1)

    guard let commandBuffer = commandQueue,
      let renderEncoder = commandBuffer.makeCommandBuffer()?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return texture
    }

    renderEncoder.endEncoding()

    if let segmenterResult = result.imageSegmenterResult,
      let categoryMask = segmenterResult.categoryMask {


      if frameCounter % frameSkip == 0 {
        extractColorInformation(from: segmenterResult, texture: texture)
      }
      frameCounter += 1
    }
    
    commandBuffer.makeCommandBuffer()?.addCompletedHandler { [weak self] (buffer: MTLCommandBuffer) in
      if buffer.status != .completed {
        self?.log("Metal command buffer execution failed with status: \(buffer.status)", level: .error)
      }
    }
    
    commandBuffer.makeCommandBuffer()?.commit()

    return texture
  }

  private func extractColorsOptimized(
    from texture: MTLTexture, with segmentMask: UnsafePointer<UInt8>, width: Int, height: Int
  ) {
    guard let downsampledTexture = createDownsampledTexture(from: texture, scale: downsampleFactor)
    else {
      return
    }
    
    let dsWidth = downsampledTexture.width
    let dsHeight = downsampledTexture.height

    let bytesPerRow = dsWidth * 4  // BGRA format = 4 bytes per pixel
    let bufferSize = dsHeight * bytesPerRow

    guard
      let textureBuffer = BufferPoolManager.shared.getBuffer(
        length: bufferSize,
        options: .storageModeShared
      )
    else {
      TexturePoolManager.shared.recycleTexture(downsampledTexture)
      log("Failed to get buffer from pool", level: .error)
      return
    }

    guard let commandBuffer = commandQueue else {
      TexturePoolManager.shared.recycleTexture(downsampledTexture)
      BufferPoolManager.shared.recycleBuffer(textureBuffer)
      return
    }
    
    let cmdBuffer = commandBuffer.makeCommandBuffer()
    let blitEncoder = cmdBuffer?.makeBlitCommandEncoder()

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

    cmdBuffer?.addCompletedHandler { [weak self] (_: MTLCommandBuffer) in
      guard let self = self else {
        BufferPoolManager.shared.recycleBuffer(textureBuffer)
        TexturePoolManager.shared.recycleTexture(downsampledTexture)
        return
      }

      let pixelData = textureBuffer.contents().bindMemory(to: UInt8.self, capacity: bufferSize)

      var skinPixels = [(r: Float, g: Float, b: Float)]()
      skinPixels.reserveCapacity(dsWidth * dsHeight / 4)  // Estimate capacity

      var hairPixels = [(r: Float, g: Float, b: Float)]()
      hairPixels.reserveCapacity(dsWidth * dsHeight / 4)  // Estimate capacity

      let strideX = width / dsWidth
      let strideY = height / dsHeight

      let chunkSize = 16  // Process 16 pixels at a time
      
      var cheekPoints: [CGPoint] = []
      var foreheadPoints: [CGPoint] = []
      
      if let landmarks = self.lastFaceLandmarks, !landmarks.isEmpty {
        let leftCheekIndices = [117, 118, 119, 120, 121, 122, 123, 147, 187, 207, 206, 203, 204]
        let rightCheekIndices = [348, 349, 350, 351, 352, 353, 354, 376, 411, 427, 426, 423, 424]
        
        let foreheadIndices = [9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 71, 63, 105, 66, 107, 55, 65, 52, 53]
        
        for index in leftCheekIndices + rightCheekIndices {
          if index < landmarks.count {
            let x = CGFloat(landmarks[index].x)
            let y = CGFloat(landmarks[index].y)
            cheekPoints.append(CGPoint(x: x, y: y))
          }
        }
        
        for index in foreheadIndices {
          if index < landmarks.count {
            let x = CGFloat(landmarks[index].x)
            let y = CGFloat(landmarks[index].y)
            foreheadPoints.append(CGPoint(x: x, y: y))
          }
        }
      }
      
      for y in 0..<dsHeight {
        var x = 0
        while x < dsWidth {
          let remainingPixels = dsWidth - x
          let pixelsToProcess = min(chunkSize, remainingPixels)

          for i in 0..<pixelsToProcess {
            let segY = min(y * strideY, height - 1)
            let segX = min((x + i) * strideX, width - 1)
            let segIndex = segY * width + segX
            let segmentClass = segmentMask[segIndex]

            let pixelOffset = (y * dsWidth + (x + i)) * 4

            let b = Float(pixelData[pixelOffset])
            let g = Float(pixelData[pixelOffset + 1])
            let r = Float(pixelData[pixelOffset + 2])
            
            if segmentClass == SegmentationClass.hair.rawValue {
              hairPixels.append((r: r, g: g, b: b))
            } 
            else if segmentClass == SegmentationClass.skin.rawValue && (cheekPoints.isEmpty && foreheadPoints.isEmpty) {
              skinPixels.append((r: r, g: g, b: b))
            }
          }

          x += pixelsToProcess
        }
      }
      
      if !cheekPoints.isEmpty || !foreheadPoints.isEmpty {
        let allSamplingPoints = cheekPoints + foreheadPoints
        
        for point in allSamplingPoints {
          let dsX = Int(point.x * CGFloat(dsWidth))
          let dsY = Int(point.y * CGFloat(dsHeight))
          
          if dsX >= 0 && dsX < dsWidth && dsY >= 0 && dsY < dsHeight {
            let pixelOffset = (dsY * dsWidth + dsX) * 4
            
            if pixelOffset + 2 < bufferSize {
              let b = Float(pixelData[pixelOffset])
              let g = Float(pixelData[pixelOffset + 1])
              let r = Float(pixelData[pixelOffset + 2])
              
              let brightnessAdjustment: Float = 1.15
              let adjustedR = min(255, r * brightnessAdjustment)
              let adjustedG = min(255, g * brightnessAdjustment)
              let adjustedB = min(255, b * brightnessAdjustment)
              
              skinPixels.append((r: adjustedR, g: adjustedG, b: adjustedB))
              skinPixels.append((r: adjustedR, g: adjustedG, b: adjustedB))  // Add twice for higher weight
            }
          }
        }
      }

      var colorInfo = ColorInfo()

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

        if self.lastColorInfo.skinColor != .clear {
          colorInfo.skinColor = self.blendColors(
            newColor: newSkinColor, oldColor: self.lastColorInfo.skinColor,
            factor: self.smoothingFactor)
        } else {
          colorInfo.skinColor = newSkinColor
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0

        colorInfo.skinColor.getHue(
          &hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        colorInfo.skinColorHSV = (hue, saturation, brightness)
      } else {
        colorInfo.skinColor = self.lastColorInfo.skinColor
        colorInfo.skinColorHSV = self.lastColorInfo.skinColorHSV
      }

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

        if self.lastColorInfo.hairColor != .clear {
          colorInfo.hairColor = self.blendColors(
            newColor: newHairColor, oldColor: self.lastColorInfo.hairColor,
            factor: self.smoothingFactor)
        } else {
          colorInfo.hairColor = newHairColor
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0

        colorInfo.hairColor.getHue(
          &hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        colorInfo.hairColorHSV = (hue, saturation, brightness)
      } else {
        colorInfo.hairColor = self.lastColorInfo.hairColor
        colorInfo.hairColorHSV = self.lastColorInfo.hairColorHSV
      }

      if !skinPixels.isEmpty || !hairPixels.isEmpty {
        self.lastColorInfo = colorInfo
      }

      BufferPoolManager.shared.recycleBuffer(textureBuffer)
      TexturePoolManager.shared.recycleTexture(downsampledTexture)
    }

    cmdBuffer?.commit()
  }

  private func blendColors(newColor: UIColor, oldColor: UIColor, factor: Float) -> UIColor {
    let factorCG = CGFloat(factor)

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

    let r = oldR * (1 - factorCG) + newR * factorCG
    let g = oldG * (1 - factorCG) + newG * factorCG
    let b = oldB * (1 - factorCG) + newB * factorCG
    let a = oldA * (1 - factorCG) + newA * factorCG

    return UIColor(red: r, green: g, blue: b, alpha: a)
  }

  func getCurrentColorInfo() -> ColorInfo {
    return lastColorInfo
  }
  
  func getFaceLandmarks() -> [NormalizedLandmark]? {
    return lastFaceLandmarks
  }
  
  func updateFaceLandmarks(_ landmarks: [NormalizedLandmark]?) {
    lastFaceLandmarks = landmarks
    //LoggingService.debug("Updated face landmarks in MultiClassSegmentedImageRenderer: \(landmarks?.count ?? 0) points")
  }

  func getFaceBoundingBox() -> CGRect {
    if let landmarks = lastFaceLandmarks, !landmarks.isEmpty {
      let faceOvalIndices = MediaPipeFaceMesh.faceOval.flatMap { [$0.0, $0.1] }
      var minX: CGFloat = 1.0
      var minY: CGFloat = 1.0
      var maxX: CGFloat = 0.0
      var maxY: CGFloat = 0.0
      
      for index in faceOvalIndices {
        guard index < landmarks.count else { continue }
        let x = CGFloat(landmarks[index].x)
        let y = CGFloat(landmarks[index].y)
        
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
      }
      
      let padding: CGFloat = 0.05
      minX = max(0, minX - padding)
      minY = max(0, minY - padding)
      maxX = min(1, maxX + padding)
      maxY = min(1, maxY + padding)
      
      return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    return CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6)
  }

  private func extractColorInformation(from segmenterResult: ImageSegmenterResult, pixelBuffer: CVPixelBuffer) {
    guard let categoryMask = segmenterResult.categoryMask else {
      log("No category mask available for color extraction", level: .warning)
      return
    }
    
    let width = segmenterResult.width
    let height = segmenterResult.height
    
    guard let commandQueue = commandQueue else {
      log("Failed to create command buffer for color extraction", level: .error)
      return
    }
    
    guard let originalTexture = makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer, textureFormat: .bgra8Unorm) else {
      log("Failed to create texture from pixel buffer for color extraction", level: .warning)
      return
    }
    
    extractColorsOptimized(
      from: originalTexture,
      with: categoryMask,
      width: width,
      height: height
    )
    
    let cmdBuffer = commandQueue.makeCommandBuffer()
    cmdBuffer?.addCompletedHandler { (_: MTLCommandBuffer) in
      TexturePoolManager.shared.recycleTexture(originalTexture)
    }
    cmdBuffer?.commit()
  }
  
  private func extractColorInformation(from segmenterResult: ImageSegmenterResult, texture: MTLTexture) {
    guard let categoryMask = segmenterResult.categoryMask else {
      log("No category mask available for color extraction", level: .warning)
      return
    }
    
    let width = segmenterResult.width
    let height = segmenterResult.height
    
    extractColorsOptimized(
      from: texture,
      with: categoryMask,
      width: width,
      height: height
    )
  }
}
