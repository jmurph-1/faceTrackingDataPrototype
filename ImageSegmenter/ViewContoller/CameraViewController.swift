//
//
//

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
class CameraViewController: UIViewController {
  private struct Constants {
    static let edgeOffset: CGFloat = 2.0
  }

  weak var inferenceResultDeliveryDelegate: InferenceResultDeliveryDelegate?

  @IBOutlet weak var previewView: PreviewMetalView!
  @IBOutlet weak var cameraUnavailableLabel: UILabel!
  @IBOutlet weak var resumeButton: UIButton!

  private let skinColorLabel = UILabel()
  private let hairColorLabel = UILabel()

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

  private var shouldShowLandmarks = false

  private var videoPixelBuffer: CVImageBuffer!
  private var formatDescription: CMFormatDescription!
  private var isSessionRunning = false
  private var isObserving = false
  private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.cameraController.backgroundQueue")

  private var landmarksOverlayView: UIView?
  private var landmarkDots: [UIView] = []

  private var debugOverlayHostingController: UIHostingController<DebugOverlayView>?
  private var isDebugOverlayVisible = true {
    didSet {
      print("isDebugOverlayVisible changed to: \(isDebugOverlayVisible)")
    }
  }

  private var lastClassificationTime: TimeInterval = 0
  private let classificationThrottleInterval: TimeInterval = 0.1  // 10Hz throttle (10 frames per second)

  private lazy var cameraService = CameraService()
  private let segmentationService = SegmentationService()
  private let classificationService = ClassificationService()
  private var toastService: ToastService!
  private let faceLandmarkRenderer = FaceLandmarkRenderer()

  private let imageSegmenterServiceQueue = DispatchQueue(
    label: "com.google.mediapipe.cameraController.imageSegmenterServiceQueue",
    attributes: .concurrent)

  private let faceLandmarkerServiceQueue = DispatchQueue(
    label: "com.google.mediapipe.cameraController.faceLandmarkerServiceQueue",
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

  private var lastFaceLandmarkerResult: FaceLandmarkerResult?
  private var lastFaceLandmarks: [NormalizedLandmark]?

  private var isAnalyzeButtonPressed = false

  // Add a flag to control logging
  private var shouldLogFrameQuality = false

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
    pauseAllProcessing()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    cameraService.delegate = self
    segmentationService.delegate = self
    classificationService.delegate = self
    setupUIComponents()

    toastService = ToastService(containerView: view)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  @objc private func handleAppWillEnterForeground() {
    clearImageSegmenterServiceOnSessionInterruption()
    clearFaceLandmarkerServiceOnSessionInterruption()
    
    initializeImageSegmenterServiceOnSessionResumption()
    
    initializeFaceLandmarkerServiceOnSessionResumption()
    
    print("Reinitialized both segmentation and face landmark detection after returning to foreground")

    previewView.pixelBuffer = nil
    previewView.flushTextureCache()
  }

  private func setupUIComponents() {
    setupColorLabels()
    setupFrameQualityUI()
    setupDebugOverlay()
    setupGestures()
  }

  private func setupColorLabels() {
    skinColorLabel.translatesAutoresizingMaskIntoConstraints = false
    skinColorLabel.textColor = .white
    skinColorLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    skinColorLabel.textAlignment = .center
    skinColorLabel.layer.cornerRadius = 5
    skinColorLabel.clipsToBounds = true
    skinColorLabel.font = UIFont.systemFont(ofSize: 12)
    skinColorLabel.text = "Skin: N/A"

    hairColorLabel.translatesAutoresizingMaskIntoConstraints = false
    hairColorLabel.textColor = .white
    hairColorLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    hairColorLabel.textAlignment = .center
    hairColorLabel.layer.cornerRadius = 5
    hairColorLabel.clipsToBounds = true
    hairColorLabel.font = UIFont.systemFont(ofSize: 12)
    hairColorLabel.text = "Hair: N/A"

    view.addSubview(skinColorLabel)
    view.addSubview(hairColorLabel)

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

    skinColorLabel.isHidden = true
    hairColorLabel.isHidden = true
  }

  private func setupFrameQualityUI() {
    self.frameQualityHostingController = UIHostingController(rootView: frameQualityView)
    self.frameQualityHostingController?.view.translatesAutoresizingMaskIntoConstraints = false
    self.frameQualityHostingController?.view.backgroundColor = .clear

    if let hostingController = self.frameQualityHostingController {
      addChild(hostingController)
      view.addSubview(hostingController.view)
      hostingController.didMove(toParent: self)

      NSLayoutConstraint.activate([
          hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
          hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
          hostingController.view.widthAnchor.constraint(equalToConstant: 300)
      ])
    }

    analyzeButton.translatesAutoresizingMaskIntoConstraints = false
    analyzeButton.setTitle("Analyze", for: .normal)
    analyzeButton.backgroundColor = UIColor.systemBlue
    analyzeButton.setTitleColor(.white, for: .normal)
    analyzeButton.layer.cornerRadius = 22
    analyzeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
    analyzeButton.addTarget(self, action: #selector(analyzeButtonTapped), for: .touchUpInside)

    updateAnalyzeButtonState()

    view.addSubview(analyzeButton)

    NSLayoutConstraint.activate([
        analyzeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        analyzeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        analyzeButton.widthAnchor.constraint(equalToConstant: 200),
        analyzeButton.heightAnchor.constraint(equalToConstant: 44)
    ])
  }

  private func setupGestures() {
    let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleThreeTap))
    tripleTapGesture.numberOfTapsRequired = 3
    view.addGestureRecognizer(tripleTapGesture)
  }

