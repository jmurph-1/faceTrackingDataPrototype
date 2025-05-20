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
 * The refactored camera view controller is responsible for displaying the camera feed and UI,
 * delegating business logic to the CameraViewModel.
 */
class RefactoredCameraViewController: UIViewController {
    // MARK: - Outlets
    @IBOutlet weak var previewView: PreviewMetalView!
    @IBOutlet weak var cameraUnavailableLabel: UILabel!
    @IBOutlet weak var resumeButton: UIButton!

    // MARK: - UI Elements
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
    private var frameQualityHostingController: UIHostingController<FrameQualityIndicatorView>?
    private let analyzeButton = UIButton(type: .system)

    // UI overlay for displaying landmarks
    private var landmarksOverlayView: UIView?
    private var landmarkDots: [UIView] = []

    // Debug overlay
    private var debugOverlayHostingController: UIHostingController<DebugOverlayView>?
    private var isDebugOverlayVisible = false

    // MARK: - Properties
    private let viewModel = CameraViewModel()
    private let analysisViewModel = AnalysisResultViewModel()
    private var toastService: ToastService!
    var shouldAutoStartAnalysis = false // Default is false
    private var isAnalyzeButtonPressed = false

    // Delegate to report inference results
    weak var inferenceResultDeliveryDelegate: InferenceResultDeliveryDelegate?

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup UI
        setupColorLabels()
        setupFrameQualityUI()
        setupDebugOverlay()
        setupGestures()

        // Initialize toast service
        toastService = ToastService(containerView: view)

        // Configure view model
        viewModel.delegate = self
        print("RVC: viewDidLoad - self.shouldAutoStartAnalysis is: \(self.shouldAutoStartAnalysis)")

