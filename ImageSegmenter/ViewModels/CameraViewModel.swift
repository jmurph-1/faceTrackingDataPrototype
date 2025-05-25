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

    func viewModel(_ viewModel: CameraViewModel, didEnterCalibrationMode: Bool)
    func viewModel(_ viewModel: CameraViewModel, didUpdateCalibrationProgress: Float)
    func viewModel(_ viewModel: CameraViewModel, didCompleteCalibration: WhiteBalanceCalibration)
}

enum CameraMode {
    case calibration
    case analysis
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

    private(set) var currentMode: CameraMode = .calibration
    private(set) var whiteBalanceCalibration: WhiteBalanceCalibration?
    private(set) var isCalibrated: Bool = false
    private var calibrationFrameCount: Int = 0
    private let requiredCalibrationFrames: Int = 5
    private var calibrationAccumulator: [(r: Float, g: Float, b: Float)] = []
    private(set) var detectedWhiteRegion: CGRect?
    private(set) var isDetectingWhiteReference: Bool = false
    private var shouldProcessFrames: Bool = false

    // MARK: - Initialization
    override init() {
        super.init()
        cameraService.delegate = self
        segmentationService.delegate = self
        classificationService.delegate = self
        LoggingService.info("CVM: Initializing and configuring services")
        configureInitialServices()
    }

    private func configureInitialServices() {
        configureSegmentationService()
        configureFaceLandmarkerService()
    }

