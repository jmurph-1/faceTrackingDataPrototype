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
    
    // Enable logging first thing
    enableConsoleLogging()
    
    print("=== CameraViewController: viewDidLoad started ===")
    
    cameraService.delegate = self
    segmentationService.delegate = self
    classificationService.delegate = self
    setupColorLabels()
    setupFrameQualityUI()
    setupDebugOverlay()
    setupGestures()

    toastService = ToastService(containerView: view)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
    
    print("=== CameraViewController: viewDidLoad completed ===")
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

  @objc private func analyzeButtonTapped() {
    if !isFrameQualitySufficientForAnalysis {
      let alert = UIAlertController(
        title: "Insufficient Frame Quality",
        message: "Please adjust your position to improve frame quality before analyzing.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
      present(alert, animated: true)
      return
    }

    guard let pixelBuffer = videoPixelBuffer else { return }
    
    let colorInfo = segmentationService.getCurrentColorInfo()
    
    classificationService.analyzeFrame(pixelBuffer: pixelBuffer, colorInfo: colorInfo)
  }

  private func presentAnalysisResultView(with result: AnalysisResult) {
    let viewModel = AnalysisResultViewModel()
    viewModel.updateWithResult(result)
    
    let resultView = UIHostingController(
      rootView: AnalysisResultView(
        viewModel: viewModel,
        onDismiss: { [weak self] in
          self?.dismiss(animated: true)
        },
        onRetry: { [weak self] in
          self?.dismiss(animated: true)
          self?.analyzeButtonTapped()
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
    print("Setting up debug overlay")
    // Start with default values
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
        hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        hostingController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        hostingController.view.widthAnchor.constraint(equalToConstant: 300),
        hostingController.view.heightAnchor.constraint(equalToConstant: 400)
      ])
      
      // Explicitly make sure the debug overlay is visible
      isDebugOverlayVisible = true
      hostingController.view.isHidden = false
      print("Debug overlay setup complete. Visibility state: \(isDebugOverlayVisible)")
    } else {
      print("ERROR: Failed to create debug overlay hosting controller")
    }
  }

  private func setupGestures() {
    let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleThreeTap))
    tripleTapGesture.numberOfTapsRequired = 3
    view.addGestureRecognizer(tripleTapGesture)
    
    // Add single tap for debug logging
    let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
    singleTapGesture.numberOfTapsRequired = 1
    singleTapGesture.require(toFail: tripleTapGesture)
    view.addGestureRecognizer(singleTapGesture)
  }

  @objc private func handleThreeTap() {
    isDebugOverlayVisible.toggle()
    debugOverlayHostingController?.view.isHidden = !isDebugOverlayVisible
  }

  @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
    // Output test logs to debug console logging issues
    NSLog("*** TEST LOG: Single tap detected ***")
    print("*** TEST LOG: This is a print statement ***")
    
    if let qualityScore = currentFrameQualityScore {
      NSLog("*** TEST LOG: Current quality score - Overall: %.2f, FaceSize: %.2f, Position: %.2f, Brightness: %.2f, Sharpness: %.2f ***",
            qualityScore.overall, qualityScore.faceSize, qualityScore.facePosition,
            qualityScore.brightness, qualityScore.sharpness)
    } else {
      NSLog("*** TEST LOG: No quality score available ***")
    }
    
    // Check debug overlay state
    NSLog("*** TEST LOG: Debug overlay visible: %@, hostingController exists: %@ ***",
          String(describing: isDebugOverlayVisible),
          String(describing: debugOverlayHostingController != nil))
  }

  private func updateDebugOverlay(
    fps: Double? = nil,
    skinColorLab: ColorConverters.LabColor? = nil,
    hairColorLab: ColorConverters.LabColor? = nil,
    deltaEs: [SeasonClassifier.Season: CGFloat]? = nil,
    qualityScore: FrameQualityService.QualityScore? = nil
  ) {
    NSLog("*** DEBUG: updateDebugOverlay ENTRY - isVisible: %@, hostingController: %@ ***",
          String(describing: isDebugOverlayVisible),
          String(describing: debugOverlayHostingController != nil))
    
    guard isDebugOverlayVisible, let debugOverlayHostingController = debugOverlayHostingController else {
      NSLog("*** DEBUG: updateDebugOverlay EARLY EXIT - guard condition failed ***")
      return
    }
    
    let currentView = debugOverlayHostingController.rootView
    let updatedFps = Float(fps ?? 0.0)
    let updatedSkinLab = skinColorLab ?? currentView.skinColorLab
    let updatedHairLab = hairColorLab ?? currentView.hairColorLab
    let updatedDeltaEs = deltaEs ?? currentView.deltaEToSeasons
    let updatedQualityScore = qualityScore ?? currentView.qualityScore
    
    NSLog("*** DEBUG: Creating updated overlay view - skinLab: %@, hairLab: %@, quality: %@ ***",
          String(describing: updatedSkinLab),
          String(describing: updatedHairLab),
          String(describing: updatedQualityScore))
    
    let updatedOverlayView = DebugOverlayView(
      fps: updatedFps,
      skinColorLab: updatedSkinLab,
      hairColorLab: updatedHairLab,
      deltaEToSeasons: updatedDeltaEs,
      qualityScore: updatedQualityScore
    )
    
    NSLog("*** DEBUG: Created updated overlay view, updating rootView ***")
    
    debugOverlayHostingController.rootView = updatedOverlayView
    
    NSLog("*** DEBUG: updateDebugOverlay COMPLETED ***")
  }

  private func setupErrorToast() {
    toastService = ToastService(containerView: view)
  }

  private func showErrorToast(message: String, type: ToastType = .error) {
    toastService.showToast(message, type: type)
  }

  private func checkForErrorConditions() {
    // Since segmentationService is not optional, we don't need to check if it exists
    // Just proceed with the quality checks
    
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

  // Add this method after viewDidLoad to enable proper logging
  private func enableConsoleLogging() {
    // Force console output to be shown
    setenv("OS_ACTIVITY_MODE", "disable", 1)
    // Print a test message to verify logging is working
    NSLog("*** DEBUG: Console logging initialized ***")
    print("*** DEBUG: Standard print logging initialized ***")
  }
}

