import Foundation
import UIKit
import MediaPipeTasksVision

/// Utility for analyzing frame quality to ensure accurate color extraction
class FrameQualityAnalyzer {

    /// Frame quality assessment result
    struct QualityResult {
        /// Overall score from 0-1.0 (higher is better)
        let score: Float

        /// Face detection confidence
        let faceConfidence: Float

        /// Face position quality (centering)
        let facePositionQuality: Float

        /// Lighting quality
        let lightingQuality: Float

        /// Blur assessment (lower is better)
        let blurScore: Float

        /// Whether the quality is high enough for analysis
        let isAcceptable: Bool

        /// Feedback message if quality issues are detected
        let feedbackMessage: String?

        /// Quality status
        enum Status: String {
            case excellent = "Excellent"
            case good = "Good"
            case acceptable = "Acceptable"
            case poor = "Poor"
            case unacceptable = "Unacceptable"
        }

        /// Get the quality status based on the score
        var status: Status {
            switch score {
            case 0.9...:
                return .excellent
            case 0.75..<0.9:
                return .good
            case 0.6..<0.75:
                return .acceptable
            case 0.4..<0.6:
                return .poor
            default:
                return .unacceptable
            }
        }

        /// Default initializer for a failed quality check
        static let failed = QualityResult(
            score: 0.0,
            faceConfidence: 0.0,
            facePositionQuality: 0.0,
            lightingQuality: 0.0,
            blurScore: 1.0,
            isAcceptable: false,
            feedbackMessage: "No face detected"
        )
    }

    /// Configuration parameters for quality analysis
    struct Configuration {
        /// Minimum acceptable quality score (0-1)
        let minAcceptableScore: Float

        /// Face position thresholds (distance from center as percentage of image dimensions)
        let maxFaceOffset: CGFloat

        /// Minimum face size as percentage of image dimensions
        let minFaceSize: CGFloat

        /// Maximum face size as percentage of image dimensions
        let maxFaceSize: CGFloat

        /// Minimum lighting level (brightness)
        let minLightingLevel: Float

        /// Maximum lighting level (brightness)
        let maxLightingLevel: Float

        /// Default configuration
        static let `default` = Configuration(
            minAcceptableScore: 0.6,
            maxFaceOffset: 0.15,
            minFaceSize: 0.25,
            maxFaceSize: 0.7,
            minLightingLevel: 0.2,
            maxLightingLevel: 0.9
        )
    }

    // Current configuration
    private let configuration: Configuration

    /// Initialize with custom configuration or defaults
    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    /// Analyze frame quality based on segmentation result and face detection
    /// - Parameters:
    ///   - segmentationMask: The segmentation mask showing face/hair regions
    ///   - width: Width of the mask
    ///   - height: Height of the mask
    ///   - image: Optional UIImage for additional analysis
    /// - Returns: Quality analysis result
    func analyzeQuality(
        segmentationMask: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        image: UIImage? = nil
    ) -> QualityResult {

        // Analyze face area and position
        let faceAnalysis = analyzeFacePosition(segmentationMask: segmentationMask, width: width, height: height)
        let faceConfidence = faceAnalysis.faceAreaRatio > 0 ? Float(1.0) : Float(0.0)
        let facePositionQuality = faceAnalysis.positionQuality

        // Analyze image lighting if available
        var lightingQuality: Float = 0.5 // Default middle value
        var blurScore: Float = 0.5 // Default middle value

        if let image = image {
            lightingQuality = analyzeLighting(image: image)
            blurScore = detectBlur(image: image)
        }

        // Calculate overall score
        let weights: (face: Float, position: Float, lighting: Float, blur: Float) = (0.3, 0.3, 0.2, 0.2)
        let faceScore = faceConfidence * weights.face
        let positionScore = facePositionQuality * weights.position
        let lightingScore = lightingQuality * weights.lighting
        let blurComponent = (Float(1.0) - blurScore) * weights.blur
        let weightedScore = faceScore + positionScore + lightingScore + blurComponent

        // Generate feedback message
        var feedbackMessage: String?

        if faceConfidence < 0.5 {
            feedbackMessage = "No face detected or face too small"
        } else if facePositionQuality < 0.5 {
            feedbackMessage = "Please center your face in the frame"
        } else if lightingQuality < 0.5 {
            if lightingQuality < 0.3 {
                feedbackMessage = "Lighting too dark, please move to a brighter area"
            } else {
                feedbackMessage = "Lighting too bright, please reduce direct light"
            }
        } else if blurScore > 0.6 {
            feedbackMessage = "Image is blurry, please hold the camera steady"
        }

        return QualityResult(
            score: weightedScore,
            faceConfidence: faceConfidence,
            facePositionQuality: facePositionQuality,
            lightingQuality: lightingQuality,
            blurScore: blurScore,
            isAcceptable: weightedScore >= configuration.minAcceptableScore,
            feedbackMessage: feedbackMessage
        )
    }

