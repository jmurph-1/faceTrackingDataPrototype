import Foundation
import UIKit
import Vision
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
        let faceSizeScore = calculateFaceSizeScore(faceBoundingBox: faceBoundingBox, imageSize: imageSize)
        
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
        let facePositionScore = calculateFacePositionScore(faceBoundingBox: faceBoundingBox, imageSize: imageSize)
        
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
        let brightnessScore = calculateBrightnessScore(pixelBuffer: pixelBuffer, faceBoundingBox: faceBoundingBox)
        
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
        let sharpnessScore = calculateSharpnessScore(pixelBuffer: pixelBuffer, faceBoundingBox: faceBoundingBox)

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

    // MARK: - Private calculation methods

    /// Calculate face size score
    /// - Parameters:
    ///   - faceBoundingBox: Face bounding box
    ///   - imageSize: Image size
    /// - Returns: Score from 0 to 1
    private static func calculateFaceSizeScore(faceBoundingBox: CGRect, imageSize: CGSize) -> Float {
        // Calculate the ratio of face area to image area
        let imageArea = imageSize.width * imageSize.height
        let faceArea = faceBoundingBox.width * faceBoundingBox.height
        let ratio = Float(faceArea / imageArea)

        // Ideal face area is 15-35% of the frame
        if ratio < 0.05 {
            // Face is too small
            return max(0, ratio / 0.05)
        } else if ratio > 0.6 {
            // Face is too large
            return max(0, Float(1.0 - ((ratio - 0.6) / 0.4)))
        } else if ratio > 0.35 {
            // Face is a bit large but acceptable
            return Float(1.0 - ((ratio - 0.35) / (0.6 - 0.35)) * 0.2)
        } else if ratio < 0.15 {
            // Face is a bit small but acceptable
            return Float(0.8 + (ratio - 0.05) / (0.15 - 0.05) * 0.2)
        } else {
            // Face is ideal size (15-35%)
            return 1.0
        }
    }

    /// Calculate face position score (how centered the face is)
    /// - Parameters:
    ///   - faceBoundingBox: Face bounding box
    ///   - imageSize: Image size
    /// - Returns: Score from 0 to 1
    private static func calculateFacePositionScore(faceBoundingBox: CGRect, imageSize: CGSize) -> Float {
        // Calculate the center point of the face
        let faceCenterX = faceBoundingBox.midX
        let faceCenterY = faceBoundingBox.midY

        // Calculate the center point of the image
        let imageCenterX = imageSize.width / 2
        let imageCenterY = imageSize.height / 2

        // Calculate the distance from the face center to the image center
        let distanceX = abs(faceCenterX - imageCenterX) / (imageSize.width / 2)
        let distanceY = abs(faceCenterY - imageCenterY) / (imageSize.height / 2)

        // Calculate position score (1 = centered, 0 = at the edge)
        let xScore = Float(1.0 - distanceX)
        let yScore = Float(1.0 - distanceY)

        // Return average of x and y scores, with more weight to horizontal alignment
        return (xScore * 0.6) + (yScore * 0.4)
    }

    /// Calculate brightness score using CIAreaAverage for efficiency
    /// - Parameters:
    ///   - pixelBuffer: Image pixel buffer
    ///   - faceBoundingBox: Face bounding box
    /// - Returns: Score from 0 to 1
    private static func calculateBrightnessScore(pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect) -> Float {
        // Create a CIImage from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Calculate the face rectangle in pixel coordinates
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let faceRect = CGRect(
            x: faceBoundingBox.origin.x * CGFloat(width),
            y: faceBoundingBox.origin.y * CGFloat(height),
            width: faceBoundingBox.width * CGFloat(width),
            height: faceBoundingBox.height * CGFloat(height)
        )
        
        // Crop to just the face area
        let croppedImage = ciImage.cropped(to: faceRect)
        
        let filter = CIFilter(name: "CIAreaAverage")!
        filter.setValue(croppedImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: CGRect(x: 0, y: 0, width: 1, height: 1)), forKey: "inputExtent")
        
        guard let outputImage = filter.outputImage else {
            return 0.5 // Default medium score if we can't calculate
        }
        
        // Create a bitmap to get the average color
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        // Calculate luminance from the average color
        let r = Float(bitmap[0]) / 255.0
        let g = Float(bitmap[1]) / 255.0
        let b = Float(bitmap[2]) / 255.0
        let averageBrightness = (0.299 * r + 0.587 * g + 0.114 * b)
        
        // Ideal brightness is between 0.4 and 0.7
        if averageBrightness < 0.2 {
            // Too dark
            return averageBrightness / 0.2
        } else if averageBrightness > 0.8 {
            // Too bright
            return Float(1.0 - ((averageBrightness - 0.8) / 0.2))
        } else if averageBrightness < 0.4 {
            // Slightly dark but acceptable
            return Float(0.7 + ((averageBrightness - 0.2) / (0.4 - 0.2)) * 0.3)
        } else if averageBrightness > 0.7 {
            // Slightly bright but acceptable
            return Float(0.7 + ((0.8 - averageBrightness) / (0.8 - 0.7)) * 0.3)
        } else {
            // Ideal brightness
            return 1.0
        }
    }

    /// Calculate sharpness/blur score using highly optimized method
    /// - Parameters:
    ///   - pixelBuffer: Image pixel buffer
    ///   - faceBoundingBox: Face bounding box
    /// - Returns: Score from 0 to 1 (higher is sharper)
    private static func calculateSharpnessScore(pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect) -> Float {
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0.5
        }
        
        // Calculate the face rectangle in pixel coordinates
        let faceRect = CGRect(
            x: Int(faceBoundingBox.origin.x * CGFloat(width)),
            y: Int(faceBoundingBox.origin.y * CGFloat(height)),
            width: Int(faceBoundingBox.width * CGFloat(width)),
            height: Int(faceBoundingBox.height * CGFloat(height))
        )
        
        let safeRect = CGRect(
            x: max(0, min(width - 1, Int(faceRect.origin.x))),
            y: max(0, min(height - 1, Int(faceRect.origin.y))),
            width: min(width - Int(faceRect.origin.x), Int(faceRect.width)),
            height: min(height - Int(faceRect.origin.y), Int(faceRect.height))
        )
        
        let gridSize = 4
        let stepX = max(1, Int(safeRect.width) / gridSize)
        let stepY = max(1, Int(safeRect.height) / gridSize)
        
        var gradientSum: Float = 0
        var sampleCount = 0
        
        // Sample in a grid pattern
        for gridY in 0..<gridSize {
            for gridX in 0..<gridSize {
                let x = Int(safeRect.origin.x) + gridX * stepX
                let y = Int(safeRect.origin.y) + gridY * stepY
                
                if x <= 0 || y <= 0 || x >= width - 1 || y >= height - 1 {
                    continue
                }
                
                // Calculate gradient at this point using Sobel operator approximation
                
                let rowPtr = baseAddress.advanced(by: y * bytesPerRow)
                let centerPtr = rowPtr.advanced(by: x * 4) // 4 bytes per pixel (BGRA)
                let leftPtr = rowPtr.advanced(by: (x - 1) * 4)
                let rightPtr = rowPtr.advanced(by: (x + 1) * 4)
                let topPtr = baseAddress.advanced(by: (y - 1) * bytesPerRow + x * 4)
                let bottomPtr = baseAddress.advanced(by: (y + 1) * bytesPerRow + x * 4)
                
                let center = getGrayscale(ptr: centerPtr)
                let left = getGrayscale(ptr: leftPtr)
                let right = getGrayscale(ptr: rightPtr)
                let top = getGrayscale(ptr: topPtr)
                let bottom = getGrayscale(ptr: bottomPtr)
                
                // Calculate horizontal and vertical gradients
                let gradientX = abs(right - left)
                let gradientY = abs(bottom - top)
                
                let gradient = sqrt(gradientX * gradientX + gradientY * gradientY)
                gradientSum += gradient
                sampleCount += 1
            }
        }
        
        guard sampleCount > 0 else {
            return 0.5
        }
        
        // Calculate average gradient
        let averageGradient = gradientSum / Float(sampleCount)
        
        // Normalize to 0-1 range
        // Higher gradient means sharper image
        let normalizedGradient = min(1.0, averageGradient / 100.0)
        
        return normalizedGradient
    }
    
    private static func getGrayscale(ptr: UnsafeRawPointer) -> Float {
        let b = Float(ptr.load(fromByteOffset: 0, as: UInt8.self))
        let g = Float(ptr.load(fromByteOffset: 1, as: UInt8.self))
        let r = Float(ptr.load(fromByteOffset: 2, as: UInt8.self))
        
        // Convert to grayscale using standard luminance formula
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    }
    
    /// Evaluate the quality of a frame using face landmarks instead of bounding box
    /// - Parameters:
    ///   - pixelBuffer: The frame pixel buffer
    ///   - imageSize: The size of the image
    /// - Returns: Quality score result
    private static let sharpnessValidationThreshold: Float = 0.07
    
    static func evaluateFrameQualityWithLandmarks(
        pixelBuffer: CVPixelBuffer,
        landmarks: [NormalizedLandmark]?,
        imageSize: CGSize
    ) -> QualityScore {
        print("Evaluating quality with landmarks: \(landmarks?.count ?? 0) points")
        
        // 1. Calculate face size score
        let faceSizeScore = FaceLandmarkQualityCalculator.calculateFaceSizeScore(
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
        let facePositionScore = FaceLandmarkQualityCalculator.calculateFacePositionScore(
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
        let brightnessScore = FaceLandmarkQualityCalculator.calculateBrightnessScore(
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
        let sharpnessScore = FaceLandmarkQualityCalculator.calculateSharpnessScore(
            landmarks: landmarks,
            pixelBuffer: pixelBuffer
        )
        
        print("Sharpness from Landmarks: \(sharpnessScore)")
        

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
