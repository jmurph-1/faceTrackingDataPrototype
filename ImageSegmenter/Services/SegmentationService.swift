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
  let colorInfo: MultiClassSegmentedImageRenderer.ColorInfo
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
    set {
      imageSegmenterServiceQueue.async(flags: .barrier) {
        self._imageSegmenterService = newValue
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
    clearImageSegmenterService()

    imageSegmenterService = ImageSegmenterService
      .liveStreamImageSegmenterService(
        modelPath: modelPath,
        liveStreamDelegate: self,
        delegate: InferenceConfigurationManager.sharedInstance.delegate)
  }

  func processFrame(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timeStamps: Int) {
    // Store the current pixel buffer for use in the segmentation callback
    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
      videoPixelBuffer = pixelBuffer

      // Update format description every time to ensure it's current
      formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
    }

    // Check for throttling
    let currentTime = Date().timeIntervalSince1970
    let timeElapsed = currentTime - lastSegmentationTime

    // Process every frame to maintain consistency
    imageSegmenterService?.segmentAsync(
      sampleBuffer: sampleBuffer,
      orientation: orientation,
      timeStamps: timeStamps)

    // Update timestamp if processing a full frame
    if timeElapsed >= segmentationThrottleInterval {
      lastSegmentationTime = currentTime
    }
  }

  func clearImageSegmenterService() {
    imageSegmenterService = nil
  }

  // MARK: - Helper Methods
  private func prepareRendererIfNeeded() {
    guard let formatDescription = formatDescription else {
      print("Cannot prepare renderer: formatDescription is nil")
      return
    }

    if !multiClassRenderer.isPrepared {
        print("Preparing multiClassRenderer with format: \(CMFormatDescriptionGetExtensions(formatDescription) ?? [:] as CFDictionary)")
      multiClassRenderer.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
    }

    // Debug dimensions
    if let pixelBuffer = videoPixelBuffer {
      let width = CVPixelBufferGetWidth(pixelBuffer)
      let height = CVPixelBufferGetHeight(pixelBuffer)
      print("Video buffer dimensions: \(width)x\(height)")
    }
  }

  // Get current face bounding box for quality assessment
  func getCurrentFaceBoundingBox() -> CGRect? {
    return multiClassRenderer.getFaceBoundingBox()
  }

  // Get current color information for analysis
  func getCurrentColorInfo() -> MultiClassSegmentedImageRenderer.ColorInfo {
    return multiClassRenderer.getCurrentColorInfo()
  }
}

// MARK: - ImageSegmenterServiceLiveStreamDelegate
extension SegmentationService: ImageSegmenterServiceLiveStreamDelegate {
  func imageSegmenterService(_ imageSegmenterService: ImageSegmenterService, didFinishSegmention result: ResultBundle?, error: Error?) {
    // Handle errors
    if let error = error {
      delegate?.segmentationService(self, didFailWithError: error)
      return
    }

    // Ensure we have segmentation results and a valid pixel buffer
    guard let imageSegmenterResult = result?.imageSegmenterResults.first as? ImageSegmenterResult,
          let confidenceMasks = imageSegmenterResult.categoryMask,
          let pixelBuffer = videoPixelBuffer else {
      print("Missing segmentation data or video pixel buffer")
      return
    }

    let confidenceMask = confidenceMasks.uint8Data

    // Make sure renderers are prepared with current format description
    prepareRendererIfNeeded()

    // Double-check dimensions before rendering
    let pixelBufferWidth = CVPixelBufferGetWidth(pixelBuffer)
    let pixelBufferHeight = CVPixelBufferGetHeight(pixelBuffer)

    // Debug log
    print("Rendering segmentation for buffer: \(pixelBufferWidth)x\(pixelBufferHeight)")

    // Render the segmentation
    guard let outputPixelBuffer = multiClassRenderer.render(pixelBuffer: pixelBuffer, segmentDatas: confidenceMask) else {
      print("Failed to render segmentation - renderer returned nil")

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
    delegate?.segmentationService(self, didCompleteSegmentation: segmentationResult)
  }
}
