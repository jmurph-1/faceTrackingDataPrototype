// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import AVFoundation
import MediaPipeTasksVision

// MARK: SegmentationServiceDelegate Declaration
protocol SegmentationServiceDelegate: AnyObject {
  func segmentationService(_ service: SegmentationService, didCompleteSegmentation result: SegmentationResult)
  func segmentationService(_ service: SegmentationService, didFailWithError error: Error)
}

// Result object that contains segmentation output and metadata
struct SegmentationResult {
  let outputPixelBuffer: CVPixelBuffer
  let segmentationMask: Data?
  let colorInfo: ColorExtractor.ColorInfo
  let faceBoundingBox: CGRect?
  let faceLandmarks: [NormalizedLandmark]?
  let inferenceTime: TimeInterval?
}

/**
 This class manages segmentation functionality including:
 - Handling segmentation model
 - Processing frames for segmentation
 - Rendering segmented output
 */
class SegmentationService {
  // MARK: - Properties
  private let imageSegmenterServiceQueue = DispatchQueue(
    label: "com.google.mediapipe.segmentationService.imageSegmenterServiceQueue",
    attributes: .concurrent)

  private var _imageSegmenterService: ImageSegmenterService?
  private var imageSegmenterService: ImageSegmenterService? {
    get {
      imageSegmenterServiceQueue.sync {
        return self._imageSegmenterService
      }
    }
  }

  // Renderers
  private let multiClassRenderer = MultiClassSegmentedImageRenderer()

  // State tracking
  private var lastSegmentationTime: TimeInterval = 0
  private let segmentationThrottleInterval: TimeInterval = 0.1  // 10Hz throttle

  private var formatDescription: CMFormatDescription?
  private(set) var isPrepared: Bool = false

  weak var delegate: SegmentationServiceDelegate?

  // Keep track of the most recent video pixel buffer for processing
  private var videoPixelBuffer: CVPixelBuffer?

  private var isCalibrated: Bool = false

  var textureCache: CVMetalTextureCache? {
    return multiClassRenderer.textureCache
  }

  // MARK: - Initialization
  init() {
    // Initialize with default settings
  }

  // MARK: - Public Methods
  func configure(with modelPath: String) {
    LoggingService.info("SEGMENTATION_FLOW: Configuring service with model")

    imageSegmenterServiceQueue.sync(flags: .barrier) {
        self._imageSegmenterService = nil
    }

    let newService = ImageSegmenterService
      .liveStreamImageSegmenterService(
        modelPath: modelPath,
        liveStreamDelegate: self,
        delegate: InferenceConfigurationManager.sharedInstance.delegate)

    imageSegmenterServiceQueue.sync(flags: .barrier) {
        self._imageSegmenterService = newService
        LoggingService.info("SEGMENTATION_FLOW: Service configured successfully")
    }
  }

  func processFrame(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timeStamps: Int) {
    // Store the current pixel buffer for use in the segmentation callback
    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
        videoPixelBuffer = pixelBuffer
        // Update format description every time to ensure it's current
        formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
    } else {
        LoggingService.warning("SEGMENTATION_FLOW: Failed to get pixel buffer from sample buffer")
        return
    }

    // Check for throttling
    let currentTime = Date().timeIntervalSince1970
    let timeElapsed = currentTime - lastSegmentationTime

    guard let currentImageSegmenter = self.imageSegmenterService else {
        LoggingService.error("SEGMENTATION_FLOW: Cannot process frame - image segmenter service is nil")
        return
    }

    // Process frame for segmentation
    do {
        try currentImageSegmenter.segmentAsync(
            sampleBuffer: sampleBuffer,
            orientation: orientation,
            timeStamps: timeStamps)
    } catch {
        LoggingService.error("SEGMENTATION_FLOW: Error calling segmentAsync: \(error)")
        delegate?.segmentationService(self, didFailWithError: error)
    }

