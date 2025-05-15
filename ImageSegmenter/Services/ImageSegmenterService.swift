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
 This protocol must be adopted by any class that wants to get the segmention results of the image segmenter in live stream mode.
 */
protocol ImageSegmenterServiceLiveStreamDelegate: AnyObject {
  func imageSegmenterService(_ imageSegmenterService: ImageSegmenterService,
                             didFinishSegmention result: ResultBundle?,
                             error: Error?)
}

/**
 This protocol must be adopted by any class that wants to take appropriate actions during  different stages of image segmenter on videos.
 */
// protocol ImageSegmenterServiceVideoDelegate: AnyObject {
//  func imageSegmenterService(_ imageSegmenterService: ImageSegmenterService,
//                             didFinishSegmentionOnVideoFrame index: Int)
//  func imageSegmenterService(_ imageSegmenterService: ImageSegmenterService,
//                             willBeginSegmention totalframeCount: Int)
// }

// Initializes and calls the MediaPipe APIs for segmention.
class ImageSegmenterService: NSObject {

  weak var liveStreamDelegate: ImageSegmenterServiceLiveStreamDelegate?
  //  weak var videoDelegate: ImageSegmenterServiceVideoDelegate?

  var imageSegmenter: ImageSegmenter?
  private(set) var runningMode = RunningMode.image
  var modelPath: String
  var delegate: Delegate

  // MARK: - Custom Initializer
  private init?(modelPath: String?,
                runningMode: RunningMode,
                delegate: Delegate) {
    print("ImageSegmenterService: init? called with modelPath: \(modelPath ?? "nil")")
    guard let modelPath = modelPath else {
        print("ImageSegmenterService: init? - modelPath is nil. Returning nil from initializer.")
        return nil
    }
    self.modelPath = modelPath
    self.runningMode = runningMode
    self.delegate = delegate
    super.init()
    print("ImageSegmenterService: init? - Properties set. ModelPath: \(self.modelPath). Calling createImageSegmenter().")

    createImageSegmenter()
    if self.imageSegmenter == nil {
        print("ImageSegmenterService: init? - WARNING: createImageSegmenter() finished, but self.imageSegmenter is still nil. The MediaPipe ImageSegmenter might have failed to initialize.")
        // Though the init doesn't return nil here, this is a critical state.
    }
  }

  private func createImageSegmenter() {
    print("ImageSegmenterService: createImageSegmenter() called. ModelPath for options: \(self.modelPath)")
    let imageSegmenterOptions = ImageSegmenterOptions()
    imageSegmenterOptions.runningMode = runningMode
    imageSegmenterOptions.shouldOutputCategoryMask = true
    imageSegmenterOptions.baseOptions.modelAssetPath = self.modelPath 
    imageSegmenterOptions.baseOptions.delegate = self.delegate
    if runningMode == .liveStream {
      imageSegmenterOptions.imageSegmenterLiveStreamDelegate = self
    }
    do {
      imageSegmenter = try ImageSegmenter(options: imageSegmenterOptions)
      print("ImageSegmenterService: createImageSegmenter - Successfully created MediaPipe ImageSegmenter.")
    } catch {
      print("ImageSegmenterService: createImageSegmenter - FAILED to create MediaPipe ImageSegmenter. Error: \(error)")
      // self.imageSegmenter will remain nil
    }
  }

  // MARK: - Static Initializers
  static func videoImageSegmenterService(
    modelPath: String?,
    delegate: Delegate) -> ImageSegmenterService? {
      let imageSegmenterService = ImageSegmenterService(
        modelPath: modelPath,
        runningMode: .video,
      delegate: delegate)
      print("ImageSegmenterService: videoImageSegmenterService factory method called with modelPath: \(modelPath ?? "nil")")
      if imageSegmenterService == nil {
          print("ImageSegmenterService: videoImageSegmenterService - ImageSegmenterService(init?) returned nil.")
      } else {
          print("ImageSegmenterService: videoImageSegmenterService - ImageSegmenterService(init?) succeeded.")
      }
      return imageSegmenterService
    }