  @objc private func handleThreeTap() {
    isDebugOverlayVisible.toggle()
    debugOverlayHostingController?.view.isHidden = !isDebugOverlayVisible
  }

#endif

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
    segmentationService.configure(with: InferenceConfigurationManager.sharedInstance.model.modelPath!)
    segmentationService.delegate = self
    startObserveConfigChanges()
  }

  private func initializeFaceLandmarkerServiceOnSessionResumption() {
    clearAndInitializeFaceLandmarkerService()
  }

  @objc private func clearAndInitializeImageSegmenterService() {
    segmentationService.clearImageSegmenterService()
      segmentationService.configure(with: InferenceConfigurationManager.sharedInstance.model.modelPath!)

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
    skinColorLabel.isHidden = false
    hairColorLabel.isHidden = false
  }

  private func clearImageSegmenterServiceOnSessionInterruption() {
    segmentationService.clearImageSegmenterService()
    stopObserveConfigChanges()

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
      let skinRGB = colorInfo.skinColor.cgColor.components
    let skinHSV = colorInfo.skinColorHSV

    if let skinRGB = skinRGB, skinRGB.count >= 3 {
      let skinRGBString = String(format: "Skin: RGB(%.0f,%.0f,%.0f)", skinRGB[0]*255, skinRGB[1]*255, skinRGB[2]*255)
      let skinHSVString = String(format: " HSV(%.0f,%.0f,%.0f)", skinHSV.h*360, skinHSV.s*100, skinHSV.v*100)
      skinColorLabel.text = skinRGBString + skinHSVString
    }

      let hairRGB = colorInfo.hairColor.cgColor.components
    let hairHSV = colorInfo.hairColorHSV

    if let hairRGB = hairRGB, hairRGB.count >= 3 {
      let hairRGBString = String(format: "Hair: RGB(%.0f,%.0f,%.0f)", hairRGB[0]*250, hairRGB[1]*250, hairRGB[2]*250)
      let hairHSVString = String(format: " HSV(%.0f,%.0f,%.0f)", hairHSV.h*360, hairHSV.s*100, hairHSV.v*100)
      hairColorLabel.text = hairRGBString + hairHSVString
    }
  }

  private func setupLandmarksOverlayView() {
    let overlayView = UIView(frame: previewView.bounds)
    overlayView.backgroundColor = .clear
    overlayView.isUserInteractionEnabled = false
    overlayView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(overlayView)

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

    for dot in landmarkDots {
      dot.removeFromSuperview()
    }
    landmarkDots.removeAll()

    let strideAmount = 5
    let selectedLandmarks = stride(from: 0, to: min(landmarks.count, 468), by: strideAmount)

    for landmarkIndex in selectedLandmarks {
      guard landmarkIndex < landmarks.count else { continue }
      let landmark = landmarks[landmarkIndex]

      let pointX = CGFloat(landmark.x) * overlayView.bounds.width
      let pointY = CGFloat(landmark.y) * overlayView.bounds.height

      let dotSize: CGFloat = 4.0
      let dotView = UIView(frame: CGRect(x: pointX - dotSize/2, y: pointY - dotSize/2, width: dotSize, height: dotSize))

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
    for dot in landmarkDots {
      dot.removeFromSuperview()
    }
    landmarkDots.removeAll()
    lastFaceLandmarks = nil
  }

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
      kCVPixelFormatType_32ARGB,
      attributes as CFDictionary,
      &pixelBuffer)

    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
      return nil
    }

    CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
    let context = CGContext(
      data: CVPixelBufferGetBaseAddress(buffer),
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

    context?.translateBy(x: 0, y: CGFloat(height))
    context?.scaleBy(x: 1, y: -1)

    UIGraphicsPushContext(context!)
    image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    UIGraphicsPopContext()

    CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))

    return buffer
  }

  private func createTextureFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> MTLTexture? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm,
      width: width,
      height: height,
      mipmapped: false)
    textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

    guard let device = MTLCreateSystemDefaultDevice(),
          let texture = device.makeTexture(descriptor: textureDescriptor) else {
      return nil
    }

    let region = MTLRegionMake2D(0, 0, width, height)
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    texture.replace(region: region, mipmapLevel: 0, withBytes: baseAddress!, bytesPerRow: bytesPerRow)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

    return texture
  }

  private var isFrameQualitySufficientForAnalysis: Bool {
    return currentFrameQualityScore?.overall ?? 0 >= 0.7
  }

  private func presentAnalysisResultView(with result: AnalysisResult) {
    shouldLogFrameQuality = false
    pauseAllProcessing()
    
    let viewModel = AnalysisResultViewModel()
    viewModel.updateWithResult(result)
    
    let resultView = UIHostingController(
      rootView: AnalysisResultView(
        viewModel: viewModel,
        onDismiss: { [weak self] in
          self?.dismiss(animated: true)
          self?.resumeAllProcessing()
          // Reinitialize pixel buffer and services
          self?.previewView.pixelBuffer = nil
          self?.initializeImageSegmenterServiceOnSessionResumption()
          self?.initializeFaceLandmarkerServiceOnSessionResumption()
          self?.updateAnalyzeButtonState()
          print("Dismissed results view, services reinitialized.")
        },
        onRetry: { [weak self] in
          self?.dismiss(animated: true)
          self?.resumeAllProcessing()
          // Reinitialize pixel buffer and services
          self?.previewView.pixelBuffer = nil
          self?.initializeImageSegmenterServiceOnSessionResumption()
          self?.initializeFaceLandmarkerServiceOnSessionResumption()
          self?.updateAnalyzeButtonState()
          print("Retrying analysis, services reinitialized.")
          
          self?.isAnalyzeButtonPressed = false
          print("ANALYZE_FLOW: Retry completed, waiting for user to tap analyze button")
        },
        onSeeDetails: { 
          print("See details tapped")
        }
      )
    )
    
    resultView.modalPresentationStyle = .pageSheet
    
    present(resultView, animated: true)
  }

  private func updateAnalyzeButtonState() {
    analyzeButton.isEnabled = isFrameQualitySufficientForAnalysis
    analyzeButton.alpha = isFrameQualitySufficientForAnalysis ? 1.0 : 0.5
  }

  private func setupDebugOverlay() {
    let debugOverlayView = DebugOverlayView(
      fps: 0,
      skinColorLab: nil,
      hairColorLab: nil,
      deltaEToSeasons: nil,
      qualityScore: nil
    )
    
    debugOverlayHostingController = UIHostingController(rootView: debugOverlayView)
    debugOverlayHostingController?.view.backgroundColor = .clear
    
    if let hostingController = debugOverlayHostingController {
      addChild(hostingController)
      view.addSubview(hostingController.view)
      hostingController.didMove(toParent: self)
      
      hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
        hostingController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        hostingController.view.widthAnchor.constraint(equalToConstant: 300),
        hostingController.view.heightAnchor.constraint(equalToConstant: 400)
      ])
      
      hostingController.view.isHidden = !isDebugOverlayVisible
    }
  }

  private func setupErrorToast() {
    toastService = ToastService(containerView: view)
  }

  private func showErrorToast(message: String, type: ToastType = .error) {
      toastService.showToast(message, type: type)
  }

  private func checkForErrorConditions() {
      // Check if the segmentation service is properly configured
    if imageSegmenterService == nil {
        toastService.showToast("Segmentation service not initialized. Please restart the app.", type: .error)
      return
    }
    
    if let qualityScore = currentFrameQualityScore {
      if qualityScore.overall < 0.3 {
          toastService.showToast("Frame quality is too low. Please adjust your position.", type: .warning)
      }
      
      if qualityScore.faceSize < 0.3 {
          toastService.showToast("Face is too small or too large. Move closer or further from camera.", type: .warning)
      }
      
      if qualityScore.facePosition < 0.3 {
          toastService.showToast("Face is not centered. Please center your face in the frame.", type: .warning)
      }
      
      if qualityScore.brightness < 0.3 {
          toastService.showToast("Lighting is too dark or too bright. Adjust lighting conditions.", type: .warning)
      }
      
      if qualityScore.sharpness < 0.3 {
          toastService.showToast("Image is blurry. Hold the camera steady and ensure good focus.", type: .warning)
      }
    }
    
    let colorInfo = segmentationService.getCurrentColorInfo()
    if colorInfo.skinColor == UIColor.clear || colorInfo.hairColor == UIColor.clear {
        toastService.showToast("Unable to extract colors. Please ensure face is visible.", type: .error)
    }
    
    toastService.clearToast()
  }

  private func clearErrorToast() {
    toastService.clearToast()
  }

  private func updateDebugOverlay(fps: Float, skinColorLab: ColorConverters.LabColor?, hairColorLab: ColorConverters.LabColor?, deltaEs: [SeasonClassifier.Season: CGFloat]?, qualityScore: FrameQualityService.QualityScore?) {
    guard isDebugOverlayVisible, let hostingController = debugOverlayHostingController else {
        return
    }

    // Create updated overlay view
    let updatedOverlayView = DebugOverlayView(
        fps: fps,
        skinColorLab: skinColorLab,
        hairColorLab: hairColorLab,
        deltaEToSeasons: deltaEs,
        qualityScore: qualityScore
    )

    // Update the hosting controller's root view
    hostingController.rootView = updatedOverlayView
  }
}

