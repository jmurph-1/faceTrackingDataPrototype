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

import AVFoundation
import MediaPipeTasksVision
import UIKit
import Metal
import MetalKit
import MetalPerformanceShaders

/**
 * The view controller is responsible for performing segmention on incoming frames from the live camera and presenting the frames with the
 * new backgrourd to the user.
 */
class CameraViewController: UIViewController {
  private struct Constants {
    static let edgeOffset: CGFloat = 2.0
  }

  weak var inferenceResultDeliveryDelegate: InferenceResultDeliveryDelegate?

  @IBOutlet weak var previewView: PreviewMetalView!
  @IBOutlet weak var cameraUnavailableLabel: UILabel!
  @IBOutlet weak var resumeButton: UIButton!
  
  // UI elements for displaying color information
  private let skinColorLabel = UILabel()
  private let hairColorLabel = UILabel()

  private var videoPixelBuffer: CVImageBuffer!
  private var formatDescription: CMFormatDescription!
  private var isSessionRunning = false
  private var isObserving = false
  private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.cameraController.backgroundQueue")

  // MARK: Controllers that manage functionality
  // Handles all the camera related functionality
  private lazy var cameraFeedService = CameraFeedService()
  private let render = SegmentedImageRenderer()
  private let multiClassRenderer = MultiClassSegmentedImageRenderer()

  private let imageSegmenterServiceQueue = DispatchQueue(
    label: "com.google.mediapipe.cameraController.imageSegmenterServiceQueue",
    attributes: .concurrent)

  // Queuing reads and writes to imageSegmenterService using the Apple recommended way
  // as they can be read and written from multiple threads and can result in race conditions.
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

#if !targetEnvironment(simulator)
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    initializeImageSegmenterServiceOnSessionResumption()
    cameraFeedService.startLiveCameraSession {[weak self] cameraConfiguration in
      DispatchQueue.main.async {
        switch cameraConfiguration {
        case .failed:
          self?.presentVideoConfigurationErrorAlert()
        case .permissionDenied:
          self?.presentCameraPermissionsDeniedAlert()
        default:
          break
        }
      }
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    cameraFeedService.stopSession()
    clearImageSegmenterServiceOnSessionInterruption()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    cameraFeedService.delegate = self
    setupColorLabels()
  }
  
  private func setupColorLabels() {
    // Configure skin color label
    skinColorLabel.translatesAutoresizingMaskIntoConstraints = false
    skinColorLabel.textColor = .white
    skinColorLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    skinColorLabel.textAlignment = .center
    skinColorLabel.layer.cornerRadius = 5
    skinColorLabel.clipsToBounds = true
    skinColorLabel.font = UIFont.systemFont(ofSize: 12)
    skinColorLabel.text = "Skin: N/A"
    
    // Configure hair color label
    hairColorLabel.translatesAutoresizingMaskIntoConstraints = false
    hairColorLabel.textColor = .white
    hairColorLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    hairColorLabel.textAlignment = .center
    hairColorLabel.layer.cornerRadius = 5
    hairColorLabel.clipsToBounds = true
    hairColorLabel.font = UIFont.systemFont(ofSize: 12)
    hairColorLabel.text = "Hair: N/A"
    
    // Add labels to view
    view.addSubview(skinColorLabel)
    view.addSubview(hairColorLabel)
    
    // Set constraints to position labels in top left corner
    NSLayoutConstraint.activate([
      skinColorLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
      skinColorLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
      skinColorLabel.widthAnchor.constraint(equalToConstant: 180),
      skinColorLabel.heightAnchor.constraint(equalToConstant: 30),
      
      hairColorLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
      hairColorLabel.topAnchor.constraint(equalTo: skinColorLabel.bottomAnchor, constant: 5),
      hairColorLabel.widthAnchor.constraint(equalToConstant: 180),
      hairColorLabel.heightAnchor.constraint(equalToConstant: 30)
    ])
    
    // Initially hide the labels
    skinColorLabel.isHidden = true
    hairColorLabel.isHidden = true
  }

#endif

  // Resume camera session when click button resume
  @IBAction func onClickResume(_ sender: Any) {
    cameraFeedService.resumeInterruptedSession {[weak self] isSessionRunning in
      if isSessionRunning {
        self?.resumeButton.isHidden = true
        self?.cameraUnavailableLabel.isHidden = true
        self?.initializeImageSegmenterServiceOnSessionResumption()
      }
    }
  }

  private func presentCameraPermissionsDeniedAlert() {
    let alertController = UIAlertController(
      title: "Camera Permissions Denied",
      message:
        "Camera permissions have been denied for this app. You can change this by going to Settings",
      preferredStyle: .alert)

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
      UIApplication.shared.open(
        URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
    }
    alertController.addAction(cancelAction)
    alertController.addAction(settingsAction)

    present(alertController, animated: true, completion: nil)
  }

