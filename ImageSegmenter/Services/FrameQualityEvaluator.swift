import UIKit
import CoreImage
import MediaPipeTasksVision

/// Shared utilities for evaluating frame quality metrics
struct FrameQualityEvaluator {

    // MARK: - Bounding box based calculations

    /// Calculate face size score using bounding box
    static func faceSizeScore(faceBoundingBox: CGRect, imageSize: CGSize) -> Float {
        let imageArea = imageSize.width * imageSize.height
        let faceArea = faceBoundingBox.width * faceBoundingBox.height
        let ratio = Float(faceArea / imageArea)

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

    /// Calculate face position score using bounding box
    static func facePositionScore(faceBoundingBox: CGRect, imageSize: CGSize) -> Float {
        let faceCenterX = faceBoundingBox.midX
        let faceCenterY = faceBoundingBox.midY

        let imageCenterX = imageSize.width / 2
        let imageCenterY = imageSize.height / 2

        let distanceX = abs(faceCenterX - imageCenterX) / (imageSize.width / 2)
        let distanceY = abs(faceCenterY - imageCenterY) / (imageSize.height / 2)

        let xScore = Float(1.0 - distanceX)
        let yScore = Float(1.0 - distanceY)

        return (xScore * 0.6) + (yScore * 0.4)
    }

    /// Calculate brightness score within face bounding box
    static func brightnessScore(pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect) -> Float {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let faceRect = CGRect(
            x: faceBoundingBox.origin.x * CGFloat(width),
            y: faceBoundingBox.origin.y * CGFloat(height),
            width: faceBoundingBox.width * CGFloat(width),
            height: faceBoundingBox.height * CGFloat(height)
        )

        let croppedImage = ciImage.cropped(to: faceRect)

        let filter = CIFilter(name: "CIAreaAverage")!
        filter.setValue(croppedImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: CGRect(x: 0, y: 0, width: 1, height: 1)), forKey: "inputExtent")

        guard let outputImage = filter.outputImage else {
            return 0.5
        }

        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let r = Float(bitmap[0]) / 255.0
        let g = Float(bitmap[1]) / 255.0
        let b = Float(bitmap[2]) / 255.0
        let averageBrightness = (0.299 * r + 0.587 * g + 0.114 * b)

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

    /// Calculate sharpness/blur score within face bounding box (higher is sharper)
    static func sharpnessScore(pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0.5
        }

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

        for gridY in 0..<gridSize {
            for gridX in 0..<gridSize {
                let x = Int(safeRect.origin.x) + gridX * stepX
                let y = Int(safeRect.origin.y) + gridY * stepY

                if x <= 0 || y <= 0 || x >= width - 1 || y >= height - 1 {
                    continue
                }

                let rowPtr = baseAddress.advanced(by: y * bytesPerRow)
                let centerPtr = rowPtr.advanced(by: x * 4)
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

    // MARK: - Landmark based calculations

    static func faceSizeScore(landmarks: [NormalizedLandmark]?, imageSize: CGSize) -> Float {
        guard let landmarks = landmarks, !landmarks.isEmpty else {
            return 0.0
        }

        let faceOvalIndices = MediaPipeFaceMesh.faceOval.flatMap { [$0.0, $0.1] }
        let faceOvalPoints = faceOvalIndices.compactMap { index -> CGPoint? in
            guard index < landmarks.count else { return nil }
            return CGPoint(x: CGFloat(landmarks[index].x), y: CGFloat(landmarks[index].y))
        }

        let faceArea = calculatePolygonArea(points: faceOvalPoints)
        let imageArea: CGFloat = 1.0
        let ratio = Float(faceArea / imageArea)

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

    static func facePositionScore(landmarks: [NormalizedLandmark]?, imageSize: CGSize) -> Float {
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

        let distanceX = abs(faceCenterX - 0.5) * 2
        let distanceY = abs(faceCenterY - 0.5) * 2

        let xScore = Float(1.0 - distanceX)
        let yScore = Float(1.0 - distanceY)

        return (xScore * 0.6) + (yScore * 0.4)
    }

    static func brightnessScore(landmarks: [NormalizedLandmark]?, pixelBuffer: CVPixelBuffer) -> Float {
        guard let landmarks = landmarks, !landmarks.isEmpty else {
            return 0.0
        }

        let keyPointIndices = [50, 330, 151]

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
              CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
            return 0.5
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var totalBrightness: Float = 0
        var sampleCount = 0

        for index in keyPointIndices {
            guard index < landmarks.count else { continue }

            let pointX = Int(CGFloat(landmarks[index].x) * CGFloat(width))
            let pointY = Int(CGFloat(landmarks[index].y) * CGFloat(height))

            guard pointX >= 0, pointY >= 0, pointX < width, pointY < height else { continue }

            let rowPtr = baseAddress.advanced(by: pointY * bytesPerRow)
            let pixelPtr = rowPtr.advanced(by: pointX * 4)

            let blue = Float(pixelPtr.load(fromByteOffset: 0, as: UInt8.self))
            let green = Float(pixelPtr.load(fromByteOffset: 1, as: UInt8.self))
            let red = Float(pixelPtr.load(fromByteOffset: 2, as: UInt8.self))

            let pointBrightness = (0.299 * red + 0.587 * green + 0.114 * blue) / 255.0
            totalBrightness += pointBrightness
            sampleCount += 1
        }

        guard sampleCount > 0 else { return 0.5 }

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

    static func sharpnessScore(landmarks: [NormalizedLandmark]?, pixelBuffer: CVPixelBuffer) -> Float {
        guard let landmarks = landmarks, !landmarks.isEmpty else {
            return 0.0
        }

        let keyPointIndices = [381, 153, 154, 464, 467, 474]

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

        for index in keyPointIndices {
            guard index < landmarks.count else { continue }

            let pointX = Int(CGFloat(landmarks[index].x) * CGFloat(width))
            let pointY = Int(CGFloat(landmarks[index].y) * CGFloat(height))

            guard pointX > 1, pointY > 1, pointX < width - 2, pointY < height - 2 else { continue }

            for offsetY in -1...1 {
                for offsetX in -1...1 {
                    let sampleX = pointX + offsetX
                    let sampleY = pointY + offsetY

                    let rowPtr = baseAddress.advanced(by: sampleY * bytesPerRow)
                    let centerPtr = rowPtr.advanced(by: sampleX * 4)
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

        guard sampleCount > 0 else { return 0.5 }

        let averageGradient = gradientSum / Float(sampleCount)
        let normalizedGradient = min(1.0, averageGradient / 0.1)
        return normalizedGradient
    }

    // MARK: - UIImage based calculations

    static func brightnessScore(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }

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

        context.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))

        guard let pixelData = context.data else { return 0.5 }

        let data = pixelData.bindMemory(
            to: UInt8.self,
            capacity: Int(thumbnailSize.width * thumbnailSize.height * 4)
        )

        var totalBrightness: Float = 0
        let pixelCount = Int(thumbnailSize.width * thumbnailSize.height)

        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            let r = Float(data[i])
            let g = Float(data[i + 1])
            let b = Float(data[i + 2])
            let luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
            totalBrightness += luminance
        }

        let averageBrightness = totalBrightness / Float(pixelCount)
        let minBrightness: Float = 0.2
        let maxBrightness: Float = 0.9
        let idealBrightness = (minBrightness + maxBrightness) / 2

        if averageBrightness < minBrightness {
            return averageBrightness / minBrightness
        } else if averageBrightness > maxBrightness {
            return 1.0 - ((averageBrightness - maxBrightness) / (1.0 - maxBrightness))
        } else if averageBrightness < idealBrightness {
            return 0.5 + 0.5 * (averageBrightness - minBrightness) / (idealBrightness - minBrightness)
        } else {
            return 1.0 - 0.5 * (averageBrightness - idealBrightness) / (maxBrightness - idealBrightness)
        }
    }

    static func blurScore(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }

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

        _ = context.makeImage()
        guard let pixelData = context.data else { return 0.5 }

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

        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                var pixelValue: Float = 0
                for ky in 0..<3 {
                    for kx in 0..<3 {
                        let pixel = Float(data[(y + ky - 1) * bytesPerRow + (x + kx - 1)])
                        pixelValue += pixel * laplacianKernel[ky * 3 + kx]
                    }
                }
                sumLaplacian += abs(pixelValue)
            }
        }

        let averageLaplacian = sumLaplacian / Float((width - 2) * (height - 2))
        let normalizedBlurScore = max(0.0, min(1.0, 1.0 - (averageLaplacian / Float(20.0))))
        return normalizedBlurScore
    }

    // MARK: - Helpers

    private static func calculatePolygonArea(points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }

        var area: CGFloat = 0
        for idx in 0..<points.count {
            let nextIdx = (idx + 1) % points.count
            area += points[idx].x * points[nextIdx].y
            area -= points[nextIdx].x * points[idx].y
        }
        return abs(area) / 2.0
    }

    private static func getGrayscale(ptr: UnsafeRawPointer) -> Float {
        let b = Float(ptr.load(fromByteOffset: 0, as: UInt8.self))
        let g = Float(ptr.load(fromByteOffset: 1, as: UInt8.self))
        let r = Float(ptr.load(fromByteOffset: 2, as: UInt8.self))
        return (0.299 * r + 0.587 * g + 0.114 * b)
    }
}

