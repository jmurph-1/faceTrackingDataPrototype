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
        
        print("Face area ratio: \(ratio)")
        
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
            return 0.0
        }
        
        let keyPointIndices = [10, 152, 234, 454, 152]
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var totalBrightness: Float = 0
        var sampleCount = 0
        
        for index in keyPointIndices {
            guard index < landmarks.count else { continue }
            
            let x = Int(CGFloat(landmarks[index].x) * CGFloat(width))
            let y = Int(CGFloat(landmarks[index].y) * CGFloat(height))
            
            let sampleRect = CGRect(x: max(0, x - 5), y: max(0, y - 5), width: 10, height: 10)
            
            let croppedImage = ciImage.cropped(to: sampleRect)
            
            let filter = CIFilter(name: "CIAreaAverage")!
            filter.setValue(croppedImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: CGRect(x: 0, y: 0, width: 1, height: 1)), forKey: "inputExtent")
            
            guard let outputImage = filter.outputImage else { continue }
            
            let context = CIContext(options: [.workingColorSpace: NSNull()])
            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            
            let r = Float(bitmap[0]) / 255.0
            let g = Float(bitmap[1]) / 255.0
            let b = Float(bitmap[2]) / 255.0
            let pointBrightness = (0.299 * r + 0.587 * g + 0.114 * b)
            
            totalBrightness += pointBrightness
            sampleCount += 1
        }
        
        guard sampleCount > 0 else {
            return 0.5 // Default medium score if we can't calculate
        }
        
        let averageBrightness = totalBrightness / Float(sampleCount)
        
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
            return 0.0
        }
        
        let featureConnections = MediaPipeFaceMesh.leftEye + MediaPipeFaceMesh.rightEye + MediaPipeFaceMesh.lips
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0.5
        }
        
        var gradientSum: Float = 0
        var sampleCount = 0
        
        for connection in featureConnections {
            let startIndex = connection.0
            let endIndex = connection.1
            
            guard startIndex < landmarks.count && endIndex < landmarks.count else {
                continue
            }
            
            let startX = Int(CGFloat(landmarks[startIndex].x) * CGFloat(width))
            let startY = Int(CGFloat(landmarks[startIndex].y) * CGFloat(height))
            let endX = Int(CGFloat(landmarks[endIndex].x) * CGFloat(width))
            let endY = Int(CGFloat(landmarks[endIndex].y) * CGFloat(height))
            
            let samplePoints = 3
            for i in 0...samplePoints {
                let t = Float(i) / Float(samplePoints)
                let x = Int(Float(startX) * (1-t) + Float(endX) * t)
                let y = Int(Float(startY) * (1-t) + Float(endY) * t)
                
                if x <= 0 || y <= 0 || x >= width - 1 || y >= height - 1 {
                    continue
                }
                
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
        
        let averageGradient = gradientSum / Float(sampleCount)
        
        let normalizedGradient = min(1.0, averageGradient / 100.0)
        
        return normalizedGradient
    }
    
    
    private static func calculatePolygonArea(points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        
        var area: CGFloat = 0
        
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }
        
        area = abs(area) / 2.0
        return area
    }
    
    private static func getGrayscale(ptr: UnsafeRawPointer) -> Float {
        let b = Float(ptr.load(fromByteOffset: 0, as: UInt8.self))
        let g = Float(ptr.load(fromByteOffset: 1, as: UInt8.self))
        let r = Float(ptr.load(fromByteOffset: 2, as: UInt8.self))
        
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    }
}
