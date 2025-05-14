import Foundation
import UIKit
import Vision

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
    struct QualityScore {
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
    
    /// Evaluate the quality of a frame for color analysis
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
        
        // 2. Calculate face position score (how centered the face is)
        let facePositionScore = calculateFacePositionScore(faceBoundingBox: faceBoundingBox, imageSize: imageSize)
        
        // 3. Calculate brightness score
        let brightnessScore = calculateBrightnessScore(pixelBuffer: pixelBuffer, faceBoundingBox: faceBoundingBox)
        
        // 4. Calculate sharpness/blur score
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
    
    /// Calculate brightness score
    /// - Parameters:
    ///   - pixelBuffer: Image pixel buffer
    ///   - faceBoundingBox: Face bounding box
    /// - Returns: Score from 0 to 1
    private static func calculateBrightnessScore(pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect) -> Float {
        // Lock the buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        // Get the pixel data
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Create a bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return 0.5 // Default medium score if we can't calculate
        }
        
        // Create a CGImage from the context
        guard let cgImage = context.makeImage() else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return 0.5
        }
        
        // Crop to just the face area
        let faceRect = CGRect(
            x: faceBoundingBox.origin.x * CGFloat(width),
            y: faceBoundingBox.origin.y * CGFloat(height),
            width: faceBoundingBox.width * CGFloat(width),
            height: faceBoundingBox.height * CGFloat(height)
        )
        
        guard let croppedImage = cgImage.cropping(to: faceRect) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return 0.5
        }
        
        // Calculate average brightness
        var sum = 0.0
        var count = 0
        
        let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 4)
        defer { buffer.deallocate() }
        
        for y in 0..<croppedImage.height {
            for x in 0..<croppedImage.width {
                if let colorBuffer = context.data?.assumingMemoryBound(to: UInt8.self) {
                    let offset = (Int(faceRect.origin.y) + y) * bytesPerRow + (Int(faceRect.origin.x) + x) * 4
                    let r = Float(colorBuffer[offset])
                    let g = Float(colorBuffer[offset + 1])
                    let b = Float(colorBuffer[offset + 2])
                    
                    // Calculate luminance
                    let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                    sum += Double(luminance)
                    count += 1
                }
            }
        }
        
        // Unlock the buffer
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        // Calculate average brightness
        let averageBrightness = Float(sum / Double(count))
        
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
    
    /// Calculate sharpness/blur score
    /// - Parameters:
    ///   - pixelBuffer: Image pixel buffer
    ///   - faceBoundingBox: Face bounding box
    /// - Returns: Score from 0 to 1 (higher is sharper)
    private static func calculateSharpnessScore(pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect) -> Float {
        // Convert CVPixelBuffer to CIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Create a Laplacian filter for edge detection (to detect blur)
        let filter = CIFilter(name: "CIConvolution3X3")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        // Laplacian kernel
        let weights = CIVector(values: [
            -1, -1, -1,
            -1,  8, -1,
            -1, -1, -1
        ], count: 9)
        filter.setValue(weights, forKey: "inputWeights")
        
        // Get the output image
        guard let outputImage = filter.outputImage else {
            return 0.5
        }
        
        // Create a CIContext
        let context = CIContext()
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return 0.5
        }
        
        // Convert to UIImage
        let uiImage = UIImage(cgImage: cgImage)
        
        // Calculate variance as a measure of sharpness
        var sum: Float = 0
        var sumSquared: Float = 0
        var pixelCount: Int = 0
        
        // Get pixel data
        if let cfData = uiImage.cgImage?.dataProvider?.data,
           let data = CFDataGetBytePtr(cfData) {
            let length = CFDataGetLength(cfData)
            let bytesPerPixel = length / (uiImage.cgImage?.width ?? 1) / (uiImage.cgImage?.height ?? 1)
            
            for i in stride(from: 0, to: length, by: bytesPerPixel) {
                let r = Float(data[i])
                let g = Float(data[i + 1])
                let b = Float(data[i + 2])
                
                // Calculate intensity
                let intensity = (r + g + b) / 3.0
                
                sum += intensity
                sumSquared += intensity * intensity
                pixelCount += 1
            }
        }
        
        // Calculate variance
        let mean = sum / Float(pixelCount)
        let variance = (sumSquared / Float(pixelCount)) - (mean * mean)
        
        // Normalize variance to 0-1 range
        // Higher variance means more edges = sharper image
        let normalizedVariance = min(1.0, variance / 5000.0)
        
        return normalizedVariance
    }
} 