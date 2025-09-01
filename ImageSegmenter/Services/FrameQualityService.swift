import Foundation
import UIKit
import MediaPipeTasksVision

/// Service for evaluating frame quality for color analysis
class FrameQualityService {

    // MARK: - Quality score thresholds

    /// Minimum overall quality score required for analysis (0-1)
    static let minimumQualityScoreForAnalysis: Float = 0.7

    /// Minimum face size score required for analysis (0-1)
    static let minimumFaceSizeScoreForAnalysis: Float = 0.6

    /// Minimum face position score required for analysis (0-1)
    static let minimumFacePositionScoreForAnalysis: Float = 0.7

    /// Minimum brightness score required for analysis (0-1)
    static let minimumBrightnessScoreForAnalysis: Float = 0.6

    /// Quality score result
    struct QualityScore: Equatable {
        /// Overall quality score (0-1)
        let overall: Float

        /// Face size score (0-1)
        let faceSize: Float

        /// Face position score (0-1)
        let facePosition: Float

        /// Brightness score (0-1)
        let brightness: Float

        /// Blur score (0-1, higher is better/less blurry)
        let sharpness: Float

        /// Whether the frame meets the minimum quality requirements for analysis
        var isAcceptableForAnalysis: Bool {
            return overall >= FrameQualityService.minimumQualityScoreForAnalysis &&
                   faceSize >= FrameQualityService.minimumFaceSizeScoreForAnalysis &&
                   facePosition >= FrameQualityService.minimumFacePositionScoreForAnalysis &&
                   brightness >= FrameQualityService.minimumBrightnessScoreForAnalysis
        }

        /// Get feedback message for improving capture quality
        var feedbackMessage: String? {
            if isAcceptableForAnalysis {
                return nil
            }

            if faceSize < FrameQualityService.minimumFaceSizeScoreForAnalysis {
                return "Move closer to the camera"
            }

            if facePosition < FrameQualityService.minimumFacePositionScoreForAnalysis {
                return "Center your face in the frame"
            }

            if brightness < FrameQualityService.minimumBrightnessScoreForAnalysis {
                return "Find better lighting"
            }

            if sharpness < 0.5 {
                return "Hold still to reduce blur"
            }

            return "Improve capture quality"
        }
    }

    /// Evaluate the quality of a frame for color analysis with early termination for poor quality frames
    /// - Parameters:
    ///   - pixelBuffer: The frame pixel buffer
    ///   - faceBoundingBox: The bounding box of the detected face
    ///   - imageSize: The size of the image
    /// - Returns: Quality score result
    static func evaluateFrameQuality(
        pixelBuffer: CVPixelBuffer,
        faceBoundingBox: CGRect,
        imageSize: CGSize
    ) -> QualityScore {
        // 1. Calculate face size score (how much of the frame is occupied by the face)
        let faceSizeScore = FrameQualityEvaluator.faceSizeScore(faceBoundingBox: faceBoundingBox, imageSize: imageSize)

        // Early termination if face size is too small or too large
        if faceSizeScore < minimumFaceSizeScoreForAnalysis * 0.7 {
            return QualityScore(
                overall: faceSizeScore * 0.25, // Approximate overall score
                faceSize: faceSizeScore,
                facePosition: 0,
                brightness: 0,
                sharpness: 0
            )
        }

        // 2. Calculate face position score (how centered the face is)
        let facePositionScore = FrameQualityEvaluator.facePositionScore(faceBoundingBox: faceBoundingBox, imageSize: imageSize)

        if facePositionScore < minimumFacePositionScoreForAnalysis * 0.7 {
            // Calculate partial overall score with what we have so far
            let partialOverall = (faceSizeScore * 0.25) + (facePositionScore * 0.25)

            return QualityScore(
                overall: partialOverall,
                faceSize: faceSizeScore,
                facePosition: facePositionScore,
                brightness: 0,
                sharpness: 0
            )
        }

        // 3. Calculate brightness score
        let brightnessScore = FrameQualityEvaluator.brightnessScore(pixelBuffer: pixelBuffer, faceBoundingBox: faceBoundingBox)

        if brightnessScore < minimumBrightnessScoreForAnalysis * 0.7 {
            // Calculate partial overall score with what we have so far
            let partialOverall = (faceSizeScore * 0.25) + (facePositionScore * 0.25) + (brightnessScore * 0.3)

            return QualityScore(
                overall: partialOverall,
                faceSize: faceSizeScore,
                facePosition: facePositionScore,
                brightness: brightnessScore,
                sharpness: 0
            )
        }

        // 4. Calculate sharpness/blur score only if other metrics are acceptable
        let sharpnessScore = FrameQualityEvaluator.sharpnessScore(pixelBuffer: pixelBuffer, faceBoundingBox: faceBoundingBox)

        // 5. Calculate overall score (weighted average)
        let overall = (faceSizeScore * 0.25) + (facePositionScore * 0.25) + (brightnessScore * 0.3) + (sharpnessScore * 0.2)

        return QualityScore(
            overall: overall,
            faceSize: faceSizeScore,
            facePosition: facePositionScore,
            brightness: brightnessScore,
            sharpness: sharpnessScore
        )
    }


