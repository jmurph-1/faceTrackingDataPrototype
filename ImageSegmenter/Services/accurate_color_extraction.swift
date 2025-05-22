import UIKit
import Metal
import MediaPipeTasksVision
import CoreGraphics

extension ColorExtractor {
    
    // MARK: - Most Accurate Color Extraction
    
    func extractColorsHighAccuracy(
        from texture: MTLTexture,
        segmentMask: UnsafePointer<UInt8>,
        width: Int,
        height: Int
    ) {
        let processingWidth = texture.width
        let processingHeight = texture.height
        
        guard texture.width == width && texture.height == height else {
            LoggingService.warning("ColorExtractor: Texture dimensions mismatch")
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
        
        guard let commandQueue = self.commandQueue, 
              let cmdBuffer = commandQueue.makeCommandBuffer() else {
            LoggingService.error("ColorExtractor: Failed to create command buffer.")
            BufferPoolManager.shared.recycleBuffer(textureBuffer)
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
            let colorInfo = self.extractColorsFromFaceRegions(
                pixelData: pixelData,
                segmentMask: segmentMask,
                processingWidth: processingWidth,
                processingHeight: processingHeight,
                maskWidth: width,
                maskHeight: height
            )
            
            self.updateColorInfo(with: colorInfo)
            BufferPoolManager.shared.recycleBuffer(textureBuffer)
        }
        
        cmdBuffer.commit()
    }
    
    // MARK: - High Accuracy Region-Based Extraction
    
    private func extractColorsFromFaceRegions(
        pixelData: UnsafePointer<UInt8>,
        segmentMask: UnsafePointer<UInt8>,
        processingWidth: Int,
        processingHeight: Int,
        maskWidth: Int,
        maskHeight: Int
    ) -> ColorInfo {
        
        guard let landmarks = self.lastFaceLandmarks, !landmarks.isEmpty else {
            return self.lastColorInfo
        }
        
        // Create accurate polygons for each facial region
        let leftCheekPolygon = createOrderedPolygon(
            from: landmarks,
            indices: [117, 118, 101, 36, 205, 187, 123] // Ordered for proper polygon
        )
        
        let rightCheekPolygon = createOrderedPolygon(
            from: landmarks,
            indices: [348, 347, 346, 280, 425, 266, 371, 329] // Ordered for proper polygon
        )
        
        let foreheadPolygon = createOrderedPolygon(
            from: landmarks,
            indices: [10, 338, 297, 299, 337, 9, 108, 69, 67, 109] // Ordered for proper polygon
        )
        
        // Extract colors with high precision
        let skinPixels = extractPixelsFromRegions(
            pixelData: pixelData,
            segmentMask: segmentMask,
            polygons: [leftCheekPolygon, rightCheekPolygon, foreheadPolygon],
            targetSegmentClass: MultiClassSegmentedImageRenderer.SegmentationClass.skin.rawValue,
            processingWidth: processingWidth,
            processingHeight: processingHeight,
            maskWidth: maskWidth,
            maskHeight: maskHeight
        )
        
        let hairPixels = extractPixelsFromSegmentation(
            pixelData: pixelData,
            segmentMask: segmentMask,
            targetSegmentClass: MultiClassSegmentedImageRenderer.SegmentationClass.hair.rawValue,
            processingWidth: processingWidth,
            processingHeight: processingHeight,
            maskWidth: maskWidth,
            maskHeight: maskHeight
        )
        
        return calculateColorInfo(skinPixels: skinPixels, hairPixels: hairPixels)
    }
    
    // MARK: - Ordered Polygon Creation
    
    private func createOrderedPolygon(from landmarks: [NormalizedLandmark], indices: [Int]) -> [CGPoint] {
        var points: [CGPoint] = []
        
        for index in indices {
            if index < landmarks.count {
                let landmark = landmarks[index]
                points.append(CGPoint(x: CGFloat(landmark.x), y: CGFloat(landmark.y)))
            }
        }
        
        // Ensure we have enough points for a valid polygon
        guard points.count >= 3 else { return points }
        
        // Order points to create a proper polygon (counter-clockwise)
        return orderPointsCounterClockwise(points)
    }
    
    private func orderPointsCounterClockwise(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        
        // Find centroid
        let centroidX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let centroidY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        let centroid = CGPoint(x: centroidX, y: centroidY)
        
        // Sort points by angle from centroid
        let sortedPoints = points.sorted { point1, point2 in
            let angle1 = atan2(point1.y - centroid.y, point1.x - centroid.x)
            let angle2 = atan2(point2.y - centroid.y, point2.x - centroid.x)
            return angle1 < angle2
        }
        
        return sortedPoints
    }
    
    // MARK: - High Precision Pixel Extraction
    
    private func extractPixelsFromRegions(
        pixelData: UnsafePointer<UInt8>,
        segmentMask: UnsafePointer<UInt8>,
        polygons: [[CGPoint]],
        targetSegmentClass: UInt8,
        processingWidth: Int,
        processingHeight: Int,
        maskWidth: Int,
        maskHeight: Int
    ) -> [(r: Float, g: Float, b: Float)] {
        
        var pixels: [(r: Float, g: Float, b: Float)] = []
        
        // Use sub-pixel sampling for maximum accuracy
        let subPixelSteps = 3 // Sample 3x3 grid per pixel for better accuracy
        let subPixelOffset = 1.0 / (CGFloat(subPixelSteps * 2))
        
        for polygon in polygons {
            guard polygon.count >= 3 else { continue }
            
            // Get bounding box to optimize search area
            let boundingBox = getBoundingBox(for: polygon)
            let startX = max(0, Int((boundingBox.minX - 0.01) * CGFloat(processingWidth)))
            let endX = min(processingWidth, Int((boundingBox.maxX + 0.01) * CGFloat(processingWidth)))
            let startY = max(0, Int((boundingBox.minY - 0.01) * CGFloat(processingHeight)))
            let endY = min(processingHeight, Int((boundingBox.maxY + 0.01) * CGFloat(processingHeight)))
            
            for y in startY..<endY {
                for x in startX..<endX {
                    var samplesInside = 0
                    
                    // Sub-pixel sampling for higher accuracy
                    for subY in 0..<subPixelSteps {
                        for subX in 0..<subPixelSteps {
                            let sampleX = (CGFloat(x) + subPixelOffset + CGFloat(subX) / CGFloat(subPixelSteps)) / CGFloat(processingWidth)
                            let sampleY = (CGFloat(y) + subPixelOffset + CGFloat(subY) / CGFloat(subPixelSteps)) / CGFloat(processingHeight)
                            let samplePoint = CGPoint(x: sampleX, y: sampleY)
                            
                            if isPointInPolygon(samplePoint, polygon: polygon) {
                                samplesInside += 1
                            }
                        }
                    }
                    
                    // Only include pixel if majority of sub-samples are inside
                    let threshold = (subPixelSteps * subPixelSteps) / 2
                    if samplesInside > threshold {
                        // Check segmentation mask
                        let maskX = min(x * maskWidth / processingWidth, maskWidth - 1)
                        let maskY = min(y * maskHeight / processingHeight, maskHeight - 1)
                        let segIndex = maskY * maskWidth + maskX
                        
                        if segmentMask[segIndex] == targetSegmentClass {
                            let pixelOffset = (y * processingWidth + x) * 4
                            if pixelOffset + 2 < processingWidth * processingHeight * 4 {
                                let b = Float(pixelData[pixelOffset])
                                let g = Float(pixelData[pixelOffset + 1])
                                let r = Float(pixelData[pixelOffset + 2])
                                
                                // Quality filtering - reject very dark or very bright pixels
                                let brightness = (r + g + b) / 3.0
                                if brightness > 20.0 && brightness < 240.0 {
                                    pixels.append((r: r, g: g, b: b))
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return pixels
    }
    
    // MARK: - Robust Point-in-Polygon Test
    
    private func isPointInPolygon(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let xi = polygon[i].x
            let yi = polygon[i].y
            let xj = polygon[j].x
            let yj = polygon[j].y
            
            if ((yi > point.y) != (yj > point.y)) &&
               (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi) {
                inside = !inside
            }
            j = i
        }
        return inside
    }
    
    private func getBoundingBox(for points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        let minX = points.map { $0.x }.min()!
        let maxX = points.map { $0.x }.max()!
        let minY = points.map { $0.y }.min()!
        let maxY = points.map { $0.y }.max()!
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // MARK: - Hair Pixel Extraction (Full Segmentation)
    
    private func extractPixelsFromSegmentation(
        pixelData: UnsafePointer<UInt8>,
        segmentMask: UnsafePointer<UInt8>,
        targetSegmentClass: UInt8,
        processingWidth: Int,
        processingHeight: Int,
        maskWidth: Int,
        maskHeight: Int
    ) -> [(r: Float, g: Float, b: Float)] {
        
        var pixels: [(r: Float, g: Float, b: Float)] = []
        
        for y in 0..<processingHeight {
            for x in 0..<processingWidth {
                let maskX = min(x * maskWidth / processingWidth, maskWidth - 1)
                let maskY = min(y * maskHeight / processingHeight, maskHeight - 1)
                let segIndex = maskY * maskWidth + maskX
                
                if segmentMask[segIndex] == targetSegmentClass {
                    let pixelOffset = (y * processingWidth + x) * 4
                    if pixelOffset + 2 < processingWidth * processingHeight * 4 {
                        let b = Float(pixelData[pixelOffset])
                        let g = Float(pixelData[pixelOffset + 1])
                        let r = Float(pixelData[pixelOffset + 2])
                        
                        // Quality filtering
                        let brightness = (r + g + b) / 3.0
                        if brightness > 5.0 && brightness < 250.0 {
                            pixels.append((r: r, g: g, b: b))
                        }
                    }
                }
            }
        }
        
        return pixels
    }
    
    // MARK: - Advanced Color Calculation
    
    private func calculateColorInfo(
        skinPixels: [(r: Float, g: Float, b: Float)],
        hairPixels: [(r: Float, g: Float, b: Float)]
    ) -> ColorInfo {
        
        var newColorInfo = ColorInfo()
        
        // Advanced skin color calculation with outlier removal
        if !skinPixels.isEmpty {
            let filteredSkinPixels = removeColorOutliers(skinPixels)
            if !filteredSkinPixels.isEmpty {
                let avgColor = calculateWeightedAverage(filteredSkinPixels)
                let calculatedSkinColor = UIColor(
                    red: CGFloat(avgColor.r / 255.0),
                    green: CGFloat(avgColor.g / 255.0),
                    blue: CGFloat(avgColor.b / 255.0),
                    alpha: 1.0
                )
                
                newColorInfo.skinColor = lastColorInfo.skinColor != .clear ?
                    blendColors(newColor: calculatedSkinColor, oldColor: lastColorInfo.skinColor, factor: smoothingFactor) :
                    calculatedSkinColor
                    
                newColorInfo.skinColor.getHue(
                    &newColorInfo.skinColorHSV.h,
                    saturation: &newColorInfo.skinColorHSV.s,
                    brightness: &newColorInfo.skinColorHSV.v,
                    alpha: nil
                )
            } else {
                newColorInfo.skinColor = lastColorInfo.skinColor
                newColorInfo.skinColorHSV = lastColorInfo.skinColorHSV
            }
        } else {
            newColorInfo.skinColor = lastColorInfo.skinColor
            newColorInfo.skinColorHSV = lastColorInfo.skinColorHSV
        }
        
        // Advanced hair color calculation with outlier removal
        if !hairPixels.isEmpty {
            let filteredHairPixels = removeColorOutliers(hairPixels)
            if !filteredHairPixels.isEmpty {
                let avgColor = calculateWeightedAverage(filteredHairPixels)
                let calculatedHairColor = UIColor(
                    red: CGFloat(avgColor.r / 255.0),
                    green: CGFloat(avgColor.g / 255.0),
                    blue: CGFloat(avgColor.b / 255.0),
                    alpha: 1.0
                )
                
                newColorInfo.hairColor = lastColorInfo.hairColor != .clear ?
                    blendColors(newColor: calculatedHairColor, oldColor: lastColorInfo.hairColor, factor: smoothingFactor) :
                    calculatedHairColor
                    
                newColorInfo.hairColor.getHue(
                    &newColorInfo.hairColorHSV.h,
                    saturation: &newColorInfo.hairColorHSV.s,
                    brightness: &newColorInfo.hairColorHSV.v,
                    alpha: nil
                )
            } else {
                newColorInfo.hairColor = lastColorInfo.hairColor
                newColorInfo.hairColorHSV = lastColorInfo.hairColorHSV
            }
        } else {
            newColorInfo.hairColor = lastColorInfo.hairColor
            newColorInfo.hairColorHSV = lastColorInfo.hairColorHSV
        }
        
        return newColorInfo
    }
    
    // MARK: - Statistical Color Processing
    
    private func removeColorOutliers(_ pixels: [(r: Float, g: Float, b: Float)]) -> [(r: Float, g: Float, b: Float)] {
        guard pixels.count > 10 else { return pixels } // Need sufficient samples
        
        // Calculate median color
        let sortedR = pixels.map { $0.r }.sorted()
        let sortedG = pixels.map { $0.g }.sorted()
        let sortedB = pixels.map { $0.b }.sorted()
        
        let medianR = sortedR[pixels.count / 2]
        let medianG = sortedG[pixels.count / 2]
        let medianB = sortedB[pixels.count / 2]
        
        // Calculate standard deviation
        let avgR = pixels.map { $0.r }.reduce(0, +) / Float(pixels.count)
        let avgG = pixels.map { $0.g }.reduce(0, +) / Float(pixels.count)
        let avgB = pixels.map { $0.b }.reduce(0, +) / Float(pixels.count)
        
        let varianceR = pixels.map { pow($0.r - avgR, 2) }.reduce(0, +) / Float(pixels.count)
        let varianceG = pixels.map { pow($0.g - avgG, 2) }.reduce(0, +) / Float(pixels.count)
        let varianceB = pixels.map { pow($0.b - avgB, 2) }.reduce(0, +) / Float(pixels.count)
        
        let stdDevR = sqrt(varianceR)
        let stdDevG = sqrt(varianceG)
        let stdDevB = sqrt(varianceB)
        
        // Filter outliers (within 2 standard deviations)
        return pixels.filter { pixel in
            abs(pixel.r - avgR) <= 2 * stdDevR &&
            abs(pixel.g - avgG) <= 2 * stdDevG &&
            abs(pixel.b - avgB) <= 2 * stdDevB
        }
    }
    
    private func calculateWeightedAverage(_ pixels: [(r: Float, g: Float, b: Float)]) -> (r: Float, g: Float, b: Float) {
        // Weight pixels towards center values to reduce noise
        let totalR = pixels.map { $0.r }.reduce(0, +)
        let totalG = pixels.map { $0.g }.reduce(0, +)
        let totalB = pixels.map { $0.b }.reduce(0, +)
        let count = Float(pixels.count)
        
        return (r: totalR / count, g: totalG / count, b: totalB / count)
    }
    
    private func updateColorInfo(with newInfo: ColorInfo) {
        DispatchQueue.main.async {
            self.lastColorInfo = newInfo
        }
    }
}