    /// Analyze face position in the frame
    private func analyzeFacePosition(
        segmentationMask: UnsafePointer<UInt8>,
        width: Int,
        height: Int
    ) -> (faceAreaRatio: Float, positionQuality: Float) {

        var facePixelCount = 0
        var skinSum = SIMD2<Int>(0, 0) // For calculating centroid (x, y)

        // Image center
        let centerX = width / 2
        let centerY = height / 2

        // Scan the segmentation mask for skin pixels
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                // Check if pixel is classified as skin (class 2)
                if segmentationMask[index] == 2 {
                    facePixelCount += 1
                    skinSum.x += x
                    skinSum.y += y
                }
            }
        }

        let totalPixels = width * height
        let faceAreaRatio = Float(facePixelCount) / Float(totalPixels)

        // If no face detected, return zeros
        if facePixelCount == 0 {
            return (0.0, 0.0)
        }

        // Calculate face centroid
        let faceCentroidX = skinSum.x / facePixelCount
        let faceCentroidY = skinSum.y / facePixelCount

        // Calculate distance from center
        let offsetX = abs(faceCentroidX - centerX)
        let offsetY = abs(faceCentroidY - centerY)

        // Normalize offset as percentage of dimensions
        let normalizedOffsetX = Float(offsetX) / Float(width)
        let normalizedOffsetY = Float(offsetY) / Float(height)

        // Overall offset (0 = centered, 1 = at edge)
        let offsetScore = sqrt(normalizedOffsetX * normalizedOffsetX + normalizedOffsetY * normalizedOffsetY)

        // Size score (1 = ideal size, 0 = too small/large)
        let idealMinSize = Float(configuration.minFaceSize)
        let idealMaxSize = Float(configuration.maxFaceSize)
        let sizeScore: Float

        if faceAreaRatio < idealMinSize {
            sizeScore = faceAreaRatio / idealMinSize
        } else if faceAreaRatio > idealMaxSize {
            sizeScore = Float(1.0) - ((faceAreaRatio - idealMaxSize) / (Float(1.0) - idealMaxSize))
        } else {
            sizeScore = Float(1.0)
        }

        // Position quality (1 = perfect, 0 = poor)
        let maxAllowedOffset = Float(configuration.maxFaceOffset)
        let positionScore = max(Float(0.0), Float(1.0) - (offsetScore / maxAllowedOffset))

        // Combine position and size scores
        let positionQuality = min(positionScore, sizeScore)

        return (faceAreaRatio, positionQuality)
    }

    /// Analyze lighting quality in the image
    private func analyzeLighting(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }

        // Create a thumbnail for faster analysis
        let thumbnailSize = CGSize(width: 64, height: 64)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return 0.5 }

        // Draw the image in the context
        context.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))

        guard let pixelData = context.data else { return 0.5 }

        let data = pixelData.bindMemory(
            to: UInt8.self,
            capacity: Int(thumbnailSize.width * thumbnailSize.height * 4)
        )

        var totalBrightness: Float = 0
        let pixelCount = Int(thumbnailSize.width * thumbnailSize.height)

        // Calculate average brightness
        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            let r = Float(data[i])
            let g = Float(data[i + 1])
            let b = Float(data[i + 2])

            // Convert RGB to relative luminance
            let luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
            totalBrightness += luminance
        }

        let averageBrightness = totalBrightness / Float(pixelCount)

        // Map brightness to quality score
        let minBrightness = configuration.minLightingLevel
        let maxBrightness = configuration.maxLightingLevel
        let idealBrightness = (minBrightness + maxBrightness) / 2

        if averageBrightness < minBrightness {
            // Too dark
            return averageBrightness / minBrightness
        } else if averageBrightness > maxBrightness {
            // Too bright
            return 1.0 - ((averageBrightness - maxBrightness) / (1.0 - maxBrightness))
        } else if averageBrightness < idealBrightness {
            // Between minimum and ideal (map 0.5-1.0)
            return 0.5 + 0.5 * (averageBrightness - minBrightness) / (idealBrightness - minBrightness)
        } else {
            // Between ideal and maximum (map 0.5-1.0)
            return 1.0 - 0.5 * (averageBrightness - idealBrightness) / (maxBrightness - idealBrightness)
        }
    }

    /// Detect blur in an image (returns score from 0-1, higher = more blurry)
    private func detectBlur(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }

        // Create a grayscale version for blur detection
        let thumbnailSize = CGSize(width: 128, height: 128)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0.5 }

        context.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))

        guard let grayscaleImage = context.makeImage(),
              let pixelData = context.data else { return 0.5 }

        // Simple Laplacian filter for edge detection
        let laplacianKernel: [Float] = [
            0, 1, 0,
            1, -4, 1,
            0, 1, 0
        ]

        let width = Int(thumbnailSize.width)
        let height = Int(thumbnailSize.height)
        let bytesPerRow = context.bytesPerRow
        let data = pixelData.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)

        var sumLaplacian: Float = 0

        // Apply Laplacian filter to detect edges
        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                var pixelValue: Float = 0

                // Apply 3x3 kernel
                for ky in 0..<3 {
                    for kx in 0..<3 {
                        let pixel = Float(data[(y + ky - 1) * bytesPerRow + (x + kx - 1)])
                        pixelValue += pixel * laplacianKernel[ky * 3 + kx]
                    }
                }

                sumLaplacian += abs(pixelValue)
            }
        }

        // Calculate average edge response
        let averageLaplacian = sumLaplacian / Float((width - 2) * (height - 2))

        // Convert to blur score (higher edge response = less blur)
        // Normalize to 0-1 range where 1 = very blurry
        let normalizedBlurScore = max(0.0, min(1.0, 1.0 - (averageLaplacian / Float(20.0))))

        return normalizedBlurScore
    }
}