extension CameraViewController: CameraServiceDelegate {

  func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    self.videoPixelBuffer = pixelBuffer
    
    let deviceOrientation = UIDevice.current.orientation
    
    let currentTimeMs = Date().timeIntervalSince1970 * 1000
    
    let shouldProcess = currentTimeMs - lastClassificationTime > classificationThrottleInterval * 1000
    
    if shouldProcess {
      lastClassificationTime = currentTimeMs
      
      if self.faceLandmarkerService == nil {
        self.clearAndInitializeFaceLandmarkerService()
      }
      
      self.faceLandmarkerService?.detectLandmarksAsync(
        sampleBuffer: sampleBuffer,
        orientation: orientation,
        timeStamps: Int(currentTimeMs))
      
      self.segmentationService.processFrame(
        sampleBuffer: sampleBuffer,
        orientation: orientation,
        timeStamps: Int(currentTimeMs))
    }
  }

  func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
    if resumeManually {
      self.resumeButton.isHidden = false
    } else {
      self.cameraUnavailableLabel.isHidden = false
    }
  }

  func sessionInterruptionEnded() {
    if !self.cameraUnavailableLabel.isHidden {
      self.cameraUnavailableLabel.isHidden = true
    }
    
    if !self.resumeButton.isHidden {
      self.resumeButton.isHidden = true
    }
  }

  func didEncounterSessionRuntimeError() {
    DispatchQueue.main.async {
      self.resumeButton.isHidden = false
    }
  }
}

