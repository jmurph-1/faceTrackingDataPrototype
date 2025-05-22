import UIKit
import Metal
import MediaPipeTasksVision // For NormalizedLandmark
import CoreGraphics // For CGPoint, CGFloat

// Assuming LoggingService and BufferPoolManager are globally accessible singletons as in the original file.
// Assuming SegmentationClass will be accessible from MultiClassSegmentedImageRenderer or a shared file.

class ColorExtractor {

    static var relevantLandmarkIndices: Set<Int> {
        let leftCheekIndices = [117, 118, 101, 205, 187, 123, 50]
        let rightCheekIndices = [329, 348, 347, 346, 280, 425, 266, 330]
        let foreheadIndices = [9, 108, 67, 109, 10, 338, 297, 299, 336, 151, 337]
        return Set(leftCheekIndices + rightCheekIndices + foreheadIndices)
    }

    struct ColorInfo {
        var skinColor: UIColor = .clear
        var hairColor: UIColor = .clear
        var skinColorHSV: (h: CGFloat, s: CGFloat, v: CGFloat) = (0, 0, 0)
        var hairColorHSV: (h: CGFloat, s: CGFloat, v: CGFloat) = (0, 0, 0)
    }

    public var lastColorInfo = ColorInfo()
    public let smoothingFactor: Float
    public var lastFaceLandmarks: [NormalizedLandmark]?

    public let metalDevice: MTLDevice
    public let commandQueue: MTLCommandQueue?

    init(metalDevice: MTLDevice, commandQueue: MTLCommandQueue?, smoothingFactor: Float = 0.3) {
        self.metalDevice = metalDevice
        self.commandQueue = commandQueue
        self.smoothingFactor = smoothingFactor
    }

    func updateFaceLandmarks(_ landmarks: [NormalizedLandmark]?) {
        self.lastFaceLandmarks = landmarks
    }

    func getCurrentColorInfo() -> ColorInfo {
        return lastColorInfo
    }

    // MARK: - Original Optimization Method (Commented Out)
    