    /// Evaluate the quality of a frame using face landmarks instead of bounding box
    /// - Parameters:
    ///   - pixelBuffer: The frame pixel buffer
    ///   - imageSize: The size of the image
    /// - Returns: Quality score result
    static func evaluateFrameQualityWithLandmarks(
        pixelBuffer: CVPixelBuffer,
        landmarks: [NormalizedLandmark]?,
        imageSize: CGSize
    ) -> QualityScore {
        // print("Evaluating quality with landmarks: \(landmarks?.count ?? 0) points")

        // 1. Calculate face size score
        let faceSizeScore = FrameQualityEvaluator.faceSizeScore(
            landmarks: landmarks,
            imageSize: imageSize
        )

        // Early termination if face size is too small or too large
        if faceSizeScore < minimumFaceSizeScoreForAnalysis * 0.7 {
            return QualityScore(
                overall: faceSizeScore * 0.25, // Approximate overall score
                faceSize: faceSizeScore,
                facePosition: 0,
                brightness: 0,
                sharpness: 0
            )
        }

        // 2. Calculate face position score
        let facePositionScore = FrameQualityEvaluator.facePositionScore(
            landmarks: landmarks,
            imageSize: imageSize
        )

        if facePositionScore < minimumFacePositionScoreForAnalysis * 0.7 {
            // Calculate partial overall score with what we have so far
            let partialOverall = (faceSizeScore * 0.25) + (facePositionScore * 0.25)

            return QualityScore(
                overall: partialOverall,
                faceSize: faceSizeScore,
                facePosition: facePositionScore,
                brightness: 0,
                sharpness: 0
            )
        }

        // 3. Calculate brightness score
        let brightnessScore = FrameQualityEvaluator.brightnessScore(
            landmarks: landmarks,
            pixelBuffer: pixelBuffer
        )

        if brightnessScore < minimumBrightnessScoreForAnalysis * 0.7 {
            // Calculate partial overall score with what we have so far
            let partialOverall = (faceSizeScore * 0.25) + (facePositionScore * 0.25) + (brightnessScore * 0.3)

            return QualityScore(
                overall: partialOverall,
                faceSize: faceSizeScore,
                facePosition: facePositionScore,
                brightness: brightnessScore,
                sharpness: 0
            )
        }

        // 4. Calculate sharpness/blur score only if other metrics are acceptable
        let sharpnessScore = FrameQualityEvaluator.sharpnessScore(
            landmarks: landmarks,
            pixelBuffer: pixelBuffer
        )

        // print("Sharpness from Landmarks: \(sharpnessScore)")

        // 5. Calculate overall score (weighted average)
        let overall = (faceSizeScore * 0.25) + (facePositionScore * 0.25) + (brightnessScore * 0.3) + (sharpnessScore * 0.2)

        return QualityScore(
            overall: overall,
            faceSize: faceSizeScore,
            facePosition: facePositionScore,
            brightness: brightnessScore,
            sharpness: sharpnessScore
        )
    }
}