    // MARK: - Public Methods
    func startCamera() {
        LoggingService.info("CVM: Starting camera session")
        configureInitialServices() // Ensure services are ready
        cameraService.startLiveCameraSession { [weak self] configuration in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                switch configuration {
                case .success:
                    strongSelf.isSessionRunning = true
                    strongSelf.delegate?.viewModelDidStartCamera(strongSelf)
                    LoggingService.info("CVM: Camera session started successfully")
                case .failed:
                    LoggingService.error("CVM: Camera configuration failed")
                    strongSelf.delegate?.viewModel(strongSelf, didEncounterError: CameraError.configurationFailed)
                case .permissionDenied:
                    LoggingService.error("CVM: Camera permission denied")
                    strongSelf.delegate?.viewModel(strongSelf, didEncounterError: CameraError.permissionDenied)
                default: break
                }
            }
        }
    }

    func stopCamera() {
        LoggingService.info("CVM: Stopping camera session")
        cameraService.stopSession()
        isSessionRunning = false
        delegate?.viewModelDidStopCamera(self)
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

    func startCalibrationMode() {
        LoggingService.info("CALIBRATION_FLOW: Starting calibration")
        currentMode = .calibration
        isDetectingWhiteReference = false  // Don't start detecting until explicitly triggered
        calibrationFrameCount = 0
        calibrationAccumulator.removeAll()
        shouldProcessFrames = false  // Ensure we're not processing frames until calibration starts
        delegate?.viewModel(self, didEnterCalibrationMode: true)
    }

    @objc func captureWhiteReference() {
        LoggingService.info("CALIBRATION_FLOW: Starting white reference capture")
        currentMode = .calibration
        isDetectingWhiteReference = true
        calibrationFrameCount = 0
        calibrationAccumulator.removeAll()
        
        // Ensure we're receiving frames
        if !isSessionRunning {
            LoggingService.warning("CALIBRATION_FLOW: Camera session not running, starting camera")
            startCamera()
        } else {
            LoggingService.info("CALIBRATION_FLOW: Camera session already running")
        }
    }

    func processFrame(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timeStamps: Int) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            LoggingService.warning("FRAME_FLOW: Failed to get pixel buffer from sample buffer")
            return
        }
        currentPixelBuffer = pixelBuffer
        
        // Always update preview buffer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.viewModel(self, didUpdateSegmentedBuffer: pixelBuffer)
        }
        
        // Process frames based on mode
        if currentMode == .calibration && isDetectingWhiteReference {
            LoggingService.info("FRAME_FLOW: Processing frame for calibration")
            processCalibrationFrame()
            return
        }
        
        // Normal frame processing
        if shouldProcessFrames {
            let currentTime = Date().timeIntervalSince1970
            guard currentTime - lastProcessingTime >= processingThrottleInterval else {
                return
            }
            lastProcessingTime = currentTime
            
            frameCount += 1
            if currentTime - lastFPSUpdateTime >= 1.0 {
                currentFPS = Float(frameCount) / Float(currentTime - lastFPSUpdateTime)
                frameCount = 0
                lastFPSUpdateTime = currentTime
            }
            
            faceLandmarkerService?.detectLandmarksAsync(sampleBuffer: sampleBuffer, orientation: orientation, timeStamps: Int(currentTime * 1000))
            segmentationService.processFrame(sampleBuffer: sampleBuffer, orientation: orientation, timeStamps: Int(currentTime * 1000))
        }
    }

    private func processCalibrationFrame() {
        LoggingService.debug("CALIBRATION_FLOW: Processing calibration frame")
        guard let pixelBuffer = currentPixelBuffer else {
            LoggingService.warning("CALIBRATION_FLOW: Cannot process calibration frame - no pixel buffer")
            return
        }

        // Always update preview during calibration
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.viewModel(self, didUpdateSegmentedBuffer: pixelBuffer)
        }
        
        // Ensure segmentation service is ready
        if !segmentationService.isPrepared {
            let attrs = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                        kCVPixelBufferWidthKey as String: CVPixelBufferGetWidth(pixelBuffer),
                        kCVPixelBufferHeightKey as String: CVPixelBufferGetHeight(pixelBuffer)] as [String : Any]
            
            var formatDescription: CMFormatDescription?
            let status = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                                     imageBuffer: pixelBuffer,
                                                                     formatDescriptionOut: &formatDescription)
            
            if status == noErr, let formatDescription = formatDescription {
                segmentationService.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
            } else {
                LoggingService.warning("CALIBRATION_FLOW: Failed to create format description")
                return
            }
        }
        
        guard let texture = segmentationService.makeTextureFromPixelBuffer(pixelBuffer) else {
            LoggingService.warning("CALIBRATION_FLOW: Cannot process calibration frame - failed to create texture")
            return
        }

        // Define white reference region (smaller region in center for better accuracy)
        let centerRegion = CGRect(x: 0.45, y: 0.45, width: 0.1, height: 0.1)  // 10% of frame in center
        detectedWhiteRegion = centerRegion
        
        // Extract color from white region
        if let whiteColor = segmentationService.extractWhiteReferenceColor(
            from: texture,
            region: centerRegion,
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        ) {
            let frameMsg = "Frame \(calibrationFrameCount + 1)/\(requiredCalibrationFrames)"
            let rgbMsg = "RGB(\(Int(whiteColor.r)), \(Int(whiteColor.g)), \(Int(whiteColor.b)))"
            LoggingService.info("CALIBRATION_FLOW: \(frameMsg) - White reference \(rgbMsg)")
            
            calibrationAccumulator.append(whiteColor)
            calibrationFrameCount += 1
            
            let progress = Float(calibrationFrameCount) / Float(requiredCalibrationFrames)
            delegate?.viewModel(self, didUpdateCalibrationProgress: progress)
            
            if calibrationFrameCount >= requiredCalibrationFrames {
                LoggingService.info("CALIBRATION_FLOW: Required frames collected, finalizing calibration")
                finalizeCalibration()
            }
        } else {
            LoggingService.warning("CALIBRATION_FLOW: Failed to extract white reference from frame - ensure white reference card is centered and well-lit")
        }
    }

    private func finalizeCalibration() {
        LoggingService.info("CALIBRATION_FLOW: Starting calibration finalization")
        
        // Calculate average white reference color
        let avgColor = calibrationAccumulator.reduce((r: 0.0, g: 0.0, b: 0.0)) { acc, color in
            (r: acc.r + color.r, g: acc.g + color.g, b: acc.b + color.b)
        }
        let count = Float(calibrationAccumulator.count)
        let finalColor = (
            r: avgColor.r / count,
            g: avgColor.g / count,
            b: avgColor.b / count
        )
        
        LoggingService.info("CALIBRATION_FLOW: Average white reference - RGB(\(Int(finalColor.r)), \(Int(finalColor.g)), \(Int(finalColor.b)))")
        
        // Calculate white balance calibration
        let calibration = WhiteBalanceCalibration.calculate(from: finalColor)
        whiteBalanceCalibration = calibration
        
        let factors = "R:\(String(format: "%.2f", calibration.redFactor)) "
            + "G:\(String(format: "%.2f", calibration.greenFactor)) "
            + "B:\(String(format: "%.2f", calibration.blueFactor))"
        LoggingService.info("CALIBRATION_FLOW: Calculated white balance factors - \(factors)")
        
        // Apply calibration to services
        segmentationService.setWhiteBalanceCalibration(calibration)
        
        // Update state
        isCalibrated = true
        currentMode = .analysis
        isDetectingWhiteReference = false
        detectedWhiteRegion = nil
        shouldProcessFrames = true
        
        LoggingService.info("CALIBRATION_FLOW: Calibration complete - Entering analysis mode")
        
        // Notify delegate
        delegate?.viewModel(self, didCompleteCalibration: calibration)
    }
    
    func skipCalibration() {
        LoggingService.info("CALIBRATION_FLOW: Skipping calibration - Using identity white balance")
        whiteBalanceCalibration = .identity
        segmentationService.setWhiteBalanceCalibration(.identity)
        isCalibrated = true
        currentMode = .analysis
        isDetectingWhiteReference = false
        detectedWhiteRegion = nil
        shouldProcessFrames = true
        delegate?.viewModel(self, didCompleteCalibration: .identity)
    }

    // MARK: - Private Methods
    private func configureSegmentationService() {
        guard let modelPath = InferenceConfigurationManager.sharedInstance.model.modelPath else {
            LoggingService.error("CVM: Failed to configure segmentation - model path is nil")
            delegate?.viewModel(self, didEncounterError: NSError(domain: "CameraViewModel", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Segmentation model path is nil."]))
            return
        }
        segmentationService.configure(with: modelPath)
    }

    private func configureFaceLandmarkerService() {
        if faceLandmarkerService != nil {
            clearFaceLandmarkerService()
        }
        faceLandmarkerService = FaceLandmarkerService.liveStreamFaceLandmarkerService(
            modelPath: Bundle.main.path(forResource: "face_landmarker", ofType: "task"),
            liveStreamDelegate: self,
            delegate: InferenceConfigurationManager.sharedInstance.delegate
        )
        if faceLandmarkerService == nil {
            LoggingService.error("CVM: Failed to create FaceLandmarkerService")
        }
    }

    private func clearFaceLandmarkerService() {
        faceLandmarkerService = nil
        lastFaceLandmarks = nil
        delegate?.viewModel(self, didUpdateFaceLandmarks: nil)
    }

    private func clearServices() {
        LoggingService.debug("CVM: Clearing services")
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

    private func makeTextureFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        var textureOut: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let textureCache = segmentationService.textureCache else {
            return nil
        }
        
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &textureOut
        )
        
        guard status == kCVReturnSuccess,
              let cvTexture = textureOut,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            return nil
        }
        
        return texture
    }
}

// MARK: - CameraServiceDelegate
extension CameraViewModel: CameraServiceDelegate {
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        // Only log if there's an issue with the sample buffer
        if CMSampleBufferIsValid(sampleBuffer) == false {
            LoggingService.warning("FRAME_FLOW: Received invalid sample buffer")
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        backgroundQueue.async { [weak self] in
            self?.processFrame(sampleBuffer: sampleBuffer, orientation: orientation, timeStamps: timestamp)
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
        if let error = error {
            LoggingService.error("CVM: Landmark detection error: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.viewModel(strongSelf, didEncounterError: error)
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