    // Update timestamp if processing a full frame
    if timeElapsed >= segmentationThrottleInterval {
        lastSegmentationTime = currentTime
    }
  }

  func clearImageSegmenterService() {
    imageSegmenterServiceQueue.sync(flags: .barrier) {
        self._imageSegmenterService = nil
    }
  }

  // MARK: - Helper Methods
  private func prepareRendererIfNeeded() {
    guard let formatDescription = formatDescription else {
        LoggingService.warning("SEGMENTATION_FLOW: Cannot prepare renderer - missing format description")
        return
    }

    if !multiClassRenderer.isPrepared {
        multiClassRenderer.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
        LoggingService.info("SEGMENTATION_FLOW: Renderer prepared")
    }

    // Debug dimensions
    if let pixelBuffer = videoPixelBuffer {
      let width = CVPixelBufferGetWidth(pixelBuffer)
      let height = CVPixelBufferGetHeight(pixelBuffer)
    }
  }

  // Get current face bounding box for quality assessment
  func getCurrentFaceBoundingBox() -> CGRect? {
    return multiClassRenderer.getFaceBoundingBox()
  }

  // Get current color information for analysis
  func getCurrentColorInfo() -> ColorExtractor.ColorInfo {
    return multiClassRenderer.getCurrentColorInfo()
  }

  // Update face landmarks for quality calculation
  func updateFaceLandmarks(_ landmarks: [NormalizedLandmark]?) {
    multiClassRenderer.updateFaceLandmarks(landmarks)
  }

  // Add white balance calibration method
  func setWhiteBalanceCalibration(_ calibration: WhiteBalanceCalibration) {
    LoggingService.info("SEGMENTATION_FLOW: Applying white balance calibration")
    multiClassRenderer.setWhiteBalanceCalibration(calibration)
    isCalibrated = true
  }

  func extractWhiteReferenceColor(
      from texture: MTLTexture,
      region: CGRect,
      width: Int,
      height: Int
  ) -> (r: Float, g: Float, b: Float)? {
    LoggingService.debug("SEGMENTATION_FLOW: Attempting to extract white reference color from region: \(region)")
    let result = multiClassRenderer.extractWhiteReferenceColor(
        from: texture,
        region: region,
        width: width,
        height: height
    )
    
    if let color = result {
        LoggingService.debug("SEGMENTATION_FLOW: Successfully extracted white reference color - R:\(color.r) G:\(color.g) B:\(color.b)")
    } else {
        LoggingService.warning("SEGMENTATION_FLOW: Failed to extract white reference color")
    }
    
    return result
  }

  func makeTextureFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> MTLTexture? {
    guard let textureCache = multiClassRenderer.textureCache else {
      LoggingService.warning("SEGMENTATION_FLOW: Texture cache not available")
      return nil
    }
    
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    
    var cvTextureOut: CVMetalTexture?
    let result = CVMetalTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault,
      textureCache,
      pixelBuffer,
      nil,
      .bgra8Unorm,
      width,
      height,
      0,
      &cvTextureOut)
      
    if result != kCVReturnSuccess {
      LoggingService.error("SEGMENTATION_FLOW: Could not create Metal texture from pixel buffer: \(result)")
      return nil
    }
    
    guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
      LoggingService.error("SEGMENTATION_FLOW: Could not get Metal texture from CVMetalTexture")
      return nil
    }
    
    return texture
  }

  func prepare(with formatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int = 3) {
    self.formatDescription = formatDescription
    multiClassRenderer.prepare(with: formatDescription, outputRetainedBufferCountHint: outputRetainedBufferCountHint)
    isPrepared = true
    LoggingService.info("SEGMENTATION_FLOW: Service prepared successfully")
  }
}

// MARK: - ImageSegmenterServiceLiveStreamDelegate
extension SegmentationService: ImageSegmenterServiceLiveStreamDelegate {
    func imageSegmenterService(_ imageSegmenterService: ImageSegmenterService, didFinishSegmention result: ResultBundle?, error: Error?) {
        // Handle errors
        if let error = error {
            LoggingService.error("SEGMENTATION_FLOW: Segmentation error: \(error.localizedDescription)")
            delegate?.segmentationService(self, didFailWithError: error)
            return
        }

        // Ensure we have segmentation results and a valid pixel buffer
        guard let imageSegmenterResult = result?.imageSegmenterResults.first as? ImageSegmenterResult,
              let confidenceMasks = imageSegmenterResult.categoryMask,
              let pixelBuffer = videoPixelBuffer else {
            LoggingService.warning("SEGMENTATION_FLOW: Missing required data for segmentation processing")
            return
        }

        let confidenceMask = confidenceMasks.uint8Data

        // Make sure renderers are prepared with current format description
        prepareRendererIfNeeded()

        // Render the segmentation
        guard let outputPixelBuffer = multiClassRenderer.render(pixelBuffer: pixelBuffer, segmentDatas: confidenceMask) else {
            LoggingService.error("SEGMENTATION_FLOW: Failed to render segmentation")

            // If we can't render, use the original pixel buffer for preview
            let colorInfo = multiClassRenderer.getCurrentColorInfo()
            let fallbackResult = SegmentationResult(
                outputPixelBuffer: pixelBuffer,
                segmentationMask: nil,
                colorInfo: colorInfo,
                faceBoundingBox: multiClassRenderer.getFaceBoundingBox(),
                faceLandmarks: multiClassRenderer.getFaceLandmarks(),
                inferenceTime: result?.inferenceTime
            )

            delegate?.segmentationService(self, didCompleteSegmentation: fallbackResult)
            return
        }

        // Extract color information only if calibrated
        let colorInfo: ColorExtractor.ColorInfo
        if isCalibrated {
            colorInfo = multiClassRenderer.getCurrentColorInfo()
        } else {
            colorInfo = ColorExtractor.ColorInfo() // Return empty color info
        }

        // Create segmentation mask data
        let maskData = Data(bytes: confidenceMask,
                           count: Int(confidenceMasks.width * confidenceMasks.height))

        // Create result object
        let segmentationResult = SegmentationResult(
            outputPixelBuffer: outputPixelBuffer,
            segmentationMask: maskData,
            colorInfo: colorInfo,
            faceBoundingBox: multiClassRenderer.getFaceBoundingBox(),
            faceLandmarks: multiClassRenderer.getFaceLandmarks(),
            inferenceTime: result?.inferenceTime
        )

        delegate?.segmentationService(self, didCompleteSegmentation: segmentationResult)
    }
}
