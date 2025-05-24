import UIKit
import MediaPipeTasksVision

class FaceLandmarkQualityCalculator {

    static func calculateFaceSizeScore(landmarks: [NormalizedLandmark]?, imageSize: CGSize) -> Float {
        guard let landmarks = landmarks, !landmarks.isEmpty else {
            return 0.0
        }

        let faceOvalIndices = MediaPipeFaceMesh.faceOval.flatMap { [$0.0, $0.1] }
        let faceOvalPoints = faceOvalIndices.compactMap { index -> CGPoint? in
            guard index < landmarks.count else { return nil }
            return CGPoint(x: CGFloat(landmarks[index].x), y: CGFloat(landmarks[index].y))
        }

        let faceArea = calculatePolygonArea(points: faceOvalPoints)

        let imageArea = 1.0 // Normalized area (1.0 x 1.0)
        let ratio = Float(faceArea / imageArea)

        // print("Face area ratio: \(ratio)")

        if ratio < 0.05 {
            return max(0, ratio / 0.05)
        } else if ratio > 0.6 {
            return max(0, Float(1.0 - ((ratio - 0.6) / 0.4)))
        } else if ratio > 0.35 {
            return Float(1.0 - ((ratio - 0.35) / (0.6 - 0.35)) * 0.2)
        } else if ratio < 0.15 {
            return Float(0.8 + (ratio - 0.05) / (0.15 - 0.05) * 0.2)
        } else {
            return 1.0
        }
    }

    static func calculateFacePositionScore(landmarks: [NormalizedLandmark]?, imageSize: CGSize) -> Float {
        guard let landmarks = landmarks, !landmarks.isEmpty else {
            return 0.0
        }

        var faceCenterX: CGFloat = 0
        var faceCenterY: CGFloat = 0

        if landmarks.count > 4 {
            faceCenterX = CGFloat(landmarks[4].x)
            faceCenterY = CGFloat(landmarks[4].y)
        } else {
            for landmark in landmarks {
                faceCenterX += CGFloat(landmark.x)
                faceCenterY += CGFloat(landmark.y)
            }
            faceCenterX /= CGFloat(landmarks.count)
            faceCenterY /= CGFloat(landmarks.count)
        }

        let distanceX = abs(faceCenterX - 0.5) * 2 // Normalized to 0-1
        let distanceY = abs(faceCenterY - 0.5) * 2 // Normalized to 0-1

        let xScore = Float(1.0 - distanceX)
        let yScore = Float(1.0 - distanceY)

        return (xScore * 0.6) + (yScore * 0.4)
    }

    static func calculateBrightnessScore(landmarks: [NormalizedLandmark]?, pixelBuffer: CVPixelBuffer) -> Float {
        guard let landmarks = landmarks, !landmarks.isEmpty else {
            print("No landmarks available for brightness calculation")
            return 0.0
        }

        // Key facial points to sample brightness (forehead, cheeks, nose, chin)
        // Use safer indices well within the landmark count
        let keyPointIndices = [50, 330, 151]
        // print("Calculating brightness using landmarks: \(keyPointIndices)")

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        // print("Pixel buffer dimensions: \(width)x\(height)")

        // Direct pixel buffer sampling instead of CIFilter
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
              CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
            print("Invalid pixel buffer format for brightness calculation")
            return 0.5 // Default medium score
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var totalBrightness: Float = 0
        var sampleCount = 0

        // Sample brightness at each key point
        for index in keyPointIndices {
            guard index < landmarks.count else {
                print("Landmark index \(index) out of bounds")
                continue
            }

            let pointX = Int(CGFloat(landmarks[index].x) * CGFloat(width))
            let pointY = Int(CGFloat(landmarks[index].y) * CGFloat(height))

            // Skip if point is outside valid image bounds
            guard pointX >= 0, pointY >= 0, pointX < width, pointY < height else {
                print("Sample point (\(pointX),\(pointY)) outside image bounds")
                continue
            }

            // Sample a single pixel instead of an area
            let rowPtr = baseAddress.advanced(by: pointY * bytesPerRow)
            let pixelPtr = rowPtr.advanced(by: pointX * 4) // 4 bytes per pixel (BGRA)

            let blueValue = Float(pixelPtr.load(fromByteOffset: 0, as: UInt8.self))
            let greenValue = Float(pixelPtr.load(fromByteOffset: 1, as: UInt8.self))
            let redValue = Float(pixelPtr.load(fromByteOffset: 2, as: UInt8.self))

            // Calculate luminance
            let pointBrightness = (0.299 * redValue + 0.587 * greenValue + 0.114 * blueValue) / 255.0
            totalBrightness += pointBrightness
            sampleCount += 1

            // print("Sample at point \(index) (\(pointX),\(pointY)): \(pointBrightness)")
        }

        guard sampleCount > 0 else {
            print("No valid samples for brightness calculation")
            return 0.5 // Default medium score
        }

        let averageBrightness = totalBrightness / Float(sampleCount)
        // print("Average brightness: \(averageBrightness)")

        // Map to quality score using same thresholds
        if averageBrightness < 0.2 {
            return averageBrightness / 0.2
        } else if averageBrightness > 0.8 {
            return Float(1.0 - ((averageBrightness - 0.8) / 0.2))
        } else if averageBrightness < 0.4 {
            return Float(0.7 + ((averageBrightness - 0.2) / (0.4 - 0.2)) * 0.3)
        } else if averageBrightness > 0.7 {
            return Float(0.7 + ((0.8 - averageBrightness) / (0.8 - 0.7)) * 0.3)
        } else {
            return 1.0
        }
    }

