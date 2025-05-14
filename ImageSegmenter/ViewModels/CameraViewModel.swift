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
    func viewModel(_ viewModel: CameraViewModel, didUpdateColorInfo colorInfo: MultiClassSegmentedImageRenderer.ColorInfo)
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
    
    // Public properties
    weak var delegate: CameraViewModelDelegate?
    
    // Current state properties
    private(set) var isSessionRunning = false
    private(set) var isFaceTrackingEnabled = false
    private(set) var currentFrameQualityScore: FrameQualityService.QualityScore?
    private(set) var currentColorInfo: MultiClassSegmentedImageRenderer.ColorInfo?
    private(set) var lastFaceLandmarks: [NormalizedLandmark]?
    private(set) var currentPixelBuffer: CVPixelBuffer?
    private(set) var currentFaceBoundingBox: CGRect?
    
    // Services
    private let cameraService = CameraService()
    private let segmentationService = SegmentationService()
    private let classificationService = ClassificationService()
    
    // Face landmarker service
    private var faceLandmarkerService: FaceLandmarkerService?
    
    // Queues
    private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.cameraViewModel.backgroundQueue")
    
    // Throttling properties
    private var lastProcessingTime: TimeInterval = 0
    private let processingThrottleInterval: TimeInterval = 0.1  // 10Hz throttle
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        // Configure services
        cameraService.delegate = self
        segmentationService.delegate = self
        classificationService.delegate = self
        
        // Initialize segmentation
        configureSegmentationService()
    }
    
    // MARK: - Public Methods
    
    /// Start camera session
    func startCamera() {
        cameraService.startLiveCameraSession { [weak self] configuration in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch configuration {
                case .success:
                    self.isSessionRunning = true
                    self.delegate?.viewModelDidStartCamera(self)
                case .failed:
                    self.delegate?.viewModel(self, didEncounterError: CameraError.configurationFailed)
                case .permissionDenied:
                    self.delegate?.viewModel(self, didEncounterError: CameraError.permissionDenied)
                default:
                    break
                }
            }
        }
    }
    
    /// Stop camera session
    func stopCamera() {
        cameraService.stopSession()
        isSessionRunning = false
        delegate?.viewModelDidStopCamera(self)
        clearServices()
    }
    
    /// Resume interrupted session
    func resumeCamera() {
        cameraService.resumeInterruptedSession { [weak self] isSessionRunning in
            guard let self = self else { return }
            
            if isSessionRunning {
                self.isSessionRunning = true
                self.delegate?.viewModelDidResumeSession(self)
                self.configureServicesBasedOnMode()
            }
        }
    }
    
    /// Toggle between face tracking and segmentation modes
    func toggleFaceTracking(enabled: Bool) {
        if isFaceTrackingEnabled == enabled {
            return // No change
        }
        
        isFaceTrackingEnabled = enabled
        configureServicesBasedOnMode()
    }
    
    /// Analyze current frame
    func analyzeCurrentFrame() {
        guard let pixelBuffer = currentPixelBuffer, 
              let colorInfo = currentColorInfo, 
              isFrameQualitySufficientForAnalysis else {
            delegate?.viewModel(self, didEncounterError: AnalysisError.insufficientQuality)
            return
        }
        
        classificationService.analyzeFrame(pixelBuffer: pixelBuffer, colorInfo: colorInfo)
    }
    
    // MARK: - Private Methods
    
    /// Configure services based on the current mode (face tracking or segmentation)
    private func configureServicesBasedOnMode() {
        if isFaceTrackingEnabled {
            // Enable face tracking, disable segmentation
            segmentationService.clearImageSegmenterService()
            configureFaceLandmarkerService()
        } else {
            // Enable segmentation, disable face tracking
            clearFaceLandmarkerService()
            configureSegmentationService()
        }
    }
    
    /// Configure segmentation service
    private func configureSegmentationService() {
        segmentationService.configure(with: InferenceConfigurationManager.sharedInstance.model.modelPath!)
    }
    
    /// Configure face landmarker service
    private func configureFaceLandmarkerService() {
        clearFaceLandmarkerService()
        
        // Create a new face landmarker service
        faceLandmarkerService = FaceLandmarkerService
            .liveStreamFaceLandmarkerService(
                modelPath: Bundle.main.path(forResource: "face_landmarker", ofType: "task"),
                liveStreamDelegate: self,
                delegate: InferenceConfigurationManager.sharedInstance.delegate)
    }
    
    /// Clear face landmarker service
    private func clearFaceLandmarkerService() {
        faceLandmarkerService = nil
        // Clear landmarks
        lastFaceLandmarks = nil
        delegate?.viewModel(self, didUpdateFaceLandmarks: nil)
    }
    
    /// Clear all services
    private func clearServices() {
        segmentationService.clearImageSegmenterService()
        clearFaceLandmarkerService()
    }
    
    /// Process current frame
    private func processFrame(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Store the current pixel buffer
        currentPixelBuffer = pixelBuffer
        
        // Get current time for throttling
        let currentTime = Date().timeIntervalSince1970
        let timeElapsedSinceLastProcessing = currentTime - lastProcessingTime
        let shouldProcess = timeElapsedSinceLastProcessing >= processingThrottleInterval
        
        if shouldProcess {
            // Update throttle timestamp
            lastProcessingTime = currentTime
            
            // Process based on current mode
            if isFaceTrackingEnabled {
                // Process face landmarks
                faceLandmarkerService?.detectLandmarksAsync(
                    sampleBuffer: sampleBuffer,
                    orientation: orientation,
                    timeStamps: Int(currentTime * 1000)
                )
            } else {
                // Process segmentation
                segmentationService.processFrame(
                    sampleBuffer: sampleBuffer,
                    orientation: orientation,
                    timeStamps: Int(currentTime * 1000)
                )
            }
        }
    }
    
    /// Check if the current frame quality is sufficient for analysis
    private var isFrameQualitySufficientForAnalysis: Bool {
        return currentFrameQualityScore?.isAcceptableForAnalysis ?? false
    }
    
    /// Check frame for error conditions and provide guidance
    private func checkForErrorConditions() {
        // Get the current face bounding box
        guard let faceBoundingBox = currentFaceBoundingBox else {
            delegate?.viewModel(self, didDisplayWarning: "No face detected. Please center your face in the frame.")
            return
        }
        
        // Check for quality issues
        if let qualityScore = currentFrameQualityScore {
            // Check overall quality first
            if qualityScore.overall < FrameQualityService.minimumQualityScoreForAnalysis {
                if let feedback = qualityScore.feedbackMessage {
                    delegate?.viewModel(self, didDisplayWarning: feedback)
                    return
                }
            }
            
            // Check brightness issues
            if qualityScore.brightness < FrameQualityService.minimumBrightnessScoreForAnalysis {
                if qualityScore.brightness < 0.3 {
                    delegate?.viewModel(self, didDisplayWarning: "Too dark. Please move to a brighter area.")
                } else if qualityScore.brightness > 0.9 {
                    delegate?.viewModel(self, didDisplayWarning: "Too bright. Please reduce direct light on your face.")
                } else {
                    delegate?.viewModel(self, didDisplayWarning: "Poor lighting detected. Please find better lighting.")
                }
                return
            }
            
            // Check face size and position
            if qualityScore.faceSize < FrameQualityService.minimumFaceSizeScoreForAnalysis {
                if qualityScore.faceSize < 0.3 {
                    delegate?.viewModel(self, didDisplayWarning: "Face too small. Please move closer to the camera.")
                } else {
                    delegate?.viewModel(self, didDisplayWarning: "Face position issue. Please center your face.")
                }
                return
            }
            
            // Check position
            if qualityScore.facePosition < FrameQualityService.minimumFacePositionScoreForAnalysis {
                delegate?.viewModel(self, didDisplayWarning: "Please center your face in the frame.")
                return
            }
            
            // Check sharpness
            if qualityScore.sharpness < 0.5 {
                delegate?.viewModel(self, didDisplayWarning: "Image is blurry. Please hold the device steady.")
                return
            }
        }
    }
}