extension CameraViewController: SegmentationServiceDelegate {
  func segmentationService(
    _ segmentationService: SegmentationService,
    didCompleteSegmentation result: SegmentationResult
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      self.previewView.pixelBuffer = result.outputPixelBuffer
      
      self.updateColorDisplay(result.colorInfo)
      
      let imageSize = CGSize(
        width: CVPixelBufferGetWidth(result.outputPixelBuffer),
        height: CVPixelBufferGetHeight(result.outputPixelBuffer)
      )
      
      let pixelBuffer = result.outputPixelBuffer
      let qualityScore: FrameQualityService.QualityScore
      
      if let landmarks = result.faceLandmarks, !landmarks.isEmpty {
        qualityScore = FrameQualityService.evaluateFrameQualityWithLandmarks(
          pixelBuffer: pixelBuffer,
          landmarks: landmarks,
          imageSize: imageSize
        )
      } else {
        let faceBoundingBox = result.faceBoundingBox ?? CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6)
        
        qualityScore = FrameQualityService.evaluateFrameQuality(
          pixelBuffer: pixelBuffer,
          faceBoundingBox: faceBoundingBox,
          imageSize: imageSize
        )
      }
      
      self.currentFrameQualityScore = qualityScore
      
      let updatedFrameQualityView = FrameQualityIndicatorView(qualityScore: qualityScore)
      self.frameQualityHostingController?.rootView = updatedFrameQualityView
      