extension CameraViewController: CameraServiceDelegate {

  func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    self.videoPixelBuffer = pixelBuffer
    
    let deviceOrientation = UIDevice.current.orientation
    let imageOrientation = orientation // Use the provided orientation
    
    let currentTimeMs = Date().timeIntervalSince1970 * 1000
    
    let shouldProcess = currentTimeMs - lastClassificationTime > classificationThrottleInterval * 1000
    
    if shouldProcess {
      lastClassificationTime = currentTimeMs
      
      if self.faceLandmarkerService == nil {
        self.clearAndInitializeFaceLandmarkerService()
      }
      
      self.faceLandmarkerService?.detectLandmarksAsync(
        sampleBuffer: sampleBuffer,
        orientation: imageOrientation,
        timeStamps: Int(currentTimeMs))
      
      self.segmentationService.processFrame(
        sampleBuffer: sampleBuffer,
        orientation: imageOrientation,
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
    NSLog("*** DEBUG: segmentationService didCompleteSegmentation called ***")
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      NSLog("*** DEBUG: On main thread, processing segmentation result ***")
      
      self.previewView.pixelBuffer = result.outputPixelBuffer
      
      self.updateColorDisplay(result.colorInfo)
      
      // Convert the extracted colors to LAB and update the debug overlay
      let skinLabColor = result.colorInfo.skinColor.labColor
      let hairLabColor = result.colorInfo.hairColor.labColor
      
      // Calculate deltaE to seasons if appropriate
      let deltaEs = SeasonClassifier.calculateDeltaEToAllSeasons(skinLab: skinLabColor)
      
      NSLog("*** DEBUG: Color data prepared: skin=%@, hair=%@, deltaE count=%d ***", 
            String(describing: skinLabColor), 
            String(describing: hairLabColor),
            deltaEs.count)
      
      let imageSize = CGSize(
        width: CVPixelBufferGetWidth(result.outputPixelBuffer),
        height: CVPixelBufferGetHeight(result.outputPixelBuffer)
      )
      
      let pixelBuffer = result.outputPixelBuffer
      let qualityScore: FrameQualityService.QualityScore
      
      if let landmarks = result.faceLandmarks, !landmarks.isEmpty {
        // Use landmarks for quality calculation
        NSLog("*** DEBUG: Using %d landmarks for quality calculation ***", landmarks.count)
        qualityScore = FrameQualityService.evaluateFrameQualityWithLandmarks(
          pixelBuffer: pixelBuffer,
          landmarks: landmarks,
          imageSize: imageSize
        )
      } else {
        // Use bounding box as fallback
        NSLog("*** DEBUG: Using bounding box for quality calculation ***")
        // Ensure we have a valid bounding box
        let faceBoundingBox = result.faceBoundingBox ?? CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6)
        
        qualityScore = FrameQualityService.evaluateFrameQuality(
          pixelBuffer: pixelBuffer,
          faceBoundingBox: faceBoundingBox,
          imageSize: imageSize
        )
      }
      
      // Check if brightness and sharpness values are valid
      NSLog("*** DEBUG: Quality details - Overall: %.2f, FaceSize: %.2f, Position: %.2f, Brightness: %.2f, Sharpness: %.2f ***",
            qualityScore.overall, qualityScore.faceSize, qualityScore.facePosition,
            qualityScore.brightness, qualityScore.sharpness)
      
      // If brightness or sharpness is zero, calculate them separately
      var updatedQualityScore = qualityScore
      if qualityScore.brightness <= 0.001 || qualityScore.sharpness <= 0.001 {
        // Calculate brightness directly from the whole frame as a fallback
        let brightnessScore = self.calculateFallbackBrightness(pixelBuffer: pixelBuffer)
        let sharpnessScore = max(0.5, qualityScore.sharpness) // Use a reasonable default if zero
        
        NSLog("*** DEBUG: Using fallback brightness: %.2f, sharpness: %.2f ***", 
              brightnessScore, sharpnessScore)
        
        // Create a new quality score with the updated values
        updatedQualityScore = FrameQualityService.QualityScore(
          overall: qualityScore.overall,
          faceSize: qualityScore.faceSize, 
          facePosition: qualityScore.facePosition,
          brightness: brightnessScore > 0 ? brightnessScore : 0.7, // Default to 0.7 if still zero
          sharpness: sharpnessScore > 0 ? sharpnessScore : 0.6     // Default to 0.6 if still zero
        )
      }
      
      self.currentFrameQualityScore = updatedQualityScore
      
      // Update the frame quality indicator view
      let updatedFrameQualityView = FrameQualityIndicatorView(qualityScore: updatedQualityScore)
      self.frameQualityHostingController?.rootView = updatedFrameQualityView
      
      // Update the debug overlay with all information
      NSLog("*** DEBUG: Calling updateDebugOverlay with quality score: %@, isVisible: %@, hostingController: %@ ***",
            String(describing: updatedQualityScore),
            String(describing: self.isDebugOverlayVisible),
            String(describing: self.debugOverlayHostingController != nil))
      
      self.updateDebugOverlay(
        fps: 30.0, // Use a fixed value or calculate actual FPS
        skinColorLab: skinLabColor,
        hairColorLab: hairLabColor,
        deltaEs: deltaEs,
        qualityScore: updatedQualityScore
      )
      
      self.updateAnalyzeButtonState()
    }
  }
  
  // Fallback method to calculate brightness from the entire frame
  private func calculateFallbackBrightness(pixelBuffer: CVPixelBuffer) -> Float {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext(options: nil)
    
    // Create a smaller version for efficiency
    let scale = 0.1
    let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    
    // Use CIAreaAverage for efficient brightness calculation
    let filter = CIFilter(name: "CIAreaAverage")!
    filter.setValue(scaledImage, forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgRect: scaledImage.extent), forKey: "inputExtent")
    
    guard let outputImage = filter.outputImage,
          let outputBuffer = context.createCGImage(outputImage, from: outputImage.extent) else {
      return 0.7 // Default if calculation fails
    }
    
    // Get color from the average
    let dataProvider = outputBuffer.dataProvider
    let data = dataProvider?.data
    let buffer = CFDataGetBytePtr(data)
    
    // Calculate brightness from RGB
    let r = Float(buffer?[0] ?? 0) / 255.0
    let g = Float(buffer?[1] ?? 0) / 255.0
    let b = Float(buffer?[2] ?? 0) / 255.0
    
    let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
    
    // Map to a 0-1 score where 0.5-0.7 is ideal
    if brightness < 0.2 {
      return brightness / 0.2
    } else if brightness > 0.8 {
      return Float(1.0 - ((brightness - 0.8) / 0.2))
    } else if brightness < 0.4 {
      return Float(0.7 + ((brightness - 0.2) / (0.4 - 0.2)) * 0.3)
    } else if brightness > 0.7 {
      return Float(0.7 + ((0.8 - brightness) / (0.8 - 0.7)) * 0.3)
    } else {
      return 1.0
    }
  }

  func segmentationService(_ segmentationService: SegmentationService, didFailWithError error: Error) {
    print("Segmentation service error: \(error)")
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
        print("Face landmark error: \(error)")
      }

      if let pixelBuffer = self.videoPixelBuffer {
        #if DEBUG
        self.debugPixelBuffer(pixelBuffer, label: "Video pixel buffer for preview")
        #endif

        self.previewView.pixelBuffer = pixelBuffer

        #if DEBUG
        print("Preview view updated with pixel buffer")
        #endif

        self.landmarksOverlayView?.isHidden = false
        
        if let faceLandmarkerResults = result?.faceLandmarkerResults,
           let firstResult = faceLandmarkerResults.first,
           let faceLandmarkerResult = firstResult,
           !faceLandmarkerResult.faceLandmarks.isEmpty,
           let landmarks = faceLandmarkerResult.faceLandmarks.first {

          #if DEBUG
          print("Received \(landmarks.count) landmarks")
          #endif

          self.lastFaceLandmarks = landmarks
          
          self.segmentationService.updateFaceLandmarks(landmarks)
          print("Updated face landmarks for quality calculation: \(landmarks.count) points")

          if self.landmarksOverlayView == nil {
            self.setupLandmarksOverlayView()
          }

          self.updateLandmarksOverlay(with: landmarks)
        } else {
          self.lastFaceLandmarks = nil

          #if DEBUG
          print("No face landmarks detected")
          #endif

          self.clearLandmarksOverlay()
        }
      } else {
        #if DEBUG
        print("ERROR: No video pixel buffer available for preview")
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