// MARK: - CameraServiceDelegate
extension CameraViewModel: CameraServiceDelegate {
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        // Process the frame in background queue
        backgroundQueue.async { [weak self] in
            self?.processFrame(sampleBuffer: sampleBuffer, orientation: orientation)
        }
    }
    
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        isSessionRunning = false
        delegate?.viewModelDidDetectSessionInterruption(self, canResume: resumeManually)
        clearServices()
    }
    
    func sessionInterruptionEnded() {
        delegate?.viewModelDidResumeSession(self)
        configureServicesBasedOnMode()
    }
    
    func didEncounterSessionRuntimeError() {
        isSessionRunning = false
        delegate?.viewModel(self, didEncounterError: CameraError.runtimeError)
    }
}

// MARK: - SegmentationServiceDelegate
extension CameraViewModel: SegmentationServiceDelegate {
    func segmentationService(_ service: SegmentationService, didCompleteSegmentation result: SegmentationResult) {
        // Update state with segmentation results
        currentColorInfo = result.colorInfo
        currentFaceBoundingBox = result.faceBoundingBox
        
        // Notify delegate about the new segmented buffer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update delegate with segmented buffer
            self.delegate?.viewModel(self, didUpdateSegmentedBuffer: result.outputPixelBuffer)
            
            // Update delegate with color information
            self.delegate?.viewModel(self, didUpdateColorInfo: result.colorInfo)
            
            // Evaluate frame quality if we have a face bounding box
            if let faceBoundingBox = result.faceBoundingBox,
               let pixelBuffer = self.currentPixelBuffer {
                let imageSize = CGSize(
                    width: CVPixelBufferGetWidth(pixelBuffer),
                    height: CVPixelBufferGetHeight(pixelBuffer)
                )
                
                let qualityScore = FrameQualityService.evaluateFrameQuality(
                    pixelBuffer: pixelBuffer,
                    faceBoundingBox: faceBoundingBox,
                    imageSize: imageSize
                )
                
                // Update quality score
                self.currentFrameQualityScore = qualityScore
                
                // Notify delegate about quality update
                self.delegate?.viewModel(self, didUpdateFrameQuality: qualityScore)
                
                // Check for error conditions
                self.checkForErrorConditions()
            }
        }
    }
    
    func segmentationService(_ service: SegmentationService, didFailWithError error: Error) {
        delegate?.viewModel(self, didEncounterError: error)
    }
}