      // Convert skin and hair colors to Lab
      let skinLab = ColorConverters.colorToLab(result.colorInfo.skinColor)
      let hairLab = ColorConverters.colorToLab(result.colorInfo.hairColor)
      
      // Calculate delta-E to seasons if skin color is available
      var deltaEs: [SeasonClassifier.Season: CGFloat]?
      if result.colorInfo.skinColor != UIColor.clear {
          deltaEs = SeasonClassifier.calculateDeltaEToAllSeasons(skinLab: skinLab)
      }
      
      // Update debug overlay with all information
      self.updateDebugOverlay(
          fps: 30.0, // Using a default FPS value
          skinColorLab: skinLab,
          hairColorLab: hairLab,
          deltaEs: deltaEs,
          qualityScore: qualityScore
      )
      
      self.updateAnalyzeButtonState()
    }
  }
  
  func segmentationService(_ segmentationService: SegmentationService, didFailWithError error: Error) {
    LoggingService.error("Segmentation service error: \(error)")
  }
}

extension CameraViewController: ClassificationServiceDelegate {
  func classificationService(_ service: ClassificationService, didCompleteAnalysis result: AnalysisResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      self.presentAnalysisResultView(with: result)
    }
  }
  
  func classificationService(_ service: ClassificationService, didFailWithError error: Error) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      let alert = UIAlertController(
        title: "Classification Error",
        message: "An error occurred during color classification: \(error.localizedDescription)",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      self.present(alert, animated: true)
    }
  }
}

extension CameraViewController: FaceLandmarkerServiceLiveStreamDelegate {
  func faceLandmarkerService(
    _ faceLandmarkerService: FaceLandmarkerService,
    didFinishLandmarkDetection result: FaceLandmarkerResultBundle?,
    error: Error?
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      if let error = error {
        LoggingService.error("Face landmark error: \(error)")
      }

      if let pixelBuffer = self.videoPixelBuffer {
        #if DEBUG
        if shouldLogFrameQuality {
            //self.debugPixelBuffer(pixelBuffer, label: "Video pixel buffer for preview")
        }
        #endif

        self.previewView.pixelBuffer = pixelBuffer

        #if DEBUG
        if shouldLogFrameQuality {
            //LoggingService.debug("Preview view updated with pixel buffer")
        }
        #endif

        self.landmarksOverlayView?.isHidden = false
        
        if let faceLandmarkerResults = result?.faceLandmarkerResults,
           let firstResult = faceLandmarkerResults.first,
           let faceLandmarkerResult = firstResult,
           !faceLandmarkerResult.faceLandmarks.isEmpty,
           let landmarks = faceLandmarkerResult.faceLandmarks.first {

          #if DEBUG
          if shouldLogFrameQuality {
              LoggingService.debug("Received \(landmarks.count) landmarks")
          }
          #endif

          self.lastFaceLandmarks = landmarks
          
          self.segmentationService.updateFaceLandmarks(landmarks)
          #if DEBUG
          if shouldLogFrameQuality {
              LoggingService.debug("Updated face landmarks for quality calculation: \(landmarks.count) points")
          }
          #endif

          if self.landmarksOverlayView == nil {
            self.setupLandmarksOverlayView()
          }

          self.updateLandmarksOverlay(with: landmarks)
        } else {
          self.lastFaceLandmarks = nil

          #if DEBUG
          if shouldLogFrameQuality {
              LoggingService.debug("No face landmarks detected")
          }
          #endif

          self.clearLandmarksOverlay()
        }
      } else {
        #if DEBUG
        if shouldLogFrameQuality {
            LoggingService.error("No video pixel buffer available for preview")
        }
        #endif
      }
    }
  }
}

