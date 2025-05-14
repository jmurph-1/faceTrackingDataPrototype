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
import SwiftUI

/**
 * The view controller is responsible for performing segmention on incoming frames from the live camera and presenting the frames with the
 * new backgrourd to the user.
 */
class CameraViewController: UIViewController, FaceLandmarkerServiceLiveStreamDelegate {
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

  // Frame quality UI elements
  private let frameQualityView = FrameQualityIndicatorView(qualityScore: FrameQualityService.QualityScore(
      overall: 0.0,
      faceSize: 0.0,
      facePosition: 0.0,
      brightness: 0.0,
      sharpness: 0.0
  ))
  private var currentFrameQualityScore: FrameQualityService.QualityScore?
  
  private var frameQualityHostingController: UIHostingController<FrameQualityIndicatorView>?
  private let analyzeButton = UIButton(type: .system)

  // Face landmark detection toggle
  private let faceTrackingLabel = UILabel()
  private let faceTrackingSwitch = UISwitch()

  // Track the face tracking state to avoid accessing UI from background threads
  private var isFaceTrackingEnabled = false

  private var videoPixelBuffer: CVImageBuffer!
  private var formatDescription: CMFormatDescription!
  private var isSessionRunning = false
  private var isObserving = false
  private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.cameraController.backgroundQueue")

  // UI overlay for displaying landmarks 
  private var landmarksOverlayView: UIView?
  private var landmarkDots: [UIView] = []

  // Debug overlay
  private var debugOverlayHostingController: UIHostingController<DebugOverlayView>?
  private var isDebugOverlayVisible = true {
    didSet {
      print("isDebugOverlayVisible changed to: \(isDebugOverlayVisible)")
    }
  }

  // Throttling properties for classification
  private var lastClassificationTime: TimeInterval = 0
  private let classificationThrottleInterval: TimeInterval = 0.1  // 10Hz throttle (10 frames per second)

  // MARK: Controllers that manage functionality
  // Handles all the camera related functionality
  private lazy var cameraService = CameraService()
  private let segmentationService = SegmentationService()
  private let classificationService = ClassificationService()
  private var toastService: ToastService!
  // These will now be handled by SegmentationService
  // private let render = SegmentedImageRenderer()
  // private let multiClassRenderer = MultiClassSegmentedImageRenderer()
  // Non-optional face landmark renderer
  private let faceLandmarkRenderer = FaceLandmarkRenderer()

  private let imageSegmenterServiceQueue = DispatchQueue(
    label: "com.google.mediapipe.cameraController.imageSegmenterServiceQueue",
    attributes: .concurrent)