        // Register for app lifecycle notifications
        registerForAppLifecycleNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("RVC: viewWillAppear - self.shouldAutoStartAnalysis is \(self.shouldAutoStartAnalysis)")
        // The camera will be started by RootViewController's call to
        // self.prepareAndStartCameraIfNeeded() after the transition,
        // or by other explicit actions like resuming from interruption.
    }

    func prepareAndStartCameraIfNeeded() {
        print("RVC: prepareAndStartCameraIfNeeded called. shouldAutoStartAnalysis = \(self.shouldAutoStartAnalysis)")
        if self.shouldAutoStartAnalysis {
            print("RVC: prepareAndStartCameraIfNeeded - Calling viewModel.startCamera()")
            viewModel.startCamera()
        }
    }

    func stopCameraProcessing() {
        print("RVC: stopCameraProcessing called.")
        viewModel.stopCamera()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop camera when view disappears
        viewModel.stopCamera()
    }

    deinit {
        // Remove all notification observers
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Actions

    // Resume camera session when click button resume
    @IBAction func onClickResume(_ sender: Any) {
        viewModel.resumeCamera()
    }

    @objc private func handleThreeTap() {
        // Toggle debug overlay visibility
        isDebugOverlayVisible.toggle()
        debugOverlayHostingController?.view.isHidden = !isDebugOverlayVisible
        print("RVC: handleThreeTap - isDebugOverlayVisible: \(isDebugOverlayVisible), debugOverlay.isHidden: \(debugOverlayHostingController?.view.isHidden ?? true)")
    }

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
                // Also remove loading indicator if it was added
                for subview in self.view.subviews {
                    if let indicator = subview as? UIActivityIndicatorView {
                        indicator.removeFromSuperview()
                    }
                }
            }
        }

        guard let currentQuality = viewModel.currentFrameQualityScore, currentQuality.isAcceptableForAnalysis else {
            print("ANALYZE_FLOW: Frame quality insufficient, showing alert")
            let alert = UIAlertController(
                title: "Insufficient Frame Quality",
                message: "Please adjust your position to improve frame quality before analyzing. Current overall score: \(String(format: "%.2f", viewModel.currentFrameQualityScore?.overall ?? 0))",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true)
            resetButtonState()
            return
        }

        // Show loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.center = view.center
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)

        // Analyze current frame using view model
        print("ANALYZE_FLOW: Calling analyzeCurrentFrame on ViewModel")
        viewModel.analyzeCurrentFrame()
        // The ViewModel will post a notification "AnalysisResultReady"
        // and handle removing the loading indicator upon receiving that notification or error.
        // However, we should ensure the button state is reset.
        // The loading indicator removal is handled in `handleAnalysisResultReady` or if an error occurs.
        
        // Reset button state after a short delay to allow processing to start
        // The view model's `analyzeCurrentFrame` is asynchronous in its effect (notification)
        // So, we reset the button state. The loading indicator is handled by `handleAnalysisResultReady`
        // or by the error handler in the view model delegate.
        // For now, let's keep it simple and reset button state.
        // We'll rely on handleAnalysisResultReady to remove the spinner.
        // The `resetButtonState` call already handles removing the spinner if it's still there.
        // No, the viewModel.analyzeCurrentFrame() is synchronous in its internal call to classificationService.analyzeFrame.
        // The result comes back via delegate. So, we only reset `isAnalyzeButtonPressed`.
        // The spinner removal will be handled by `handleAnalysisResultReady` or error delegate.

        // Reset button state. Spinner removal is handled by other delegate methods.
        DispatchQueue.main.async {
            print("ANALYZE_FLOW: Analysis initiated, resetting button state (isAnalyzeButtonPressed=false)")
            self.isAnalyzeButtonPressed = false
        }
    }

    @objc private func handleAppWillEnterForeground() {
        print("RVC: handleAppWillEnterForeground called. shouldAutoStartAnalysis: \(shouldAutoStartAnalysis)")
        viewModel.stopCamera() // Stop any existing session first

        if shouldAutoStartAnalysis && view.window != nil { // Check if view is part of a window hierarchy
            print("RVC: handleAppWillEnterForeground - Starting camera because shouldAutoStartAnalysis is true and view is in window.")
            viewModel.startCamera()
        } else {
            print("RVC: handleAppWillEnterForeground - Not starting camera. shouldAutoStartAnalysis: \(shouldAutoStartAnalysis), view.window: \(String(describing: view.window))")
        }
    }

    @objc private func handleAnalysisResultReady(_ notification: Notification) {
        // Remove any loading indicators
        for subview in view.subviews {
            if let indicator = subview as? UIActivityIndicatorView {
                indicator.removeFromSuperview()
            }
        }

        // Extract the analysis result from the notification
        if let result = notification.userInfo?["result"] as? AnalysisResult {
            // Present the analysis result view
            presentAnalysisResultView(result: result)
        }
    }

    // MARK: - Alert Methods

    private func presentCameraPermissionsDeniedAlert() {
        let alertController = UIAlertController(
            title: "Camera Permissions Denied",
            message: "Camera permissions have been denied for this app. You can change this by going to Settings",
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

    // MARK: - UI Setup Methods

    // setupColorLabels method moved to extension

    // setupFrameQualityUI method moved to extension

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
            hostingController.view.backgroundColor = .clear // Important for transparency

            // Add to view hierarchy but initially hidden
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.didMove(toParent: self)

            hostingController.view.isUserInteractionEnabled = true

            // Ensure frameQualityHostingController.view is referenced safely if it might not be set up yet
            // However, setupFrameQualityUI is called before setupDebugOverlay in viewDidLoad.
            
            let bottomAnchorConstraint: NSLayoutConstraint
            if let frameQualityView = frameQualityHostingController?.view {
                bottomAnchorConstraint = hostingController.view.bottomAnchor.constraint(lessThanOrEqualTo: frameQualityView.topAnchor, constant: -10)
            } else {
                // Fallback if frameQualityView is not available, go up from safe area bottom
                bottomAnchorConstraint = hostingController.view.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -150) // Adjust constant as needed
            }

            // Define content hugging and compression resistance priorities.
            // We want the hosting view to hug its content vertically.
            hostingController.view.setContentHuggingPriority(.required, for: .vertical)
            hostingController.view.setContentCompressionResistancePriority(.required, for: .vertical)
            // For horizontal, it can expand.
            hostingController.view.setContentHuggingPriority(.defaultLow, for: .horizontal)

            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                hostingController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
                hostingController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10), // This will define its width
                // No explicit bottom anchor that defines height, let intrinsic content size try to dictate it,
                // but it MUST NOT go below the frameQualityView.
                // The 'bottomAnchorConstraint' (lessThanOrEqualTo) acts as an upper limit for its bottom edge.
                // An explicit height constraint might be needed if intrinsic sizing is ambiguous.
                // For now, let's rely on the SwiftUI view's intrinsic size primarily for height.
                // The `lessThanOrEqualTo` constraint for the bottom anchor will prevent it from growing indefinitely downwards.
                bottomAnchorConstraint // This is important to cap its maximum extent
            ])

            // Initially hidden
            hostingController.view.isHidden = true
        }
    }

    private func setupGestures() {
        // Add 3-finger tap gesture for debug overlay
        let threeTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleThreeTap))
        threeTapGesture.numberOfTapsRequired = 3
        view.addGestureRecognizer(threeTapGesture)
    }

    private func registerForAppLifecycleNotifications() {
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Register for analysis result notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnalysisResultReady(_:)),
            name: Notification.Name("AnalysisResultReady"),
            object: nil
        )
    }

    // MARK: - UI Update Methods

    // Landmark overlay visibility will be handled directly or tied to debug overlay.
    /*
    private func updateUIForTrackingMode(isFaceTrackingEnabled: Bool) {
       landmarksOverlayView?.isHidden = true // Always hide
       clearLandmarksOverlay()
    }
    */

    private func updateColorDisplay(_ colorInfo: MultiClassSegmentedImageRenderer.ColorInfo) {
        // Update skin color label
        if let skinRGB = colorInfo.skinColor.cgColor.components, skinRGB.count >= 3 {
            let skinHSV = colorInfo.skinColorHSV
            let skinRGBString = String(format: "Skin: RGB(%.0f,%.0f,%.0f)", skinRGB[0]*255, skinRGB[1]*255, skinRGB[2]*255)
            let skinHSVString = String(format: " HSV(%.0f,%.0f,%.0f)", skinHSV.h*360, skinHSV.s*100, skinHSV.v*100)
            skinColorLabel.text = skinRGBString + skinHSVString
        }

        // Update hair color label
        if let hairRGB = colorInfo.hairColor.cgColor.components, hairRGB.count >= 3 {
            let hairHSV = colorInfo.hairColorHSV
            let hairRGBString = String(format: "Hair: RGB(%.0f,%.0f,%.0f)", hairRGB[0]*250, hairRGB[1]*250, hairRGB[2]*250)
            let hairHSVString = String(format: " HSV(%.0f,%.0f,%.0f)", hairHSV.h*360, hairHSV.s*100, hairHSV.v*100)
            hairColorLabel.text = hairRGBString + hairHSVString
        }
    }

    private func updateAnalyzeButtonState(isEnabled: Bool) {
        analyzeButton.isEnabled = isEnabled
        analyzeButton.alpha = isEnabled ? 1.0 : 0.5
    }

    private func updateDebugOverlay(fps: Float, colorInfo: MultiClassSegmentedImageRenderer.ColorInfo?, qualityScore: FrameQualityService.QualityScore?) {
        guard isDebugOverlayVisible, let hostingController = debugOverlayHostingController else {
            return
        }

        // Convert color values to Lab if available
        var skinLab: ColorConverters.LabColor?
        var hairLab: ColorConverters.LabColor?
        var deltaEs: [SeasonClassifier.Season: CGFloat]?

        if let colorInfo = colorInfo {
            skinLab = ColorConverters.colorToLab(colorInfo.skinColor)
            hairLab = ColorConverters.colorToLab(colorInfo.hairColor)
            if let skinColorLab = skinLab {
                deltaEs = SeasonClassifier.calculateDeltaEToAllSeasons(skinLab: skinColorLab)
            }
        }

        // Create updated overlay view
        let updatedOverlayView = DebugOverlayView(
            fps: viewModel.currentFPS,
            skinColorLab: skinLab,
            hairColorLab: hairLab,
            deltaEToSeasons: deltaEs,
            qualityScore: qualityScore
        )

        hostingController.rootView = updatedOverlayView
    }

    // MARK: - Landmarks Methods

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
    }

    // MARK: - Result Presentation

    private func presentAnalysisResultView(result: AnalysisResult) {
        // Stop all camera processing before showing results
        viewModel.stopCamera()
        previewView.pixelBuffer = nil
        previewView.flushTextureCache()
        
        // Clear any overlays
        clearLandmarksOverlay()
        landmarksOverlayView?.isHidden = true
        
        // Update analysis view model with the result
        analysisViewModel.updateWithResult(result)

        // Create hosting controller for SwiftUI view
        let resultView = AnalysisResultView(
            viewModel: analysisViewModel,
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
                // On dismiss, check if we should restart camera
                if self?.shouldAutoStartAnalysis == true {
                    self?.viewModel.startCamera()
                }
            },
            onRetry: { [weak self] in
                self?.dismiss(animated: true)
                // On retry, restart camera
                self?.viewModel.startCamera()
            },
            onSeeDetails: { [weak self] in
                // Stub for future expansion
                self?.dismiss(animated: true)
                // Don't restart camera here since we're just seeing details
            }
        )

        let hostingController = UIHostingController(rootView: resultView)
        hostingController.modalPresentationStyle = .pageSheet

        present(hostingController, animated: true)
    }
}

