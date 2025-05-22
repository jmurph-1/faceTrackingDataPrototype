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

import Foundation
import UIKit
import AVFoundation
import CoreVideo
import MediaPipeTasksVision

// MARK: - CameraViewModel Delegate Protocol
protocol CameraViewModelDelegate: AnyObject {
    // UI updates
    func viewModel(_ viewModel: CameraViewModel, didUpdateFrameQuality quality: FrameQualityService.QualityScore)
    func viewModel(_ viewModel: CameraViewModel, didUpdateSegmentedBuffer buffer: CVPixelBuffer)
    func viewModel(_ viewModel: CameraViewModel, didUpdateColorInfo colorInfo: ColorExtractor.ColorInfo)
    func viewModel(_ viewModel: CameraViewModel, didUpdateFaceLandmarks landmarks: [NormalizedLandmark]?)

    // Error handling
    func viewModel(_ viewModel: CameraViewModel, didEncounterError error: Error)
    func viewModel(_ viewModel: CameraViewModel, didDisplayWarning message: String)

    // Session state changes
    func viewModelDidStartCamera(_ viewModel: CameraViewModel)
    func viewModelDidStopCamera(_ viewModel: CameraViewModel)
    func viewModelDidDetectSessionInterruption(_ viewModel: CameraViewModel, canResume: Bool)
    func viewModelDidResumeSession(_ viewModel: CameraViewModel)
}

// MARK: - CameraViewModel
class CameraViewModel: NSObject {
    // MARK: - Properties
    weak var delegate: CameraViewModelDelegate?
    private(set) var isSessionRunning = false
    private(set) var currentFrameQualityScore: FrameQualityService.QualityScore?
    private(set) var currentColorInfo: ColorExtractor.ColorInfo?
    private(set) var lastFaceLandmarks: [NormalizedLandmark]?
    private(set) var currentPixelBuffer: CVPixelBuffer?
    private(set) var currentFaceBoundingBox: CGRect?

    private let cameraService = CameraService()
    private let segmentationService = SegmentationService()
    private let classificationService = ClassificationService()
    private var faceLandmarkerService: FaceLandmarkerService?

    private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.cameraViewModel.backgroundQueue")
    private var lastProcessingTime: TimeInterval = 0
    private var processingThrottleInterval: TimeInterval = 0.1

    private var frameCount: Int = 0
    private var lastFPSUpdateTime: TimeInterval = 0
    private(set) var currentFPS: Float = 0.0

    // MARK: - Initialization
    override init() {
        super.init()
        cameraService.delegate = self
        segmentationService.delegate = self
        classificationService.delegate = self
        LoggingService.info("CVM: init - Configuring services.")
        configureInitialServices()
    }

    private func configureInitialServices() {
        configureSegmentationService()
        configureFaceLandmarkerService()
    }