// MARK: - ClassificationServiceDelegate
extension CameraViewModel: ClassificationServiceDelegate {
    func classificationService(_ service: ClassificationService, didCompleteAnalysis result: AnalysisResult) {
        // Forward the analysis result to the view controller
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Raise a custom notification with the result
            NotificationCenter.default.post(
                name: Notification.Name("AnalysisResultReady"),
                object: self,
                userInfo: ["result": result]
            )
        }
    }
    
    func classificationService(_ service: ClassificationService, didFailWithError error: Error) {
        delegate?.viewModel(self, didEncounterError: error)
    }
}

// MARK: - FaceLandmarkerServiceLiveStreamDelegate
extension CameraViewModel: FaceLandmarkerServiceLiveStreamDelegate {
    func faceLandmarkerService(_ faceLandmarkerService: FaceLandmarkerService, didFinishLandmarkDetection result: FaceLandmarkerResultBundle?, error: Error?) {
        if let error = error {
            delegate?.viewModel(self, didEncounterError: error)
            return
        }
        
        // Only process if face tracking is still enabled
        guard isFaceTrackingEnabled else { return }
        
        // Process the landmarks if available
        if let faceLandmarkerResults = result?.faceLandmarkerResults,
           let firstResult = faceLandmarkerResults.first,
           let faceLandmarkerResult = firstResult,
           !faceLandmarkerResult.faceLandmarks.isEmpty,
           let landmarks = faceLandmarkerResult.faceLandmarks.first {
            
            // Update landmarks
            lastFaceLandmarks = landmarks
            
            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // If we have a valid pixel buffer, update preview
                if let pixelBuffer = self.currentPixelBuffer {
                    // Update the preview with the original camera frame
                    self.delegate?.viewModel(self, didUpdateSegmentedBuffer: pixelBuffer)
                    
                    // Notify about landmarks update
                    self.delegate?.viewModel(self, didUpdateFaceLandmarks: landmarks)
                }
            }
        } else {
            // No landmarks detected
            lastFaceLandmarks = nil
            delegate?.viewModel(self, didUpdateFaceLandmarks: nil)
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