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
  private let render = SegmentedImageRenderer()
  private let multiClassRenderer = MultiClassSegmentedImageRenderer()

  // State tracking
  private var lastSegmentationTime: TimeInterval = 0
  private let segmentationThrottleInterval: TimeInterval = 0.1  // 10Hz throttle

  private var formatDescription: CMFormatDescription?

  weak var delegate: SegmentationServiceDelegate?

  // Keep track of the most recent video pixel buffer for processing
  private var videoPixelBuffer: CVPixelBuffer?

  // MARK: - Initialization
  init() {
    // Initialize with default settings
  }

  // MARK: - Public Methods
  func configure(with modelPath: String) {
      //print("SegmentationService: configure(with modelPath: \(modelPath)) CALLED.")

    imageSegmenterServiceQueue.sync(flags: .barrier) {
        self._imageSegmenterService = nil
        //print("SegmentationService: configure - _imageSegmenterService cleared synchronously.")
    }

    let newService = ImageSegmenterService
      .liveStreamImageSegmenterService(
        modelPath: modelPath,
        liveStreamDelegate: self,
        delegate: InferenceConfigurationManager.sharedInstance.delegate)

    imageSegmenterServiceQueue.sync(flags: .barrier) {
        self._imageSegmenterService = newService
        //print("SegmentationService: configure - _imageSegmenterService has been set synchronously. Is nil: \(self._imageSegmenterService == nil)")
    }
  }

  func processFrame(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timeStamps: Int) {
    //print("SegmentationService: processFrame called for timestamp: \(timeStamps)")

    // Store the current pixel buffer for use in the segmentation callback
    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
      videoPixelBuffer = pixelBuffer
      // print("SegmentationService: videoPixelBuffer assigned.")

      // Update format description every time to ensure it's current
      formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
      // print("SegmentationService: formatDescription updated.")
    }

    // Check for throttling
    let currentTime = Date().timeIntervalSince1970
    let timeElapsed = currentTime - lastSegmentationTime

    guard let currentImageSegmenter = self.imageSegmenterService else {
        //print("SegmentationService: processFrame - ERROR: self.imageSegmenterService (computed property) is nil!")
        return
    }
    
    //print("SegmentationService: processFrame - Attempting to call imageSegmenterService.segmentAsync")
    do {
        try currentImageSegmenter.segmentAsync(
            sampleBuffer: sampleBuffer,
            orientation: orientation,
            timeStamps: timeStamps)
        //print("SegmentationService: processFrame - Called imageSegmenterService.segmentAsync for timestamp: \(timeStamps)")
    } catch {
        //print("SegmentationService: processFrame - Error calling segmentAsync: \(error)")
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
        //print("SegmentationService: clearImageSegmenterService - _imageSegmenterService cleared synchronously.")
    }
  }

  // MARK: - Helper Methods
  private func prepareRendererIfNeeded() {
    guard let formatDescription = formatDescription else {
      //print("Cannot prepare renderer: formatDescription is nil")
      return
    }

    if !multiClassRenderer.isPrepared {
        //print("Preparing multiClassRenderer with format: \(CMFormatDescriptionGetExtensions(formatDescription) ?? [:] as CFDictionary)")
      multiClassRenderer.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
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
}

// MARK: - ImageSegmenterServiceLiveStreamDelegate
extension SegmentationService: ImageSegmenterServiceLiveStreamDelegate {
  func imageSegmenterService(_ imageSegmenterService: ImageSegmenterService, didFinishSegmention result: ResultBundle?, error: Error?) {
    //print("SegmentationService: imageSegmenterService.didFinishSegmention delegate called.")
    // Handle errors
    if let error = error {
      //print("SegmentationService: didFinishSegmention - Error: \(error.localizedDescription)")
      delegate?.segmentationService(self, didFailWithError: error)
      return
    }

    // Ensure we have segmentation results and a valid pixel buffer
    guard let imageSegmenterResult = result?.imageSegmenterResults.first as? ImageSegmenterResult,
          let confidenceMasks = imageSegmenterResult.categoryMask,
          let pixelBuffer = videoPixelBuffer else {
      //print("SegmentationService: didFinishSegmention - Missing segmentation data or video pixel buffer")
      // If videoPixelBuffer is nil, we can't proceed. Maybe return an error or a specific result.
      if videoPixelBuffer == nil {
          //print("SegmentationService: videoPixelBuffer is nil, cannot render.")
          // Consider what to do here. Maybe a specific error or skip frame.
          // For now, let's just return, which means no update to the delegate.
          return
      }
      // If only segmentation data is missing, we might still want to pass the original frame.
      // However, the guard condition above handles this by returning.
      return
    }

    let confidenceMask = confidenceMasks.uint8Data

    // Make sure renderers are prepared with current format description
    prepareRendererIfNeeded()

    // Double-check dimensions before rendering
    let pixelBufferWidth = CVPixelBufferGetWidth(pixelBuffer)
    let pixelBufferHeight = CVPixelBufferGetHeight(pixelBuffer)

    // Debug log
    //print("SegmentationService: didFinishSegmention - Rendering segmentation for buffer: \(pixelBufferWidth)x\(pixelBufferHeight)")

    // Render the segmentation
    guard let outputPixelBuffer = multiClassRenderer.render(pixelBuffer: pixelBuffer, segmentDatas: confidenceMask) else {
      //print("SegmentationService: didFinishSegmention - Failed to render segmentation - renderer returned nil")

      // If we can't render, use the original pixel buffer for preview
      let colorInfo = multiClassRenderer.getCurrentColorInfo()
      let fallbackResult = SegmentationResult(
        outputPixelBuffer: pixelBuffer, // Use original buffer
        segmentationMask: nil,
        colorInfo: colorInfo,
        faceBoundingBox: multiClassRenderer.getFaceBoundingBox(),
        faceLandmarks: multiClassRenderer.getFaceLandmarks(),
        inferenceTime: result?.inferenceTime
      )

      // Notify delegate with fallback result
      delegate?.segmentationService(self, didCompleteSegmentation: fallbackResult)
      return
    }

    // Extract color information
    let colorInfo = multiClassRenderer.getCurrentColorInfo()

    // Get face bounding box
    let faceBoundingBox = multiClassRenderer.getFaceBoundingBox()

    // Create segmentation mask data
    let maskData = Data(bytes: confidenceMask,
                       count: Int(confidenceMasks.width * confidenceMasks.height))

    // Create result object
    let segmentationResult = SegmentationResult(
      outputPixelBuffer: outputPixelBuffer,
      segmentationMask: maskData,
      colorInfo: colorInfo,
      faceBoundingBox: faceBoundingBox,
      faceLandmarks: multiClassRenderer.getFaceLandmarks(),
      inferenceTime: result?.inferenceTime
    )

    // Notify delegate
    //print("SegmentationService: didFinishSegmention - Successfully created SegmentationResult. Notifying delegate.")
    delegate?.segmentationService(self, didCompleteSegmentation: segmentationResult)
  }
}