    // MARK: - Public Methods
    func startCamera() {
        LoggingService.info("CVM: startCamera called. Session running: \(isSessionRunning)")
        configureInitialServices() // Ensure services are ready
        cameraService.startLiveCameraSession { [weak self] configuration in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                LoggingService.info("CVM: startCamera completion - Configuration: \(configuration)")
                switch configuration {
                case .success:
                    strongSelf.isSessionRunning = true
                    strongSelf.delegate?.viewModelDidStartCamera(strongSelf)
                case .failed:
                    strongSelf.delegate?.viewModel(strongSelf, didEncounterError: CameraError.configurationFailed)
                case .permissionDenied:
                    strongSelf.delegate?.viewModel(strongSelf, didEncounterError: CameraError.permissionDenied)
                default: break
                }
            }
        }
    }

    func stopCamera() {
        LoggingService.info("CVM: stopCamera called.")
        cameraService.stopSession()
        isSessionRunning = false
        delegate?.viewModelDidStopCamera(self) // 'self' is fine here
        clearServices()
    }

    func resumeCamera() {
        LoggingService.info("CVM: resumeCamera called.")
        cameraService.resumeInterruptedSession { [weak self] isSessionRunning in
            guard let strongSelf = self else { return }
            if isSessionRunning {
                strongSelf.isSessionRunning = true
                strongSelf.delegate?.viewModelDidResumeSession(strongSelf)
                LoggingService.info("CVM: resumeCamera - Reconfiguring services.")
                strongSelf.configureInitialServices()
            }
        }
    }

    func analyzeCurrentFrame() {
        LoggingService.info("CVM: analyzeCurrentFrame called.")
        guard let pixelBuffer = currentPixelBuffer,
              let colorInfo = currentColorInfo,
              isFrameQualitySufficientForAnalysis else {
            LoggingService.warning("CVM: Insufficient quality/data for analysis.")
            delegate?.viewModel(self, didEncounterError: AnalysisError.insufficientQuality) // 'self' is fine
            return
        }
        classificationService.analyzeFrame(pixelBuffer: pixelBuffer, colorInfo: colorInfo)
    }

    // MARK: - Private Methods
    private func configureSegmentationService() {
        LoggingService.debug("CVM: Configuring SegmentationService.")
        guard let modelPath = InferenceConfigurationManager.sharedInstance.model.modelPath else {
            LoggingService.error("CVM: Segmentation model path is nil.")
            delegate?.viewModel(self, didEncounterError: NSError(domain: "CameraViewModel", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Segmentation model path is nil."])) // 'self' fine
            return
        }
        segmentationService.configure(with: modelPath)
    }

    private func configureFaceLandmarkerService() {
        LoggingService.debug("CVM: Configuring FaceLandmarkerService.")
        if faceLandmarkerService != nil {
            clearFaceLandmarkerService()
        }
        faceLandmarkerService = FaceLandmarkerService.liveStreamFaceLandmarkerService(
            modelPath: Bundle.main.path(forResource: "face_landmarker", ofType: "task"),
            liveStreamDelegate: self, // 'self' is fine (conformance)
            delegate: InferenceConfigurationManager.sharedInstance.delegate
        )
        if faceLandmarkerService == nil {
            LoggingService.error("CVM: FAILED to create FaceLandmarkerService.")
        }
    }

    private func clearFaceLandmarkerService() {
        LoggingService.debug("CVM: Clearing FaceLandmarkerService.")
        faceLandmarkerService = nil
        lastFaceLandmarks = nil
        delegate?.viewModel(self, didUpdateFaceLandmarks: nil) // 'self' is fine
    }

    private func clearServices() {
        LoggingService.debug("CVM: Clearing all services.")
        segmentationService.clearImageSegmenterService()
        clearFaceLandmarkerService()
    }

    private func processFrame(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        currentPixelBuffer = pixelBuffer
        
        let currentTime = Date().timeIntervalSince1970
        guard currentTime - lastProcessingTime >= processingThrottleInterval else { return }
        lastProcessingTime = currentTime

        frameCount += 1
        if currentTime - lastFPSUpdateTime >= 1.0 { // Update FPS every second
            currentFPS = Float(frameCount) / Float(currentTime - lastFPSUpdateTime)
            frameCount = 0
            lastFPSUpdateTime = currentTime
            // Optional: Notify delegate about FPS update if needed elsewhere,
            // but for debug overlay, direct access from RVC to viewModel.currentFPS is fine.
        }

        faceLandmarkerService?.detectLandmarksAsync(sampleBuffer: sampleBuffer, orientation: orientation, timeStamps: Int(currentTime * 1000))
        segmentationService.processFrame(sampleBuffer: sampleBuffer, orientation: orientation, timeStamps: Int(currentTime * 1000))
    }
    
    private var isFrameQualitySufficientForAnalysis: Bool {
        return currentFrameQualityScore?.isAcceptableForAnalysis ?? false
    }

    private func checkForErrorConditions() {
        // The FrameQualityIndicatorView now provides this feedback.

        guard currentFaceBoundingBox != nil else {
            // delegate?.viewModel(self, didDisplayWarning: "No face detected. Please center your face in the frame.")
            return
        }
        if let qualityScore = currentFrameQualityScore {
            if !qualityScore.isAcceptableForAnalysis, let feedback = qualityScore.feedbackMessage {
                // delegate?.viewModel(self, didDisplayWarning: feedback)
                // No return here, as FrameQualityIndicatorView shows its own comprehensive message.
            }
            /*
            if qualityScore.brightness < FrameQualityService.minimumBrightnessScoreForAnalysis {
                // ...
                return
            }
            // ... other checks ...
            */
        }
    }
}

// MARK: - CameraServiceDelegate
extension CameraViewModel: CameraServiceDelegate {
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        backgroundQueue.async { [weak self] in
            self?.processFrame(sampleBuffer: sampleBuffer, orientation: orientation)
        }
    }

    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        LoggingService.warning("CVM: Session interrupted. Can resume manually: \(resumeManually)")
        isSessionRunning = false
        delegate?.viewModelDidDetectSessionInterruption(self, canResume: resumeManually) // 'self' fine
        clearServices()
    }

    func sessionInterruptionEnded() {
        LoggingService.info("CVM: Session interruption ended.")
        isSessionRunning = true 
        delegate?.viewModelDidResumeSession(self) // 'self' fine
        configureInitialServices()
    }

    func didEncounterSessionRuntimeError() {
        LoggingService.error("CVM: Session runtime error.")
        isSessionRunning = false
        delegate?.viewModel(self, didEncounterError: CameraError.runtimeError) // 'self' fine
    }
}