  private let faceLandmarkerServiceQueue = DispatchQueue(
    label: "com.google.mediapipe.cameraController.faceLandmarkerServiceQueue",
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

  // Queuing reads and writes to faceLandmarkerService to avoid race conditions
  private var _faceLandmarkerService: FaceLandmarkerService?
  private var faceLandmarkerService: FaceLandmarkerService? {
    get {
      faceLandmarkerServiceQueue.sync {
        return self._faceLandmarkerService
      }
    }
    set {
      faceLandmarkerServiceQueue.async(flags: .barrier) {
        self._faceLandmarkerService = newValue
      }
    }
  }

  // Store the latest face landmark result
  private var lastFaceLandmarkerResult: FaceLandmarkerResult?
  private var lastFaceLandmarks: [NormalizedLandmark]?

#if !targetEnvironment(simulator)
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    initializeImageSegmenterServiceOnSessionResumption()
    cameraService.startLiveCameraSession {[weak self] cameraConfiguration in
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
    cameraService.stopSession()
    clearImageSegmenterServiceOnSessionInterruption()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    cameraService.delegate = self
    segmentationService.delegate = self
    classificationService.delegate = self
    setupColorLabels()
    setupFrameQualityUI()
    setupFaceTrackingControls()
    setupDebugOverlay()
    setupGestures()

    // Initialize toast service
    toastService = ToastService(containerView: view)

    // Register for app lifecycle notifications
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  deinit {
    // Remove app lifecycle observers
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  @objc private func handleAppWillEnterForeground() {
    // Reinitialize services based on current state when app returns to foreground
    if isFaceTrackingEnabled {
      // Reinitialize face tracking
      clearFaceLandmarkerServiceOnSessionInterruption()
      initializeFaceLandmarkerServiceOnSessionResumption()
      print("Reinitialized face tracking after returning to foreground")
    } else {
      // Reinitialize segmentation
      clearImageSegmenterServiceOnSessionInterruption()
      initializeImageSegmenterServiceOnSessionResumption()

      // Reset the renderers to ensure they're properly initialized
      // as they need the formatDescription which comes from the camera feed
      print("Reinitialized segmentation after returning to foreground")
    }

    // Make sure the preview view's pixel buffer is cleared to force redraw
    previewView.pixelBuffer = nil
    previewView.flushTextureCache()
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

  private func setupFrameQualityUI() {
    // Configure frame quality view
    self.frameQualityHostingController = UIHostingController(rootView: frameQualityView)
    self.frameQualityHostingController?.view.translatesAutoresizingMaskIntoConstraints = false
    self.frameQualityHostingController?.view.backgroundColor = .clear

    if let hostingController = self.frameQualityHostingController {
      addChild(hostingController)
      view.addSubview(hostingController.view)
      hostingController.didMove(toParent: self)

      // Position it at the bottom center above the analyze button
      NSLayoutConstraint.activate([
          hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
          hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
          hostingController.view.widthAnchor.constraint(equalToConstant: 300)
      ])
    }

    // Configure analyze button
    analyzeButton.translatesAutoresizingMaskIntoConstraints = false
    analyzeButton.setTitle("Analyze", for: .normal)
    analyzeButton.backgroundColor = UIColor.systemBlue
    analyzeButton.setTitleColor(.white, for: .normal)
    analyzeButton.layer.cornerRadius = 22
    analyzeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
    analyzeButton.addTarget(self, action: #selector(analyzeButtonTapped), for: .touchUpInside)

    // Initially disable the analyze button
    updateAnalyzeButtonState()

    view.addSubview(analyzeButton)

    NSLayoutConstraint.activate([
        analyzeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        analyzeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        analyzeButton.widthAnchor.constraint(equalToConstant: 200),
        analyzeButton.heightAnchor.constraint(equalToConstant: 44)
    ])
  }

  private func setupFaceTrackingControls() {
    // Configure face tracking label
    faceTrackingLabel.translatesAutoresizingMaskIntoConstraints = false
    faceTrackingLabel.textColor = .white
    faceTrackingLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    faceTrackingLabel.textAlignment = .center
    faceTrackingLabel.layer.cornerRadius = 5
    faceTrackingLabel.clipsToBounds = true
    faceTrackingLabel.font = UIFont.systemFont(ofSize: 12)
    faceTrackingLabel.text = "Face Tracking:"

    // Configure face tracking switch
    faceTrackingSwitch.translatesAutoresizingMaskIntoConstraints = false
    faceTrackingSwitch.isOn = false // Default to segmentation mode
    isFaceTrackingEnabled = faceTrackingSwitch.isOn // Initialize the tracking property
    faceTrackingSwitch.addTarget(self, action: #selector(faceTrackingSwitchChanged(_:)), for: .valueChanged)

    // Add to view
    view.addSubview(faceTrackingLabel)
    view.addSubview(faceTrackingSwitch)

    // Position controls in top right corner
    NSLayoutConstraint.activate([
      faceTrackingLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -60),
      faceTrackingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
      faceTrackingLabel.widthAnchor.constraint(equalToConstant: 100),
      faceTrackingLabel.heightAnchor.constraint(equalToConstant: 30),

      faceTrackingSwitch.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
      faceTrackingSwitch.centerYAnchor.constraint(equalTo: faceTrackingLabel.centerYAnchor)
    ])
  }

  @objc private func faceTrackingSwitchChanged(_ sender: UISwitch) {
    // Update our tracking property when the switch changes
    isFaceTrackingEnabled = sender.isOn

    if isFaceTrackingEnabled {
      // Enable face tracking, disable segmentation
      clearImageSegmenterServiceOnSessionInterruption()
      initializeFaceLandmarkerServiceOnSessionResumption()
      // Hide color information labels
      skinColorLabel.isHidden = true
      hairColorLabel.isHidden = true
      print("Face tracking enabled")
    } else {
      // Enable segmentation, disable face tracking
      clearFaceLandmarkerServiceOnSessionInterruption()
      initializeImageSegmenterServiceOnSessionResumption()
      // Show or hide color labels based on the selected model
      updateUIForCurrentModel()

      // Ensure all landmarks are cleared when toggling off
      clearLandmarksOverlay()
      // Hide the landmarks overlay view
      landmarksOverlayView?.isHidden = true

      print("Face tracking disabled")
    }
  }

#endif

  // Resume camera session when click button resume
  @IBAction func onClickResume(_ sender: Any) {
    cameraService.resumeInterruptedSession {[weak self] isSessionRunning in
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
    let settingsAction = UIAlertAction(title: "Settings", style: .default) { (_) in
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
    // Initialize segmentation service
      segmentationService.configure(with: InferenceConfigurationManager.sharedInstance.model.modelPath!)
    segmentationService.delegate = self
    startObserveConfigChanges()

    // Only initialize face landmarker if switch is on AND we're not doing segmentation
    if isFaceTrackingEnabled && segmentationService.getCurrentColorInfo().skinColor == nil {
      initializeFaceLandmarkerServiceOnSessionResumption()
    }
  }

  private func initializeFaceLandmarkerServiceOnSessionResumption() {
    clearAndInitializeFaceLandmarkerService()
  }

  @objc private func clearAndInitializeImageSegmenterService() {
    segmentationService.clearImageSegmenterService()
      segmentationService.configure(with: InferenceConfigurationManager.sharedInstance.model.modelPath!)

    // Update UI based on selected model
    DispatchQueue.main.async {
      self.updateUIForCurrentModel()
    }
  }

  @objc private func clearAndInitializeFaceLandmarkerService() {
    faceLandmarkerService = nil
    faceLandmarkerService = FaceLandmarkerService
      .liveStreamFaceLandmarkerService(
        modelPath: Bundle.main.path(forResource: "face_landmarker", ofType: "task"),
        liveStreamDelegate: self,
        delegate: InferenceConfigurationManager.sharedInstance.delegate)
  }

  private func updateUIForCurrentModel() {
    // Since we only have one model now (multiClassSegmentation), 
    // we just need to check if it's enabled or if face tracking is enabled
    if isFaceTrackingEnabled {
      // Face tracking mode - hide segmentation UI
      skinColorLabel.isHidden = true
      hairColorLabel.isHidden = true
    } else {
      // Segmentation mode - always show color labels since there's only one model type now
      skinColorLabel.isHidden = false
      hairColorLabel.isHidden = false
    }
  }

  private func clearImageSegmenterServiceOnSessionInterruption() {
    segmentationService.clearImageSegmenterService()
    stopObserveConfigChanges()

    // Also clear face landmarker
    clearFaceLandmarkerServiceOnSessionInterruption()
  }

  private func clearFaceLandmarkerServiceOnSessionInterruption() {
    faceLandmarkerService = nil
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
                        name: InferenceConfigurationManager.notificationName,
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
      let hairRGBString = String(format: "Hair: RGB(%.0f,%.0f,%.0f)", hairRGB[0]*250, hairRGB[1]*250, hairRGB[2]*250)
      let hairHSVString = String(format: " HSV(%.0f,%.0f,%.0f)", hairHSV.h*360, hairHSV.s*100, hairHSV.v*100)
      hairColorLabel.text = hairRGBString + hairHSVString
    }
  }

  // Face landmarker service callback (formerly in extension)
  func faceLandmarkerService(
    _ faceLandmarkerService: FaceLandmarkerService,
    didFinishLandmarkDetection result: FaceLandmarkerResultBundle?,
    error: Error?) {

    // Only process landmarks if face tracking is still enabled
    // This prevents processing after toggling face tracking off
    if !isFaceTrackingEnabled {
      return
    }

    // Simply use the original video frame for now
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      if let error = error {
        print("Face landmark error: \(error)")
      }

      // Debug the pixel buffer
      if let pixelBuffer = self.videoPixelBuffer {
        // Only debug logs in debug builds to reduce console spam
        #if DEBUG
        self.debugPixelBuffer(pixelBuffer, label: "Video pixel buffer for preview")
        #endif

        // First approach - direct display of camera frame
        // This approach should be reliable but doesn't show landmarks
        self.previewView.pixelBuffer = pixelBuffer

        // Only print logs in debug builds
        #if DEBUG
        print("Preview view updated with pixel buffer")
        #endif

        // Make sure landmark overlay view is visible when face tracking is on
        self.landmarksOverlayView?.isHidden = false

        // Detect landmarks
        if let faceLandmarkerResults = result?.faceLandmarkerResults,
           let firstResult = faceLandmarkerResults.first,
           let faceLandmarkerResult = firstResult,
           !faceLandmarkerResult.faceLandmarks.isEmpty,
           let landmarks = faceLandmarkerResult.faceLandmarks.first {

          // Only print logs in debug builds
          #if DEBUG
          print("Received \(landmarks.count) landmarks")
          #endif

          self.lastFaceLandmarks = landmarks
          
          self.segmentationService.updateFaceLandmarks(landmarks)
          print("Updated face landmarks for quality calculation: \(landmarks.count) points")

          // Add visual feedback by overlaying a UIView with dots for landmarks
          if self.landmarksOverlayView == nil {
            self.setupLandmarksOverlayView()
          }

          // Update the landmarks display
          self.updateLandmarksOverlay(with: landmarks)
        } else {
          self.lastFaceLandmarks = nil

          // Only print logs in debug builds
          #if DEBUG
          print("No face landmarks detected")
          #endif

          // Clear landmarks display if needed
          self.clearLandmarksOverlay()
        }
      } else {
        // Only print logs in debug builds
        #if DEBUG
        print("ERROR: No video pixel buffer available for preview")
        #endif
      }
    }
  }

  private func setupLandmarksOverlayView() {
    // Create an overlay view that covers the preview
    let overlayView = UIView(frame: previewView.bounds)
    overlayView.backgroundColor = .clear
    overlayView.isUserInteractionEnabled = false
    overlayView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(overlayView)

    // Make the overlay view match the preview view's size and position
    NSLayoutConstraint.activate([
      overlayView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
      overlayView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
      overlayView.topAnchor.constraint(equalTo: previewView.topAnchor),
      overlayView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor)
    ])

    landmarksOverlayView = overlayView
  }

  private func updateLandmarksOverlay(with landmarks: [NormalizedLandmark]) {
    guard let overlayView = landmarksOverlayView else { return }

    // Remove previous landmark dots
    for dot in landmarkDots {
      dot.removeFromSuperview()
    }
    landmarkDots.removeAll()

    // Only draw a subset of landmarks for better performance (e.g., every 5th landmark)
    let strideAmount = 5
    let selectedLandmarks = stride(from: 0, to: min(landmarks.count, 468), by: strideAmount)

    for landmarkIndex in selectedLandmarks {
      guard landmarkIndex < landmarks.count else { continue }
      let landmark = landmarks[landmarkIndex]

      // Convert normalized coordinates to view coordinates
      let pointX = CGFloat(landmark.x) * overlayView.bounds.width
      let pointY = CGFloat(landmark.y) * overlayView.bounds.height

      // Create a dot to represent the landmark
      let dotSize: CGFloat = 4.0
      let dotView = UIView(frame: CGRect(x: pointX - dotSize/2, y: pointY - dotSize/2, width: dotSize, height: dotSize))

      // Color based on landmark type/index
      let dotColor: UIColor
      if landmarkIndex < 36 { // Face contour
        dotColor = .red
      } else if landmarkIndex < 68 { // Eyes
        dotColor = .green
      } else if landmarkIndex < 106 { // Lips
        dotColor = .blue
      } else {
        dotColor = .yellow
      }

      dotView.backgroundColor = dotColor
      dotView.layer.cornerRadius = dotSize / 2

      overlayView.addSubview(dotView)
      landmarkDots.append(dotView)
    }
  }

  private func clearLandmarksOverlay() {
    // Remove all landmark dots
    for dot in landmarkDots {
      dot.removeFromSuperview()
    }
    landmarkDots.removeAll()
    lastFaceLandmarks = nil
  }

  // Helper method to debug pixel buffer properties
  private func debugPixelBuffer(_ pixelBuffer: CVPixelBuffer, label: String) {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
    let formatStr: String
    switch format {
    case kCVPixelFormatType_32BGRA: formatStr = "32BGRA"
    case kCVPixelFormatType_32RGBA: formatStr = "32RGBA"
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: formatStr = "420YpCbCr8BiPlanarVideoRange"
    default: formatStr = String(format: "Unknown (0x%08x)", format)
    }
    print("\(label): \(width)x\(height) \(formatStr)")
  }

  // Convert UIImage to CVPixelBuffer
  private func pixelBufferFromUIImage(_ image: UIImage) -> CVPixelBuffer? {
    let width = Int(image.size.width)
    let height = Int(image.size.height)

    let attributes: [String: Any] = [
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]

    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attributes as CFDictionary,
      &pixelBuffer
    )

    guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
    let context = CGContext(
      data: CVPixelBufferGetBaseAddress(buffer),
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )

    if let context = context {
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 1, y: -1)
      UIGraphicsPushContext(context)
      image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
      UIGraphicsPopContext()
    }

    CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
    return buffer
  }

  // Helper to create a Metal texture from a CVPixelBuffer
  private func createTextureFromPixelBuffer(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)

    var textureCache: CVMetalTextureCache?
    let device = MTLCreateSystemDefaultDevice()!
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)

    guard let cache = textureCache else { return nil }

    var cvTextureOut: CVMetalTexture?
    CVMetalTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault,
      cache,
      pixelBuffer,
      nil,
      .bgra8Unorm,
      width,
      height,
      0,
      &cvTextureOut)

    guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
      return nil
    }

    return texture
  }

  // MARK: - Quality-related properties
  private var isFrameQualitySufficientForAnalysis: Bool {
    return currentFrameQualityScore?.isAcceptableForAnalysis ?? false
  }

  // Handle analyze button tap
  @objc private func analyzeButtonTapped() {
    guard let qualityScore = currentFrameQualityScore, qualityScore.isAcceptableForAnalysis else {
      return
    }

    // Show loading indicator
    let loadingIndicator = UIActivityIndicatorView(style: .large)
    loadingIndicator.center = view.center
    loadingIndicator.startAnimating()
    view.addSubview(loadingIndicator)

    // Use classification service to analyze the frame
    if let pixelBuffer = self.videoPixelBuffer {
      let colorInfo = self.segmentationService.getCurrentColorInfo()
      classificationService.analyzeFrame(pixelBuffer: pixelBuffer, colorInfo: colorInfo)
    } else {
      // Handle error case - no pixel buffer
      DispatchQueue.main.async {
        loadingIndicator.removeFromSuperview()

        // Show error alert
        let alert = UIAlertController(
          title: "Analysis Failed",
          message: "Could not access video frame. Please try again.",
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
      }
    }
  }

  // Present analysis result view
  private func presentAnalysisResultView(result: AnalysisResult) {
    // Create view model and update with result
    let viewModel = AnalysisResultViewModel()
    viewModel.updateWithResult(result)

    // Create hosting controller for SwiftUI view
    let resultView = AnalysisResultView(
      viewModel: viewModel,
      onDismiss: { [weak self] in
        self?.dismiss(animated: true)
      },
      onRetry: { [weak self] in
        self?.dismiss(animated: true)
      },
      onSeeDetails: { [weak self] in
        // Stub for future expansion
        self?.dismiss(animated: true)
      }
    )

    let hostingController = UIHostingController(rootView: resultView)
    hostingController.modalPresentationStyle = .pageSheet

    present(hostingController, animated: true)
  }

  // Update the analyze button state based on frame quality
  private func updateAnalyzeButtonState() {
    analyzeButton.isEnabled = isFrameQualitySufficientForAnalysis
    analyzeButton.alpha = isFrameQualitySufficientForAnalysis ? 1.0 : 0.5
  }

  private func setupDebugOverlay() {
    // Create debug overlay view
    let debugOverlayView = DebugOverlayView(
      fps: 0,
      skinColorLab: nil,
      hairColorLab: nil,
      deltaEToSeasons: nil,
      qualityScore: nil
    )

    // Create hosting controller
    debugOverlayHostingController = UIHostingController(rootView: debugOverlayView)
    if let hostingController = debugOverlayHostingController {
      hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      hostingController.view.backgroundColor = .clear

      // Add to view hierarchy but initially hidden
      addChild(hostingController)
      view.addSubview(hostingController.view)
      hostingController.didMove(toParent: self)

      // Fill entire view
      NSLayoutConstraint.activate([
        hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
        hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      ])

      // Initially visible if isDebugOverlayVisible is true
      hostingController.view.isHidden = !isDebugOverlayVisible
      print("Debug overlay initial visibility: \(isDebugOverlayVisible), view.isHidden: \(hostingController.view.isHidden)")
    }
  }

  private func setupGestures() {
    // Add 3-finger tap gesture for debug overlay
    let threeTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleThreeTap))
    threeTapGesture.numberOfTouchesRequired = 3
    threeTapGesture.numberOfTapsRequired = 1
    view.addGestureRecognizer(threeTapGesture)
  }

  @objc private func handleThreeTap() {
    // Toggle debug overlay visibility
    isDebugOverlayVisible.toggle()
    debugOverlayHostingController?.view.isHidden = !isDebugOverlayVisible
  }

  // Update debug overlay with latest data
  private func updateDebugOverlay(fps: Float, colorInfo: MultiClassSegmentedImageRenderer.ColorInfo?, qualityScore: FrameQualityService.QualityScore?) {
    print("updateDebugOverlay called with qualityScore: \(String(describing: qualityScore))")
    
    // Ensure we're on the main thread for UI updates
    if !Thread.isMainThread {
      DispatchQueue.main.async {
        self.updateDebugOverlay(fps: fps, colorInfo: colorInfo, qualityScore: qualityScore)
      }
      return
    }

    guard isDebugOverlayVisible, let hostingController = debugOverlayHostingController else {
      print("Debug overlay not visible or hostingController is nil")
      return
    }

    // Convert color values to Lab if available
    var skinLab: ColorConverters.LabColor?
    var hairLab: ColorConverters.LabColor?
    var deltaEs: [SeasonClassifier.Season: CGFloat]?

    if let colorInfo = colorInfo {
      // Convert to Lab
      skinLab = ColorConverters.colorToLab(colorInfo.skinColor)
      hairLab = ColorConverters.colorToLab(colorInfo.hairColor)

      // Calculate delta-E to each season
      if let skinColorLab = skinLab {
        deltaEs = SeasonClassifier.calculateDeltaEToAllSeasons(skinLab: skinColorLab)
      }
    }

    // Debug print quality score before creating overlay view
    if let quality = qualityScore {
      print("Creating DebugOverlayView with quality score - Overall: \(quality.overall), FaceSize: \(quality.faceSize), Position: \(quality.facePosition), Brightness: \(quality.brightness), Sharpness: \(quality.sharpness)")
    } else {
      print("Creating DebugOverlayView with nil quality score")
    }
    
    // Create updated overlay view
    let updatedOverlayView = DebugOverlayView(
      fps: fps,
      skinColorLab: skinLab,
      hairColorLab: hairLab,
      deltaEToSeasons: deltaEs,
      qualityScore: qualityScore
    )

    // Update the hosting controller's root view
    hostingController.rootView = updatedOverlayView
    print("Debug overlay rootView updated with qualityScore: \(String(describing: qualityScore))")
  }

  private func setupErrorToast() {
    // Now handled by ToastService
  }

  // Show error toast message
  private func showErrorToast(_ message: String, duration: TimeInterval = 3.0) {
    toastService.showToast(message, duration: duration, type: .error)
  }

  // Check for error conditions and provide user guidance
  private func checkForErrorConditions() {
    // Get the current face bounding box and other data
    let faceBoundingBox = segmentationService.getCurrentFaceBoundingBox()
    let hasFace = faceBoundingBox != nil && !faceBoundingBox!.isEmpty

    // Check if any face was detected
    if !hasFace {
      toastService.showToast("No face detected. Please center your face in the frame.", type: .warning)
      return
    }

    // Check for quality issues
    if let qualityScore = currentFrameQualityScore {
      // Check overall quality first
      if qualityScore.overall < FrameQualityService.minimumQualityScoreForAnalysis {
        if let feedback = qualityScore.feedbackMessage {
          toastService.showToast(feedback, type: .warning)
          return
        }
      }

      // Check brightness issues
      if qualityScore.brightness < FrameQualityService.minimumBrightnessScoreForAnalysis {
        if qualityScore.brightness < 0.3 {
          toastService.showToast("Too dark. Please move to a brighter area.", type: .warning)
        } else if qualityScore.brightness > 0.9 {
          toastService.showToast("Too bright. Please reduce direct light on your face.", type: .warning)
        } else {
          toastService.showToast("Poor lighting detected. Please find better lighting.", type: .warning)
        }
        return
      }

      // Check face size and position
      if qualityScore.faceSize < FrameQualityService.minimumFaceSizeScoreForAnalysis {
        if qualityScore.faceSize < 0.3 {
          toastService.showToast("Face too small. Please move closer to the camera.", type: .warning)
        } else {
          toastService.showToast("Face position issue. Please center your face.", type: .warning)
        }
        return
      }

      // Check position
      if qualityScore.facePosition < FrameQualityService.minimumFacePositionScoreForAnalysis {
        toastService.showToast("Please center your face in the frame.", type: .warning)
        return
      }

      // Check sharpness
      if qualityScore.sharpness < 0.5 {
        toastService.showToast("Image is blurry. Please hold the device steady.", type: .warning)
        return
      }
    }

    // Check if color extraction failed
    let colorInfo = segmentationService.getCurrentColorInfo()
    if colorInfo.skinColor == nil {
      toastService.showToast("Unable to extract skin color. Please adjust lighting.", type: .error)
      return
    }

    // If all conditions are good, clear any error toast
    toastService.clearToast()
  }

  // Replace clearErrorToast method with toastService call
  private func clearErrorToast() {
    toastService.clearToast()
  }
}

