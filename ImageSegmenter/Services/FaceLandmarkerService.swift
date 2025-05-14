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
import MediaPipeTasksVision
import AVFoundation

/**
 This protocol must be adopted by any class that wants to get the face landmark results in live stream mode.
 */
protocol FaceLandmarkerServiceLiveStreamDelegate: AnyObject {
  func faceLandmarkerService(_ faceLandmarkerService: FaceLandmarkerService,
                             didFinishLandmarkDetection result: FaceLandmarkerResultBundle?,
                             error: Error?)
}

// Initializes and calls the MediaPipe APIs for face landmark detection.
class FaceLandmarkerService: NSObject {

  weak var liveStreamDelegate: FaceLandmarkerServiceLiveStreamDelegate?

  var faceLandmarker: FaceLandmarker?
  private(set) var runningMode = RunningMode.image
  var modelPath: String
  var delegate: Delegate

  // MARK: - Custom Initializer
  private init?(modelPath: String?,
                runningMode: RunningMode,
                delegate: Delegate) {
    guard let modelPath = modelPath else { return nil }
    self.modelPath = modelPath
    self.runningMode = runningMode
    self.delegate = delegate
    super.init()

    createFaceLandmarker()
  }

  private func createFaceLandmarker() {
    let faceLandmarkerOptions = FaceLandmarkerOptions()
    faceLandmarkerOptions.runningMode = runningMode
    faceLandmarkerOptions.baseOptions.modelAssetPath = modelPath
    faceLandmarkerOptions.baseOptions.delegate = self.delegate
    faceLandmarkerOptions.outputFaceBlendshapes = true
    faceLandmarkerOptions.outputFacialTransformationMatrixes = true

    if runningMode == .liveStream {
      faceLandmarkerOptions.faceLandmarkerLiveStreamDelegate = self
    }

    do {
      faceLandmarker = try FaceLandmarker(options: faceLandmarkerOptions)
    } catch {
      print(error)
    }
  }

  // MARK: - Static Initializers
  static func liveStreamFaceLandmarkerService(
    modelPath: String?,
    liveStreamDelegate: FaceLandmarkerServiceLiveStreamDelegate?,
    delegate: Delegate) -> FaceLandmarkerService? {
      let faceLandmarkerService = FaceLandmarkerService(
        modelPath: modelPath,
        runningMode: .liveStream,
        delegate: delegate)
      faceLandmarkerService?.liveStreamDelegate = liveStreamDelegate

      return faceLandmarkerService
    }

  static func stillImageFaceLandmarkerService(
    modelPath: String?,
    delegate: Delegate) -> FaceLandmarkerService? {
      let faceLandmarkerService = FaceLandmarkerService(
        modelPath: modelPath,
        runningMode: .image,
        delegate: delegate)

      return faceLandmarkerService
    }

  // MARK: - Landmark Detection Methods for Different Modes
  /**
   This method returns FaceLandmarkerResult and inferenceTime when receive an image
   **/
  func detectLandmarks(image: UIImage) -> FaceLandmarkerResultBundle? {
    guard let cgImage = image.fixedOrientation() else { return nil }
    let fixImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    guard let mpImage = try? MPImage(uiImage: fixImage) else {
      return nil
    }
    do {
      let startDate = Date()
      let result = try faceLandmarker?.detect(image: mpImage)
      let inferenceTime = Date().timeIntervalSince(startDate) * 1000
      return FaceLandmarkerResultBundle(inferenceTime: inferenceTime, faceLandmarkerResults: [result])
    } catch {
      print(error)
      return nil
    }
  }

  func detectLandmarksAsync(
    sampleBuffer: CMSampleBuffer,
    orientation: UIImage.Orientation,
    timeStamps: Int) {
      guard let image = try? MPImage(sampleBuffer: sampleBuffer, orientation: orientation) else {
        return
      }
      do {
        try faceLandmarker?.detectAsync(image: image, timestampInMilliseconds: timeStamps)
      } catch {
        print(error)
      }
    }
}

// MARK: - FaceLandmarkerLiveStreamDelegate Methods
extension FaceLandmarkerService: FaceLandmarkerLiveStreamDelegate {
  func faceLandmarker(_ faceLandmarker: FaceLandmarker, didFinishDetection result: FaceLandmarkerResult?, timestampInMilliseconds: Int, error: Error?) {
    let resultBundle = FaceLandmarkerResultBundle(
      inferenceTime: Date().timeIntervalSince1970 * 1000 - Double(timestampInMilliseconds),
      faceLandmarkerResults: [result])
    liveStreamDelegate?.faceLandmarkerService(
      self,
      didFinishLandmarkDetection: resultBundle,
      error: error)
  }
}

/// A result from the `FaceLandmarkerService`.
struct FaceLandmarkerResultBundle {
  let inferenceTime: Double
  let faceLandmarkerResults: [FaceLandmarkerResult?]
  var size: CGSize = .zero
}