// MARK: - SegmentationServiceDelegate
extension CameraViewModel: SegmentationServiceDelegate {
    func segmentationService(_ service: SegmentationService, didCompleteSegmentation result: SegmentationResult) {
        currentColorInfo = result.colorInfo
        currentFaceBoundingBox = result.faceBoundingBox

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.viewModel(strongSelf, didUpdateSegmentedBuffer: result.outputPixelBuffer)
            strongSelf.delegate?.viewModel(strongSelf, didUpdateColorInfo: result.colorInfo)
            
            if let pBuffer = strongSelf.currentPixelBuffer {
                strongSelf.backgroundQueue.async { // strongSelf is captured
                    let imgSize = CGSize(width: CVPixelBufferGetWidth(pBuffer), height: CVPixelBufferGetHeight(pBuffer))
                    let qScore: FrameQualityService.QualityScore
                    if let landmarks = result.faceLandmarks, !landmarks.isEmpty {
                         qScore = FrameQualityService.evaluateFrameQualityWithLandmarks(pixelBuffer: pBuffer, landmarks: landmarks, imageSize: imgSize)
                    } else {
                        let bbox = result.faceBoundingBox ?? CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.6)
                        qScore = FrameQualityService.evaluateFrameQuality(pixelBuffer: pBuffer, faceBoundingBox: bbox, imageSize: imgSize)
                    }
                    
                    DispatchQueue.main.async { [weak self] in // Re-capture self weakly
                        guard let innerSelf = self else { return }
                        innerSelf.currentFrameQualityScore = qScore
                        innerSelf.delegate?.viewModel(innerSelf, didUpdateFrameQuality: qScore)
                        innerSelf.checkForErrorConditions()
                    }
                }
            }
        }
    }

    func segmentationService(_ service: SegmentationService, didFailWithError error: Error) {
        LoggingService.error("CVM: Segmentation error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in // Ensure delegate call is on main thread
            guard let strongSelf = self else { return }
            strongSelf.delegate?.viewModel(strongSelf, didEncounterError: error)
        }
    }
}

// MARK: - ClassificationServiceDelegate
extension CameraViewModel: ClassificationServiceDelegate {
  func classificationService(_ service: ClassificationService, didCompleteAnalysis analysisResult: AnalysisResult) {
    LoggingService.info("CVM: Classification complete.")
    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else { return }
      NotificationCenter.default.post(name: Notification.Name("AnalysisResultReady"), object: strongSelf, userInfo: ["result": analysisResult])
    }
  }

  func classificationService(_ service: ClassificationService, didFailWithError error: Error) {
    LoggingService.error("CVM: Classification error: \(error.localizedDescription)")
    DispatchQueue.main.async { [weak self] in // Ensure delegate call is on main thread
        guard let strongSelf = self else { return }
        strongSelf.delegate?.viewModel(strongSelf, didEncounterError: error)
    }
  }
}

// MARK: - FaceLandmarkerServiceLiveStreamDelegate
extension CameraViewModel: FaceLandmarkerServiceLiveStreamDelegate {
    func faceLandmarkerService(_ service: FaceLandmarkerService, didFinishLandmarkDetection result: FaceLandmarkerResultBundle?, error: Error?) {
        if let e = error {
            LoggingService.error("CVM: Landmark detection error: \(e.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.viewModel(strongSelf, didEncounterError: e)
            }
            return
        }

        guard let faceLandmarkerResults = result?.faceLandmarkerResults, // Ensure results array exists
              let firstFaceLandmarkerResult = faceLandmarkerResults.first, // Get the first result (optional)
              let actualLandmarkResult = firstFaceLandmarkerResult, // Ensure it's not nil (already covered by previous 'first', but good for clarity if needed)
              !actualLandmarkResult.faceLandmarks.isEmpty, // Ensure landmarks array is not empty
              let landmarksData = actualLandmarkResult.faceLandmarks.first // Get the first set of landmarks
        else {
            lastFaceLandmarks = nil
            segmentationService.updateFaceLandmarks(nil)
            DispatchQueue.main.async { [weak self] in
                // Ensure self is non-nil before force-unwrapping or calling delegate
                guard let strongSelf = self else { return }
                // The previous force unwrap here was risky, let's avoid it.
                strongSelf.delegate?.viewModel(strongSelf, didUpdateFaceLandmarks: nil)
            }
            return
        }

        lastFaceLandmarks = landmarksData
        segmentationService.updateFaceLandmarks(landmarksData)
        DispatchQueue.main.async { [weak self] in
             guard let strongSelf = self else { return }
            strongSelf.delegate?.viewModel(strongSelf, didUpdateFaceLandmarks: landmarksData)
        }
    }
}

// MARK: - Errors
enum CameraError: Error {
    case configurationFailed
    case permissionDenied
    case runtimeError
}

enum AnalysisError: Error {
    case insufficientQuality
}