// MARK: - CameraServiceDelegate
extension CameraViewController: CameraServiceDelegate {

  func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
    let currentTimeMs = Date().timeIntervalSince1970 * 1000
    guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
      print("Failed to get pixel buffer or format description from sample buffer")
      return
    }

    // Always update the current video pixel buffer for use in analysis
    self.videoPixelBuffer = videoPixelBuffer
    self.formatDescription = formatDescription

    // Get current time for throttling
    let currentTime = Date().timeIntervalSince1970
    let timeElapsedSinceLastClassification = currentTime - lastClassificationTime
    let shouldProcess = timeElapsedSinceLastClassification >= classificationThrottleInterval

    // Always process video frames, but throttle intensive operations
    backgroundQueue.async { [weak self] in
      guard let self = self else { return }

      // Face tracking has priority but should also be throttled
      if self.isFaceTrackingEnabled {
        if shouldProcess {
          // Update throttle timestamp
          self.lastClassificationTime = currentTime

          // Perform face landmark detection
          self.faceLandmarkerService?.detectLandmarksAsync(
            sampleBuffer: sampleBuffer,
            orientation: orientation,
            timeStamps: Int(currentTimeMs))
        }
      } else {
        // For regular segmentation, use the segmentation service
        self.segmentationService.processFrame(
          sampleBuffer: sampleBuffer,
          orientation: orientation,
          timeStamps: Int(currentTimeMs))

        // If it's time to update classification results, update the timestamp
        if shouldProcess {
          self.lastClassificationTime = currentTime
        }
      }
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

// MARK: - SegmentationServiceDelegate
extension CameraViewController: SegmentationServiceDelegate {
  func segmentationService(_ service: SegmentationService, didCompleteSegmentation result: SegmentationResult) {
    // Check for error conditions and provide guidance
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      // Update UI with segmentation results
      self.previewView.pixelBuffer = result.outputPixelBuffer

      // Update color display
      self.updateColorDisplay(result.colorInfo)

      // Evaluate frame quality if we have a face bounding box or landmarks
      if let pixelBuffer = self.videoPixelBuffer {
        let imageSize = CGSize(
          width: CVPixelBufferGetWidth(pixelBuffer),
          height: CVPixelBufferGetHeight(pixelBuffer)
        )
        
        let qualityScore: FrameQualityService.QualityScore
        
        // Prefer using landmarks for quality calculation if available
        if let landmarks = result.faceLandmarks, !landmarks.isEmpty {
          print("Using landmarks for quality calculation: \(landmarks.count) points")
          qualityScore = FrameQualityService.evaluateFrameQualityWithLandmarks(
            pixelBuffer: pixelBuffer,
            landmarks: landmarks,
            imageSize: imageSize
          )
        } else if let faceBoundingBox = result.faceBoundingBox {
          // Fall back to bounding box method if landmarks aren't available
          print("Using bounding box for quality calculation")
          qualityScore = FrameQualityService.evaluateFrameQuality(
            pixelBuffer: pixelBuffer,
            faceBoundingBox: faceBoundingBox,
            imageSize: imageSize
          )
        } else {
          print("No face detected for quality calculation")
          qualityScore = FrameQualityService.QualityScore(
            overall: 0.0,
            faceSize: 0.0,
            facePosition: 0.0,
            brightness: 0.0,
            sharpness: 0.0
          )
        }
        
        print("New quality score calculated: \(qualityScore)")
        print("Quality score details - Overall: \(qualityScore.overall), FaceSize: \(qualityScore.faceSize), Position: \(qualityScore.facePosition), Brightness: \(qualityScore.brightness), Sharpness: \(qualityScore.sharpness)")

        // Update current score and UI
        self.currentFrameQualityScore = qualityScore

        // Update frame quality view
        let updatedFrameQualityView = FrameQualityIndicatorView(
          qualityScore: qualityScore,
          showDetailed: false
        )

        // Update the frame quality view using the stored reference
        if let hostingController = self.frameQualityHostingController {
          hostingController.rootView = updatedFrameQualityView
        }

        // Update analyze button state
        self.updateAnalyzeButtonState()

        // Check if we need to show error conditions
        self.checkForErrorConditions()

        // Update debug overlay
        self.updateDebugOverlay(
          fps: result.inferenceTime != nil ? 1000.0 / Float(result.inferenceTime!) : 0.0,
          colorInfo: result.colorInfo,
          qualityScore: qualityScore
        )
      }
    }

    inferenceResultDeliveryDelegate?.didPerformInference(result: nil)
  }

  func segmentationService(_ service: SegmentationService, didFailWithError error: Error) {
    print("Segmentation error: \(error)")
  }
}

// MARK: - ClassificationServiceDelegate
extension CameraViewController: ClassificationServiceDelegate {
  func classificationService(_ service: ClassificationService, didCompleteAnalysis result: AnalysisResult) {
    DispatchQueue.main.async {
      // Remove any loading indicators
      for subview in self.view.subviews {
        if let indicator = subview as? UIActivityIndicatorView {
          indicator.removeFromSuperview()
        }
      }

      // Present analysis result view
      self.presentAnalysisResultView(result: result)
    }
  }

  func classificationService(_ service: ClassificationService, didFailWithError error: Error) {
    DispatchQueue.main.async {
      // Remove any loading indicators
      for subview in self.view.subviews {
        if let indicator = subview as? UIActivityIndicatorView {
          indicator.removeFromSuperview()
        }
      }

      // Show error alert
      let alert = UIAlertController(
        title: "Analysis Failed",
        message: "Could not extract color information. Please try again with better lighting.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      self.present(alert, animated: true)
    }
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