  static func liveStreamImageSegmenterService(
    modelPath: String?,
    liveStreamDelegate: ImageSegmenterServiceLiveStreamDelegate?,
    delegate: Delegate) -> ImageSegmenterService? {
      print("ImageSegmenterService: liveStreamImageSegmenterService factory method called with modelPath: \(modelPath ?? "nil")")
      let imageSegmenterService = ImageSegmenterService(
        modelPath: modelPath,
        runningMode: .liveStream,
      delegate: delegate)
      if imageSegmenterService == nil {
          print("ImageSegmenterService: liveStreamImageSegmenterService - ImageSegmenterService(init?) returned nil.")
      } else {
          print("ImageSegmenterService: liveStreamImageSegmenterService - ImageSegmenterService(init?) succeeded. Assigning liveStreamDelegate.")
      }
      imageSegmenterService?.liveStreamDelegate = liveStreamDelegate

      return imageSegmenterService
    }

  static func stillImageSegmenterService(
    modelPath: String?,
    delegate: Delegate) -> ImageSegmenterService? {
      let imageSegmenterService = ImageSegmenterService(
        modelPath: modelPath,
        runningMode: .image,
      delegate: delegate)
      print("ImageSegmenterService: stillImageSegmenterService factory method called with modelPath: \(modelPath ?? "nil")")
      if imageSegmenterService == nil {
          print("ImageSegmenterService: stillImageSegmenterService - ImageSegmenterService(init?) returned nil.")
      } else {
          print("ImageSegmenterService: stillImageSegmenterService - ImageSegmenterService(init?) succeeded.")
      }
      return imageSegmenterService
    }

  // MARK: - Segmention Methods for Different Modes
  /**
   This method return ImageSegmenterResult and infrenceTime when receive an image
   **/
  func segment(image: UIImage) -> ResultBundle? {
    guard let cgImage = image.fixedOrientation() else { return nil }
    let fixImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    guard let mpImage = try? MPImage(uiImage: fixImage) else {
      return nil
    }
    do {
      let startDate = Date()
      let result = try imageSegmenter?.segment(image: mpImage)
      let inferenceTime = Date().timeIntervalSince(startDate) * 1000
      return ResultBundle(inferenceTime: inferenceTime, imageSegmenterResults: [result])
    } catch {
      print(error)
      return nil
    }
  }

  func segmentAsync(
    sampleBuffer: CMSampleBuffer,
    orientation: UIImage.Orientation,
    timeStamps: Int) {
      guard let image = try? MPImage(sampleBuffer: sampleBuffer, orientation: orientation) else {
        return
      }
      do {
        try imageSegmenter?.segmentAsync(image: image, timestampInMilliseconds: timeStamps)
      } catch {
        print(error)
      }
    }

  func segment(
    videoFrame: CGImage,
    orientation: UIImage.Orientation,
    timeStamps: Int)
  -> ResultBundle? {
    do {
      let mpImage = try MPImage(uiImage: UIImage(cgImage: videoFrame))
      let startDate = Date()
      let result = try imageSegmenter?.segment(videoFrame: mpImage, timestampInMilliseconds: timeStamps)
      let inferenceTime = Date().timeIntervalSince(startDate) * 1000
      return ResultBundle(inferenceTime: inferenceTime, imageSegmenterResults: [result])
    } catch {
      print(error)
      return nil
    }
  }
}

// MARK: - ImageSegmenterLiveStreamDelegate Methods
extension ImageSegmenterService: ImageSegmenterLiveStreamDelegate {
  func imageSegmenter(_ imageSegmenter: ImageSegmenter, didFinishSegmentation result: ImageSegmenterResult?, timestampInMilliseconds: Int, error: Error?) {
    let resultBundle = ResultBundle(
      inferenceTime: Date().timeIntervalSince1970 * 1000 - Double(timestampInMilliseconds),
      imageSegmenterResults: [result])
    liveStreamDelegate?.imageSegmenterService(
      self,
      didFinishSegmention: resultBundle,
      error: error)
  }
}

/// A result from the `ImageSegmenterService`.
struct ResultBundle {
  let inferenceTime: Double
  let imageSegmenterResults: [ImageSegmenterResult?]
  var size: CGSize = .zero
}

struct VideoFrame {
  let pixelBuffer: CVPixelBuffer
  let formatDescription: CMFormatDescription
}
