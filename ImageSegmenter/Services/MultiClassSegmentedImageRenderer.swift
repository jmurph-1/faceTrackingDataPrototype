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

  public enum SegmentationClass: UInt8 {
    case background = 0
    case hair = 1
    case skin = 2
    case lips = 3
    case eyes = 4
    case eyebrows = 5
  }

  private let faceLandmarkRenderer = FaceLandmarkRenderer()
  
  private var lastFaceLandmarks: [NormalizedLandmark]?

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

  let context: CIContext
  let textureLoader: MTKTextureLoader

  private let commandQueue: MTLCommandQueue?

  private let colorExtractor: ColorExtractor

  required init() {
    let defaultLibrary = metalDevice.makeDefaultLibrary()
    
    if let kernelFunction = defaultLibrary?.makeFunction(name: "processMultiClass") {
        do {
          computePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction)
        } catch {
          print("Could not create compute pipeline state for processMultiClass: \(error)")
          computePipelineState = nil
        }
    } else {
        print("Could not load default library or kernel function 'processMultiClass'.")
        computePipelineState = nil
    }
    
    context = CIContext(mtlDevice: metalDevice)
    textureLoader = MTKTextureLoader(device: metalDevice)
    
    let cq = metalDevice.makeCommandQueue()
    self.commandQueue = cq
    
    colorExtractor = ColorExtractor(metalDevice: self.metalDevice, commandQueue: cq)
    
    faceLandmarkRenderer.highlightedLandmarkIndices = ColorExtractor.relevantLandmarkIndices
//    faceLandmarkRenderer.showMesh = false
//    faceLandmarkRenderer.showContours = false
//    faceLandmarkRenderer.landmarkSize = 1.0
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

    faceLandmarkRenderer.prepare(with: formatDescription, outputRetainedBufferCountHint: outputRetainedBufferCountHint, needChangeWidthHeight: needChangeWidthHeight)

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

    faceLandmarkRenderer.reset()
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

    let result = processSegmentation(pixelBuffer: pixelBuffer, segmentDatas: segmentDatas)
    
    // If we have landmarks, render them using FaceLandmarkRenderer
    if let landmarks = lastFaceLandmarks, let outputBuffer = result {
        faceLandmarkRenderer.renderFaceLandmarks(on: outputBuffer, faceLandmarks: landmarks) { image in
            if let cgImage = image?.cgImage {
                // Convert CGImage back to CVPixelBuffer and blend with output
                let width = CVPixelBufferGetWidth(outputBuffer)
                let height = CVPixelBufferGetHeight(outputBuffer)
                
                CVPixelBufferLockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
                let context = CGContext(data: CVPixelBufferGetBaseAddress(outputBuffer),
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: CVPixelBufferGetBytesPerRow(outputBuffer),
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                
                context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
                CVPixelBufferUnlockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
            }
        }
    }

    let currentProcessingTime = CACurrentMediaTime() - processingStartTime
    lastProcessingTime = currentProcessingTime

    if currentProcessingTime > 0.1 { // More than 100ms per frame
      frameSkip = min(frameSkip + 1, 30) // Increase skip rate up to max of 30
      isProcessingHeavyLoad = true
    } else if currentProcessingTime < 0.05 && frameSkip > 15 { // Less than 50ms per frame
      frameSkip = max(frameSkip - 1, 15) // Decrease skip rate down to min of 15
      isProcessingHeavyLoad = false
    }

    return result
  }

  private func processSegmentation(pixelBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>) -> CVPixelBuffer? {
    let pixelBufferWidth = CVPixelBufferGetWidth(pixelBuffer)
    let pixelBufferHeight = CVPixelBufferGetHeight(pixelBuffer)

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

    if isGPUProcessingAvailable() {
        if !processWithGPU(inputBuffer: pixelBuffer, outputBuffer: outputBuffer, segmentDatas: segmentDatas, width: pixelBufferWidth, height: pixelBufferHeight) {
            processFallbackCPU(inputBuffer: pixelBuffer, outputBuffer: outputBuffer, segmentDatas: segmentDatas)
        }
    } else {
        processFallbackCPU(inputBuffer: pixelBuffer, outputBuffer: outputBuffer, segmentDatas: segmentDatas)
    }

    if frameCounter % frameSkip == 0 {
        if let imageSegmenterResult = (Result(
            size: CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)),
            imageSegmenterResult: ImageSegmenterResult(
                categoryMask: segmentDatas,
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )
        )).imageSegmenterResult,
           let categoryMask = imageSegmenterResult.categoryMask {
            
            if let textureForColorExtraction = makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer, textureFormat: .bgra8Unorm) {
                 colorExtractor.extractColorsOptimized(
                    from: textureForColorExtraction,
                    segmentMask: categoryMask,
                    width: imageSegmenterResult.width,
                    height: imageSegmenterResult.height
                )
            } else {
                log("Failed to create texture from CVPixelBuffer for color extraction. Skipping color extraction for this frame.", level: .warning)
            }
        }
    }
    frameCounter += 1

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
         colorExtractor.extractColorsHighAccuracy(
            from: texture,
            segmentMask: categoryMask,
            width: segmenterResult.width,
            height: segmenterResult.height
        )
      }
      // Let's assume frameCounter is primarily for processSegmentation path. If this render path is also called per frame, frameCounter logic might need adjustment.
      // For now, assume processSegmentation is the primary frame processing path.
    }
    
    commandBuffer.makeCommandBuffer()?.addCompletedHandler { (_: MTLCommandBuffer) in
      // TexturePoolManager.shared.recycleTexture(texture)
    }
    commandBuffer.makeCommandBuffer()?.commit()

    return texture
  }

  func getCurrentColorInfo() -> ColorExtractor.ColorInfo {
    return colorExtractor.getCurrentColorInfo()
  }
  
  func getFaceLandmarks() -> [NormalizedLandmark]? {
    return lastFaceLandmarks
  }
  
  func updateFaceLandmarks(_ landmarks: [NormalizedLandmark]?) {
    lastFaceLandmarks = landmarks
    colorExtractor.updateFaceLandmarks(landmarks)
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
}