// MARK: - UISetup Extension
private extension RefactoredCameraViewController {
    func setupColorLabels() {
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

    func setupFrameQualityUI() {
        // Configure frame quality view
        self.frameQualityHostingController = UIHostingController(rootView: frameQualityView)
        guard let frameQualityHostingController = self.frameQualityHostingController else { return }

        frameQualityHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        frameQualityHostingController.view.backgroundColor = .clear

        addChild(frameQualityHostingController)
        view.addSubview(frameQualityHostingController.view)
        frameQualityHostingController.didMove(toParent: self)

        // Position it at the bottom center above the analyze button
        NSLayoutConstraint.activate([
            frameQualityHostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameQualityHostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            frameQualityHostingController.view.widthAnchor.constraint(equalToConstant: 300)
        ])

        // Configure analyze button
        analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        analyzeButton.setTitle("Analyze", for: .normal)
        analyzeButton.backgroundColor = UIColor.systemBlue
        analyzeButton.setTitleColor(.white, for: .normal)
        analyzeButton.layer.cornerRadius = 22
        analyzeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        analyzeButton.addTarget(self, action: #selector(analyzeButtonTapped), for: .touchUpInside)

        // Initially disable the analyze button
        analyzeButton.isEnabled = false
        analyzeButton.alpha = 0.5

        view.addSubview(analyzeButton)

        NSLayoutConstraint.activate([
            analyzeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            analyzeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            analyzeButton.widthAnchor.constraint(equalToConstant: 200),
            analyzeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}

// MARK: - CameraViewModelDelegate
extension RefactoredCameraViewController: CameraViewModelDelegate {
    func viewModel(_ viewModel: CameraViewModel, didUpdateFrameQuality quality: FrameQualityService.QualityScore) {
        // Update frame quality view
        let updatedFrameQualityView = FrameQualityIndicatorView(
            qualityScore: quality,
            showDetailed: false
        )

        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Update the hosting controller's root view directly
            self.frameQualityHostingController?.rootView = updatedFrameQualityView

            // Update analyze button state
            self.updateAnalyzeButtonState(isEnabled: quality.isAcceptableForAnalysis)

            // Update debug overlay
            if self.isDebugOverlayVisible {
                self.updateDebugOverlay(
                    fps: viewModel.currentFPS,
                    colorInfo: viewModel.currentColorInfo,
                    qualityScore: quality
                )
            }
        }
    }

    func viewModel(_ viewModel: CameraViewModel, didUpdateSegmentedBuffer buffer: CVPixelBuffer) {
        print("RVC: CameraViewModel didUpdateSegmentedBuffer. Assigning to previewView.")
        // Update preview with segmented buffer
        DispatchQueue.main.async { [weak self] in
            self?.previewView.pixelBuffer = buffer
        }
    }

    func viewModel(_ viewModel: CameraViewModel, didUpdateColorInfo colorInfo: MultiClassSegmentedImageRenderer.ColorInfo) {
        // Update color display
        DispatchQueue.main.async { [weak self] in
            self?.updateColorDisplay(colorInfo)
        }
    }

    func viewModel(_ viewModel: CameraViewModel, didUpdateFaceLandmarks landmarks: [NormalizedLandmark]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Ensure the overlay view is set up if it's the first time.
            if self.landmarksOverlayView == nil {
                self.setupLandmarksOverlayView()
            }
            // Make sure the overlay is visible.
            // We can decide later if this should be tied to the debug overlay's visibility.
            // For now, let's make it always visible if landmarks are processed.
            self.landmarksOverlayView?.isHidden = false

            if let landmarks = landmarks, !landmarks.isEmpty {
                self.updateLandmarksOverlay(with: landmarks)
            } else {
                self.clearLandmarksOverlay()
            }
        }
    }

    func viewModel(_ viewModel: CameraViewModel, didEncounterError error: Error) {
        // Handle errors
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Remove any loading indicators
            for subview in self.view.subviews {
                if let indicator = subview as? UIActivityIndicatorView {
                    indicator.removeFromSuperview()
                }
            }

            // Handle specific error types
            if let cameraError = error as? CameraError {
                switch cameraError {
                case .configurationFailed:
                    self.presentVideoConfigurationErrorAlert()
                case .permissionDenied:
                    self.presentCameraPermissionsDeniedAlert()
                case .runtimeError:
                    self.toastService.showToast("Camera error. Please restart the app.", type: .error)
                }
            } else if let analysisError = error as? AnalysisError {
                switch analysisError {
                case .insufficientQuality:
                    self.toastService.showToast("Unable to analyze. Please improve lighting and position.", type: .warning)
                }
            } else {
                // Generic error
                self.toastService.showToast("An error occurred: \(error.localizedDescription)", type: .error)
            }
        }
    }

    func viewModel(_ viewModel: CameraViewModel, didDisplayWarning message: String) {
        // Show warning toast
        DispatchQueue.main.async { [weak self] in
            self?.toastService.showToast(message, type: .warning)
        }
    }

    func viewModelDidStartCamera(_ viewModel: CameraViewModel) {
        // Camera started successfully
        DispatchQueue.main.async { [weak self] in
            self?.resumeButton.isHidden = true
            self?.cameraUnavailableLabel.isHidden = true
        }
    }

    func viewModelDidStopCamera(_ viewModel: CameraViewModel) {
        // Camera stopped
    }

    func viewModelDidDetectSessionInterruption(_ viewModel: CameraViewModel, canResume: Bool) {
        // Session was interrupted
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if canResume {
                self.resumeButton.isHidden = false
            } else {
                self.cameraUnavailableLabel.isHidden = false
            }
        }
    }

    func viewModelDidResumeSession(_ viewModel: CameraViewModel) {
        // Session resumed
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.resumeButton.isHidden = true
            self.cameraUnavailableLabel.isHidden = true
        }
    }
}