    static func calculateSharpnessScore(landmarks: [NormalizedLandmark]?, pixelBuffer: CVPixelBuffer) -> Float {
        guard let landmarks = landmarks, !landmarks.isEmpty else {
            print("No landmarks available for sharpness calculation")
            return 0.0
        }

        // print("Calculating sharpness with \(landmarks.count) landmarks")

        // Sample points across the face for sharpness calculation
        // Use a simpler approach with key facial points rather than connections
        let keyPointIndices = [381, 153, 154, 464, 467, 474]

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("Invalid pixel buffer base address")
            return 0.5
        }

        var gradientSum: Float = 0
        var sampleCount = 0

        // Sample around each key point
        for index in keyPointIndices {
            guard index < landmarks.count else {
                print("Landmark index \(index) out of bounds")
                continue
            }

            let pointX = Int(CGFloat(landmarks[index].x) * CGFloat(width))
            let pointY = Int(CGFloat(landmarks[index].y) * CGFloat(height))

            // Skip if point is outside valid image bounds or too close to edge
            guard pointX > 1, pointY > 1, pointX < width - 2, pointY < height - 2 else {
                print("Sample point (\(pointX),\(pointY)) too close to image edge")
                continue
            }

            // Sample a 3x3 grid around the point
            for offsetY in -1...1 {
                for offsetX in -1...1 {
                    let sampleX = pointX + offsetX
                    let sampleY = pointY + offsetY

                    let rowPtr = baseAddress.advanced(by: sampleY * bytesPerRow)
                    let centerPtr = rowPtr.advanced(by: sampleX * 4) // 4 bytes per pixel (BGRA)
                    let leftPtr = rowPtr.advanced(by: (sampleX - 1) * 4)
                    let rightPtr = rowPtr.advanced(by: (sampleX + 1) * 4)
                    let topPtr = baseAddress.advanced(by: (sampleY - 1) * bytesPerRow + sampleX * 4)
                    let bottomPtr = baseAddress.advanced(by: (sampleY + 1) * bytesPerRow + sampleX * 4)

                    let center = getGrayscale(ptr: centerPtr)
                    let left = getGrayscale(ptr: leftPtr)
                    let right = getGrayscale(ptr: rightPtr)
                    let top = getGrayscale(ptr: topPtr)
                    let bottom = getGrayscale(ptr: bottomPtr)

                    let gradientX = abs(right - left)
                    let gradientY = abs(bottom - top)

                    let gradient = sqrt(gradientX * gradientX + gradientY * gradientY)
                    gradientSum += gradient
                    sampleCount += 1
                }
            }
        }

        guard sampleCount > 0 else {
            print("No valid samples for sharpness calculation")
            return 0.5
        }

        let averageGradient = gradientSum / Float(sampleCount)
        // print("Average gradient (sharpness): \(averageGradient)")

        // Normalize to 0-1 range
        let normalizedGradient = min(1.0, averageGradient / 0.1)
        // print("Normalized sharpness score: \(normalizedGradient)")

        return normalizedGradient
    }

    private static func calculatePolygonArea(points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }

        var area: CGFloat = 0

        for idx in 0..<points.count {
            let nextIdx = (idx + 1) % points.count
            area += points[idx].x * points[nextIdx].y
            area -= points[nextIdx].x * points[idx].y
        }

        area = abs(area) / 2.0
        return area
    }

    private static func getGrayscale(ptr: UnsafeRawPointer) -> Float {
        let blueValue = Float(ptr.load(fromByteOffset: 0, as: UInt8.self))
        let greenValue = Float(ptr.load(fromByteOffset: 1, as: UInt8.self))
        let redValue = Float(ptr.load(fromByteOffset: 2, as: UInt8.self))

        return (0.299 * redValue + 0.587 * greenValue + 0.114 * blueValue) / 255.0
    }
}