  private func presentVideoConfigurationErrorAlert() {
    let alert = UIAlertController(
      title: "Camera Configuration Failed",
      message: "There was an error while configuring camera.",
      preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

    self.present(alert, animated: true)
  }

  private func initializeImageSegmenterServiceOnSessionResumption() {
    clearAndInitializeImageSegmenterService()
    startObserveConfigChanges()
  }

  @objc private func clearAndInitializeImageSegmenterService() {
    imageSegmenterService = nil
    imageSegmenterService = ImageSegmenterService
      .liveStreamImageSegmenterService(
        modelPath: InferenceConfigurationManager.sharedInstance.model.modelPath,
        liveStreamDelegate: self,
        delegate: InferenceConfigurationManager.sharedInstance.delegate)
    
    // Update UI based on selected model
    DispatchQueue.main.async {
      self.updateUIForCurrentModel()
    }
  }
  
  private func updateUIForCurrentModel() {
    let isMultiClass = InferenceConfigurationManager.sharedInstance.model == .multiClassSegmentation
    skinColorLabel.isHidden = !isMultiClass
    hairColorLabel.isHidden = !isMultiClass
  }

  private func clearImageSegmenterServiceOnSessionInterruption() {
    stopObserveConfigChanges()
    imageSegmenterService = nil
  }

  private func startObserveConfigChanges() {
    NotificationCenter.default
      .addObserver(self,
                   selector: #selector(clearAndInitializeImageSegmenterService),
                   name: InferenceConfigurationManager.notificationName,
                   object: nil)
    isObserving = true
  }

  private func stopObserveConfigChanges() {
    if isObserving {
      NotificationCenter.default
        .removeObserver(self,
                        name:InferenceConfigurationManager.notificationName,
                        object: nil)
    }
    isObserving = false
  }
  
  private func updateColorDisplay(_ colorInfo: MultiClassSegmentedImageRenderer.ColorInfo) {
    // Update skin color label
    let skinRGB = colorInfo.skinColor.cgColor.components
    let skinHSV = colorInfo.skinColorHSV
    
    if let skinRGB = skinRGB, skinRGB.count >= 3 {
      let skinRGBString = String(format: "Skin: RGB(%.0f,%.0f,%.0f)", skinRGB[0]*255, skinRGB[1]*255, skinRGB[2]*255)
      let skinHSVString = String(format: " HSV(%.0f,%.0f,%.0f)", skinHSV.h*360, skinHSV.s*100, skinHSV.v*100)
      skinColorLabel.text = skinRGBString + skinHSVString
    }
    
    // Update hair color label
    let hairRGB = colorInfo.hairColor.cgColor.components
    let hairHSV = colorInfo.hairColorHSV
    
    if let hairRGB = hairRGB, hairRGB.count >= 3 {
      let hairRGBString = String(format: "Hair: RGB(%.0f,%.0f,%.0f)", hairRGB[0]*255, hairRGB[1]*255, hairRGB[2]*255)
      let hairHSVString = String(format: " HSV(%.0f,%.0f,%.0f)", hairHSV.h*360, hairHSV.s*100, hairHSV.v*100)
      hairColorLabel.text = hairRGBString + hairHSVString
    }
  }
}

extension CameraViewController: CameraFeedServiceDelegate {

  func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
    let currentTimeMs = Date().timeIntervalSince1970 * 1000
    guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
      return
    }

    self.videoPixelBuffer = videoPixelBuffer
    self.formatDescription = formatDescription

    backgroundQueue.async { [weak self] in
      self?.imageSegmenterService?.segmentAsync(
        sampleBuffer: sampleBuffer,
        orientation: orientation,
        timeStamps: Int(currentTimeMs))
    }
  }

  // MARK: Session Handling Alerts
  func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
    // Updates the UI when session is interupted.
    if resumeManually {
      resumeButton.isHidden = false
    } else {
      cameraUnavailableLabel.isHidden = false
    }
    clearImageSegmenterServiceOnSessionInterruption()
  }

  func sessionInterruptionEnded() {
    // Updates UI once session interruption has ended.
    cameraUnavailableLabel.isHidden = true
    resumeButton.isHidden = true
    initializeImageSegmenterServiceOnSessionResumption()
  }

  func didEncounterSessionRuntimeError() {
    // Handles session run time error by updating the UI and providing a button if session can be
    // manually resumed.
    resumeButton.isHidden = false
    clearImageSegmenterServiceOnSessionInterruption()
  }
}

// MARK: ImageSegmenterServiceLiveStreamDelegate
extension CameraViewController: ImageSegmenterServiceLiveStreamDelegate {

  func imageSegmenterService(_ imageSegmenterService: ImageSegmenterService, didFinishSegmention result: ResultBundle?, error: Error?) {
    guard let imageSegmenterResult = result?.imageSegmenterResults.first as? ImageSegmenterResult,
      let confidenceMasks = imageSegmenterResult.categoryMask else { return }
    let confidenceMask = confidenceMasks.uint8Data

    // Choose renderer based on the selected model
    if InferenceConfigurationManager.sharedInstance.model == .multiClassSegmentation {
      if !multiClassRenderer.isPrepared {
        multiClassRenderer.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
      }
      
      let outputPixelBuffer = multiClassRenderer.render(pixelBuffer: videoPixelBuffer, segmentDatas: confidenceMask)
      
      // Extract and display color information
      let colorInfo = multiClassRenderer.getCurrentColorInfo()
      DispatchQueue.main.async { [weak self] in
        self?.updateColorDisplay(colorInfo)
      }
      
      previewView.pixelBuffer = outputPixelBuffer
    } else {
      if !render.isPrepared {
        render.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
      }
      
      let outputPixelBuffer = render.render(pixelBuffer: videoPixelBuffer, segmentDatas: confidenceMask)
      previewView.pixelBuffer = outputPixelBuffer
    }
    
    inferenceResultDeliveryDelegate?.didPerformInference(result: result)
  }
}

// MARK: - AVLayerVideoGravity Extension
extension AVLayerVideoGravity {
  var contentMode: UIView.ContentMode {
    switch self {
    case .resizeAspectFill:
      return .scaleAspectFill
    case .resizeAspect:
      return .scaleAspectFit
    case .resize:
      return .scaleToFill
    default:
      return .scaleAspectFit
    }
  }
}