    /*
    // OLD IMPLEMENTATION - can uncomment to revert
    func extractColorsOptimized(
        from texture: MTLTexture,
        segmentMask: UnsafePointer<UInt8>,
        width: Int,
        height: Int
    ) {
        let processingWidth = texture.width
        let processingHeight = texture.height

        guard texture.width == width && texture.height == height else {
            LoggingService.warning("ColorExtractor: Texture dimensions (\(texture.width)x\(texture.height)) do not match mask dimensions (\(width)x\(height)). Color extraction might be inaccurate.")
            return
        }

        let bytesPerRow = processingWidth * 4
        let bufferSize = processingHeight * bytesPerRow

        guard let textureBuffer = BufferPoolManager.shared.getBuffer(
            length: bufferSize,
            options: .storageModeShared
        ) else {
            LoggingService.error("ColorExtractor: Failed to get buffer from pool")
            return
        }

        guard let commandQueue = self.commandQueue, let cmdBuffer = commandQueue.makeCommandBuffer() else {
            LoggingService.error("ColorExtractor: Failed to create command buffer.")
            BufferPoolManager.shared.recycleBuffer(textureBuffer) // Recycle if command buffer fails
            return
        }
        
        let blitEncoder = cmdBuffer.makeBlitCommandEncoder()
        let sourceSize = MTLSizeMake(processingWidth, processingHeight, 1)
        
        blitEncoder?.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: sourceSize,
            to: textureBuffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: bufferSize
        )
        blitEncoder?.endEncoding()

        cmdBuffer.addCompletedHandler { [weak self] (_: MTLCommandBuffer) in
            guard let self = self else {
                BufferPoolManager.shared.recycleBuffer(textureBuffer)
                return
            }

            let pixelData = textureBuffer.contents().bindMemory(to: UInt8.self, capacity: bufferSize)
            var skinPixels = [(r: Float, g: Float, b: Float)]()
            skinPixels.reserveCapacity(processingWidth * processingHeight / 4)
            var hairPixels = [(r: Float, g: Float, b: Float)]()
            hairPixels.reserveCapacity(processingWidth * processingHeight / 4)

            let strideX = 1
            let strideY = 1
            let chunkSize = 16
            
            var cheekPoints: [CGPoint] = []
            var foreheadPoints: [CGPoint] = []
            
            if let landmarks = self.lastFaceLandmarks, !landmarks.isEmpty {
                print("Extracting colors with landmarks")
                let relevantIndices = ColorExtractor.relevantLandmarkIndices
                let leftCheekIndices = [117, 118, 101, 205, 187, 123, 50]
                let rightCheekIndices = [329, 348, 347, 346, 280, 425, 266, 330]
                let foreheadIndices = [9, 108, 67, 109, 10, 338, 297, 299, 336, 151, 337]
                
                for index in leftCheekIndices + rightCheekIndices {
                    if index < landmarks.count {
                        cheekPoints.append(CGPoint(x: CGFloat(landmarks[index].x), y: CGFloat(landmarks[index].y)))
                    }
                }
                for index in foreheadIndices {
                    if index < landmarks.count {
                        foreheadPoints.append(CGPoint(x: CGFloat(landmarks[index].x), y: CGFloat(landmarks[index].y)))
                    }
                }
            }
            
            for y in 0..<processingHeight {
                var x = 0
                while x < processingWidth {
                    let remainingPixels = processingWidth - x
                    let pixelsToProcess = min(chunkSize, remainingPixels)
                    for i in 0..<pixelsToProcess {
                        let currentPixelX = x + i
                        let currentPixelY = y
                        let segY = min(currentPixelY * strideY, height - 1)
                        let segX = min(currentPixelX * strideX, width - 1)
                        let segIndex = segY * width + segX
                        let segmentClass = segmentMask[segIndex]
                        let pixelOffset = (currentPixelY * processingWidth + currentPixelX) * 4
                        
                        let b = Float(pixelData[pixelOffset])
                        let g = Float(pixelData[pixelOffset + 1])
                        let r = Float(pixelData[pixelOffset + 2])
                        
                        if segmentClass == MultiClassSegmentedImageRenderer.SegmentationClass.hair.rawValue {
                            hairPixels.append((r: r, g: g, b: b))
                        } else if segmentClass == MultiClassSegmentedImageRenderer.SegmentationClass.skin.rawValue && (cheekPoints.isEmpty && foreheadPoints.isEmpty) {
                            skinPixels.append((r: r, g: g, b: b))
                        }
                    }
                    x += pixelsToProcess
                }
            }
            
            if !cheekPoints.isEmpty || !foreheadPoints.isEmpty {
                let allSamplingPoints = cheekPoints + foreheadPoints
                for point in allSamplingPoints {
                    let sampleX = Int(point.x * CGFloat(processingWidth))
                    let sampleY = Int(point.y * CGFloat(processingHeight))
                    if sampleX >= 0 && sampleX < processingWidth && sampleY >= 0 && sampleY < processingHeight {
                        let pixelOffset = (sampleY * processingWidth + sampleX) * 4
                        if pixelOffset + 2 < bufferSize {
                            let b = Float(pixelData[pixelOffset])
                            let g = Float(pixelData[pixelOffset + 1])
                            let r = Float(pixelData[pixelOffset + 2])
                            skinPixels.append((r: r, g: g, b: b))
                            skinPixels.append((r: r, g: g, b: b))
                        }
                    }
                }
            }

            var newColorInfo = ColorInfo()
            if !skinPixels.isEmpty {
                let skinPixelCount = skinPixels.count
                let skinTotals = skinPixels.reduce((r: 0.0, g: 0.0, b: 0.0)) { ($0.r + $1.r, $0.g + $1.g, $0.b + $1.b) }
                let avgR = skinTotals.r / Float(skinPixelCount)
                let avgG = skinTotals.g / Float(skinPixelCount)
                let avgB = skinTotals.b / Float(skinPixelCount)
                let calculatedSkinColor = UIColor(red: CGFloat(avgR / 255.0), green: CGFloat(avgG / 255.0), blue: CGFloat(avgB / 255.0), alpha: 1.0)
                
                if self.lastColorInfo.skinColor != .clear {
                    newColorInfo.skinColor = self.blendColors(newColor: calculatedSkinColor, oldColor: self.lastColorInfo.skinColor, factor: self.smoothingFactor)
                } else {
                    newColorInfo.skinColor = calculatedSkinColor
                }
                newColorInfo.skinColor.getHue(&newColorInfo.skinColorHSV.h, saturation: &newColorInfo.skinColorHSV.s, brightness: &newColorInfo.skinColorHSV.v, alpha: nil)
            } else {
                newColorInfo.skinColor = self.lastColorInfo.skinColor
                newColorInfo.skinColorHSV = self.lastColorInfo.skinColorHSV
            }

            if !hairPixels.isEmpty {
                let hairPixelCount = hairPixels.count
                let hairTotals = hairPixels.reduce((r: 0.0, g: 0.0, b: 0.0)) { ($0.r + $1.r, $0.g + $1.g, $0.b + $1.b) }
                let avgR = hairTotals.r / Float(hairPixelCount)
                let avgG = hairTotals.g / Float(hairPixelCount)
                let avgB = hairTotals.b / Float(hairPixelCount)
                let calculatedHairColor = UIColor(red: CGFloat(avgR / 255.0), green: CGFloat(avgG / 255.0), blue: CGFloat(avgB / 255.0), alpha: 1.0)

                if self.lastColorInfo.hairColor != .clear {
                    newColorInfo.hairColor = self.blendColors(newColor: calculatedHairColor, oldColor: self.lastColorInfo.hairColor, factor: self.smoothingFactor)
                } else {
                    newColorInfo.hairColor = calculatedHairColor
                }
                newColorInfo.hairColor.getHue(&newColorInfo.hairColorHSV.h, saturation: &newColorInfo.hairColorHSV.s, brightness: &newColorInfo.hairColorHSV.v, alpha: nil)
            } else {
                newColorInfo.hairColor = self.lastColorInfo.hairColor
                newColorInfo.hairColorHSV = self.lastColorInfo.hairColorHSV
            }
            
            if !skinPixels.isEmpty || !hairPixels.isEmpty {
                self.lastColorInfo = newColorInfo
            }
            BufferPoolManager.shared.recycleBuffer(textureBuffer)
        }
        cmdBuffer.commit()
    }
    */

    // MARK: - New Implementation Delegation
    func extractColorsOptimized(
        from texture: MTLTexture,
        segmentMask: UnsafePointer<UInt8>,
        width: Int,
        height: Int
    ) {
        // Delegate to new high accuracy implementation
        extractColorsHighAccuracy(
            from: texture,
            segmentMask: segmentMask,
            width: width,
            height: height
        )
    }

    public func blendColors(newColor: UIColor, oldColor: UIColor, factor: Float) -> UIColor {
        let factorCG = CGFloat(factor)
        var (nR, nG, nB, nA): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (oR, oG, oB, oA): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        newColor.getRed(&nR, green: &nG, blue: &nB, alpha: &nA)
        oldColor.getRed(&oR, green: &oG, blue: &oB, alpha: &oA)
        let r = oR * (1 - factorCG) + nR * factorCG
        let g = oG * (1 - factorCG) + nG * factorCG
        let b = oB * (1 - factorCG) + nB * factorCG
        let a = oA * (1 - factorCG) + nA * factorCG
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