extension AVLayerVideoGravity {
  var contentMode: UIView.ContentMode {
    switch self {
    case .resizeAspect:
      return .scaleAspectFit
    case .resizeAspectFill:
      return .scaleAspectFill
    case .resize:
      return .scaleToFill
    default:
      return .scaleAspectFit
    }
  }
}

// Extension to convert UIDeviceOrientation to UIImage.Orientation
extension UIDeviceOrientation {
  var imageOrientation: UIImage.Orientation {
    switch self {
    case .portrait:
      return .right
    case .portraitUpsideDown:
      return .left
    case .landscapeLeft:
      return .up
    case .landscapeRight:
      return .down
    default:
      return .right // Default to portrait
    }
  }
}

// MARK: - Camera Processing Control

extension CameraViewController {
    private func pauseAllProcessing() {
        cameraService.stopSession()
        clearImageSegmenterServiceOnSessionInterruption()
        clearFaceLandmarkerServiceOnSessionInterruption()
        previewView.pixelBuffer = nil
        previewView.flushTextureCache()
        segmentationService.delegate = nil
        classificationService.delegate = nil
        faceLandmarkerService = nil
        
        // Hide or update UI components that rely on the pixel buffer
        previewView.isHidden = true
    }

    private func resumeAllProcessing() {
        print("ANALYZE_FLOW: Resuming all processing")
        cameraService.startLiveCameraSession { _ in }
        initializeImageSegmenterServiceOnSessionResumption()
        initializeFaceLandmarkerServiceOnSessionResumption()
        
        print("ANALYZE_FLOW: Resetting delegates")
        segmentationService.delegate = self
        classificationService.delegate = self
        
        // Ensure UI components are visible when processing resumes
        previewView.isHidden = false
        print("ANALYZE_FLOW: All processing resumed")
    }
}

// MARK: - Analyze Button Handling

extension CameraViewController {
    @objc private func analyzeButtonTapped() {
        print("ANALYZE_FLOW: analyzeButtonTapped called, isAnalyzeButtonPressed=\(isAnalyzeButtonPressed)")
        
        if isAnalyzeButtonPressed {
            print("ANALYZE_FLOW: Button already pressed, ignoring tap")
            return
        }
        
        print("ANALYZE_FLOW: Setting isAnalyzeButtonPressed=true")
        isAnalyzeButtonPressed = true
        
        // Ensure button state is reset even if we return early
        let resetButtonState = {
            DispatchQueue.main.async {
                print("ANALYZE_FLOW: Resetting isAnalyzeButtonPressed=false")
                self.isAnalyzeButtonPressed = false
            }
        }
        
        if !isFrameQualitySufficientForAnalysis {
            print("ANALYZE_FLOW: Frame quality insufficient, showing alert")
            let alert = UIAlertController(
                title: "Insufficient Frame Quality",
                message: "Please adjust your position to improve frame quality before analyzing.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true)
            resetButtonState()
            return
        }

        guard let pixelBuffer = videoPixelBuffer else {
            print("ANALYZE_FLOW: No video pixel buffer available")
            resetButtonState()
            return
        }
        
        print("ANALYZE_FLOW: Getting color info from segmentation service")
        let colorInfo = segmentationService.getCurrentColorInfo()
        
        print("ANALYZE_FLOW: Calling analyzeFrame on classification service")
        classificationService.analyzeFrame(pixelBuffer: pixelBuffer, colorInfo: colorInfo)
        
        print("ANALYZE_FLOW: Analysis initiated, resetting button state")
        resetButtonState()
    }
}

// MARK: - Camera Session Management

extension CameraViewController {
    private func startCameraSession() {
        cameraService.startLiveCameraSession { [weak self] cameraConfiguration in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch cameraConfiguration {
                case .success:
                    self.initializeImageSegmenterServiceOnSessionResumption()
                    self.initializeFaceLandmarkerServiceOnSessionResumption()
                case .failed:
                    self.showCameraErrorAlert()
                case .permissionDenied:
                    self.presentCameraPermissionsDeniedAlert()
                }
            }
        }
    }

    private func stopCameraSession() {
        cameraService.stopSession()
        clearImageSegmenterServiceOnSessionInterruption()
        clearFaceLandmarkerServiceOnSessionInterruption()
    }

    private func showCameraErrorAlert() {
        let alert = UIAlertController(
            title: "Camera Error",
            message: "Unable to start camera session.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
}
