//
//  ColorDegubTest.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/22/25.
//

import UIKit
import Metal
import MediaPipeTasksVision
import CoreGraphics

// MARK: - Temporary Debug Test Method
// Add this method to your ColorExtractor class for testing

extension ColorExtractor {

    func extractColorsDebugTest(
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

        LoggingService.info("ColorExtractor: DEBUG TEST - Starting extraction")

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

            LoggingService.info("ColorExtractor: DEBUG TEST - Texture copied, analyzing...")

            let pixelData = textureBuffer.contents().bindMemory(to: UInt8.self, capacity: bufferSize)

            // Test 1: Check if we have landmarks
            guard let landmarks = self.lastFaceLandmarks, !landmarks.isEmpty else {
                LoggingService.info("ColorExtractor: DEBUG TEST - NO LANDMARKS")
                BufferPoolManager.shared.recycleBuffer(textureBuffer)
                return
            }

            LoggingService.info("ColorExtractor: DEBUG TEST - Have \(landmarks.count) landmarks")

            // Test 2: Create one polygon and log its points
            let leftCheekPolygon = self.createOrderedPolygon(
                from: landmarks,
                indices: [123, 117, 118, 101, 36, 205, 187]
            )

            LoggingService.info("ColorExtractor: DEBUG TEST - Left cheek polygon has \(leftCheekPolygon.count) points")
            if leftCheekPolygon.count > 0 {
                LoggingService.info("ColorExtractor: DEBUG TEST - First point: \(leftCheekPolygon[0])")
                LoggingService.info("ColorExtractor: DEBUG TEST - Last point: \(leftCheekPolygon[leftCheekPolygon.count-1])")
            }

            // Test 3: Check segmentation mask for skin pixels
            var totalSkinPixels = 0
            var samplePixelColors: [(r: Float, g: Float, b: Float)] = []

            let skinClass = MultiClassSegmentedImageRenderer.SegmentationClass.skin.rawValue
            let sampleStep = 10 // Sample every 10th pixel for speed

            for y in stride(from: 0, to: processingHeight, by: sampleStep) {
                for x in stride(from: 0, to: processingWidth, by: sampleStep) {
                    let maskX = min(x * width / processingWidth, width - 1)
                    let maskY = min(y * height / processingHeight, height - 1)
                    let segIndex = maskY * width + maskX

                    if segmentMask[segIndex] == skinClass {
                        totalSkinPixels += 1

                        if samplePixelColors.count < 5 { // Collect first 5 samples
                            let pixelOffset = (y * processingWidth + x) * 4
                            if pixelOffset + 2 < bufferSize {
                                let b = Float(pixelData[pixelOffset])
                                let g = Float(pixelData[pixelOffset + 1])
                                let r = Float(pixelData[pixelOffset + 2])
                                samplePixelColors.append((r: r, g: g, b: b))
                            }
                        }
                    }
                }
            }

            LoggingService.info("ColorExtractor: DEBUG TEST - Found \(totalSkinPixels) skin pixels in mask (sampled)")
            LoggingService.info("ColorExtractor: DEBUG TEST - Sample colors: \(samplePixelColors)")

            // Test 4: Try simple polygon extraction
            if !leftCheekPolygon.isEmpty {
                let extractedPixels = self.extractPixelsFromRegionsSimplified(
                    pixelData: pixelData,
                    segmentMask: segmentMask,
                    polygons: [leftCheekPolygon],
                    targetSegmentClass: skinClass,
                    processingWidth: processingWidth,
                    processingHeight: processingHeight,
                    maskWidth: width,
                    maskHeight: height
                )

                LoggingService.info("ColorExtractor: DEBUG TEST - Polygon extraction result: \(extractedPixels.count) pixels")
            }

            BufferPoolManager.shared.recycleBuffer(textureBuffer)
        }

        cmdBuffer.commit()
    }
    // Replace the complex extractPixelsFromRegions method with this simpler version
        private func extractPixelsFromRegionsSimplified(
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

            for polygon in polygons {
                guard polygon.count >= 3 else {
                    LoggingService.info("ColorExtractor: Polygon has insufficient points: \(polygon.count)")
                    continue
                }

                LoggingService.info("ColorExtractor: Processing polygon with \(polygon.count) points")

                // Get bounding box for efficiency
                let boundingBox = getBoundingBox(for: polygon)
                LoggingService.info("ColorExtractor: Bounding box: \(boundingBox)")

                let startX = max(0, Int(boundingBox.minX * CGFloat(processingWidth)) - 5)
                let endX = min(processingWidth, Int(boundingBox.maxX * CGFloat(processingWidth)) + 5)
                let startY = max(0, Int(boundingBox.minY * CGFloat(processingHeight)) - 5)
                let endY = min(processingHeight, Int(boundingBox.maxY * CGFloat(processingHeight)) + 5)

                LoggingService.info("ColorExtractor: Scanning region X:\(startX)-\(endX) Y:\(startY)-\(endY)")

                var regionPixelCount = 0
                var insideCount = 0

                // Simple single-point sampling (no sub-pixel complexity)
                for y in startY..<endY {
                    for x in startX..<endX {
                        regionPixelCount += 1

                        // Convert pixel coordinates to normalized coordinates
                        let normalizedX = CGFloat(x) / CGFloat(processingWidth)
                        let normalizedY = CGFloat(y) / CGFloat(processingHeight)
                        let point = CGPoint(x: normalizedX, y: normalizedY)

                        if isPointInPolygonSimple(point, polygon: polygon) {
                            insideCount += 1

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

                                    // Basic quality filtering
                                    let brightness = (r + g + b) / 3.0
                                    if brightness > 15.0 && brightness < 245.0 {
                                        pixels.append((r: r, g: g, b: b))
                                    }
                                }
                            }
                        }
                    }
                }

                LoggingService.info("ColorExtractor: Scanned \(regionPixelCount) pixels, \(insideCount) inside polygon, extracted \(pixels.count) valid pixels")
            }

            return pixels
        }

        // Simplified point-in-polygon test
        private func isPointInPolygonSimple(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
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

        // Test method to verify polygon creation and basic functionality
        func debugPolygonExtraction() {
            guard let landmarks = self.lastFaceLandmarks, !landmarks.isEmpty else {
                LoggingService.info("ColorExtractor: No landmarks for debug test")
                return
            }

            let leftCheekPolygon = createOrderedPolygon(
                from: landmarks,
                indices: [123, 117, 118, 101, 36, 205, 187]
            )

            LoggingService.info("ColorExtractor: Debug - Left cheek polygon:")
            for (index, point) in leftCheekPolygon.enumerated() {
                LoggingService.info("  Point \(index): (\(point.x), \(point.y))")
            }

            // Test a few points to see if they're inside
            let testPoints = [
                CGPoint(x: 0.3, y: 0.6), // Should be around left cheek area
                CGPoint(x: 0.5, y: 0.5), // Center of face
                CGPoint(x: 0.1, y: 0.1)  // Top-left corner (should be outside)
            ]

            for (index, testPoint) in testPoints.enumerated() {
                let isInside = isPointInPolygonSimple(testPoint, polygon: leftCheekPolygon)
                LoggingService.info("ColorExtractor: Test point \(index) (\(testPoint.x), \(testPoint.y)) inside: \(isInside)")
            }
        }
    func extractColorsCoordinateFix(
            from texture: MTLTexture,
            segmentMask: UnsafePointer<UInt8>,
            width: Int,
            height: Int
        ) {
            let processingWidth = texture.width
            let processingHeight = texture.height

            // -----------------------------------------------------------------
            // Frame-sync DEBUG (B)
            // -----------------------------------------------------------------
            self.debugCheckFrameSync(context: "extractColorsCoordinateFix")

            LoggingService.info("ColorExtractor: COORDINATE FIX - Texture: \(processingWidth)x\(processingHeight), Mask: \(width)x\(height)")

            guard texture.width == width && texture.height == height else {
                LoggingService.warning("ColorExtractor: COORDINATE MISMATCH - This is likely the issue!")
                LoggingService.warning("ColorExtractor: Texture: \(texture.width)x\(texture.height) vs Mask: \(width)x\(height)")
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

                guard let landmarks = self.lastFaceLandmarks, !landmarks.isEmpty else {
                    LoggingService.info("ColorExtractor: No landmarks available")
                    BufferPoolManager.shared.recycleBuffer(textureBuffer)
                    return
                }

                // Create polygon for left cheek
                let leftCheekPolygon = self.createOrderedPolygon(
                    from: landmarks,
                    indices: [123, 117, 118, 101, 36, 205, 187]
                )

                LoggingService.info("ColorExtractor: COORDINATE FIX - Processing left cheek polygon with \(leftCheekPolygon.count) points")

                let extractedPixels = self.extractPixelsCoordinateFix(
                    pixelData: pixelData,
                    segmentMask: segmentMask,
                    polygon: leftCheekPolygon,
                    targetSegmentClass: ColorExtractor.faceSkinClassID,
                    processingWidth: processingWidth,
                    processingHeight: processingHeight,
                    maskWidth: width,
                    maskHeight: height
                )

                LoggingService.info("ColorExtractor: COORDINATE FIX - Final result: \(extractedPixels.count) pixels extracted")

                if !extractedPixels.isEmpty {
                    // Test: Calculate a simple average to verify the colors look reasonable
                    let avgR = extractedPixels.map { $0.r }.reduce(0, +) / Float(extractedPixels.count)
                    let avgG = extractedPixels.map { $0.g }.reduce(0, +) / Float(extractedPixels.count)
                    let avgB = extractedPixels.map { $0.b }.reduce(0, +) / Float(extractedPixels.count)

                    LoggingService.info("ColorExtractor: COORDINATE FIX - Average color: R:\(avgR) G:\(avgG) B:\(avgB)")
                }

                BufferPoolManager.shared.recycleBuffer(textureBuffer)
            }

            cmdBuffer.commit()
        }

        public func extractPixelsCoordinateFix(
            pixelData: UnsafePointer<UInt8>,
            segmentMask: UnsafePointer<UInt8>,
            polygon: [CGPoint],
            targetSegmentClass: UInt8 = ColorExtractor.faceSkinClassID,
            processingWidth: Int,
            processingHeight: Int,
            maskWidth: Int,
            maskHeight: Int
        ) -> [(r: Float, g: Float, b: Float)] {

            guard polygon.count >= 3 else {
                LoggingService.info("ColorExtractor: Polygon insufficient points")
                return []
            }

            // -----------------------------------------------------------------
            // Histogram container (A)
            // -----------------------------------------------------------------
            var classHistogram: [UInt8: Int] = [:]   //  key = class id  •  value = pixel count

            var pixels: [(r: Float, g: Float, b: Float)] = []

            // Get bounding box in normalized coordinates [0,1]
            let boundingBox = getBoundingBox(for: polygon)
            LoggingService.info("ColorExtractor: COORDINATE FIX - Normalized bounding box: \(boundingBox)")

            // Convert to actual pixel coordinates
            let startX = max(0, Int(boundingBox.minX * CGFloat(processingWidth)))
            let endX = min(processingWidth, Int(boundingBox.maxX * CGFloat(processingWidth)))
            let startY = max(0, Int(boundingBox.minY * CGFloat(processingHeight)))
            let endY = min(processingHeight, Int(boundingBox.maxY * CGFloat(processingHeight)))

            LoggingService.info("ColorExtractor: COORDINATE FIX - Texture scan region X:\(startX)-\(endX) Y:\(startY)-\(endY)")
            LoggingService.info("ColorExtractor: COORDINATE FIX - Processing dimensions: \(processingWidth)x\(processingHeight)")
            LoggingService.info("ColorExtractor: COORDINATE FIX - Mask dimensions: \(maskWidth)x\(maskHeight)")

            var scannedCount = 0
            var insideCount = 0
            var skinCount = 0
            var validCount = 0

            for y in startY..<endY {
                for x in startX..<endX {
                    scannedCount += 1

                    // Convert texture pixel to normalized coordinates for polygon test
                    let normalizedX = CGFloat(x) / CGFloat(processingWidth)
                    let normalizedY = CGFloat(y) / CGFloat(processingHeight)
                    let point = CGPoint(x: normalizedX, y: normalizedY)

                    if isPointInPolygonSimple(point, polygon: polygon) {
                        insideCount += 1

                        // FIXED: Use direct pixel coordinate mapping for segmentation mask
                        // The issue was here - we were scaling coordinates incorrectly
                        let maskX = x  // Direct mapping since texture and mask should be same size
                        let maskY = y  // Direct mapping since texture and mask should be same size

                        // Bounds check for mask
                        guard maskX >= 0 && maskX < maskWidth && maskY >= 0 && maskY < maskHeight else {
                            continue
                        }

                        let segIndex = maskY * maskWidth + maskX

                        // Update class histogram regardless of whether it’s skin
                        let classVal = segmentMask[segIndex]
                        classHistogram[classVal, default: 0] += 1

                        if classVal == targetSegmentClass {
                            skinCount += 1

                            let pixelOffset = (y * processingWidth + x) * 4
                            if pixelOffset + 2 < processingWidth * processingHeight * 4 {
                                let b = Float(pixelData[pixelOffset])
                                let g = Float(pixelData[pixelOffset + 1])
                                let r = Float(pixelData[pixelOffset + 2])

                                // Very lenient brightness filter for testing
                                let brightness = (r + g + b) / 3.0
                                if brightness > 10.0 && brightness < 250.0 {
                                    pixels.append((r: r, g: g, b: b))
                                    validCount += 1
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // Dump class histogram (A) – sorted by descending frequency
            // -----------------------------------------------------------------
            if !classHistogram.isEmpty {
                let histString = classHistogram
                    .sorted(by: { $0.value > $1.value })
                    .map { "C\($0.key):\($0.value)" }
                    .joined(separator: ", ")
                LoggingService.info("ColorExtractor: CLASS HISTOGRAM (inside polygon) – \(histString)")
            } else {
                LoggingService.info("ColorExtractor: CLASS HISTOGRAM – no classes found inside polygon")
            }

            LoggingService.info("ColorExtractor: COORDINATE FIX - Scanned:\(scannedCount) Inside:\(insideCount) Skin:\(skinCount) Valid:\(validCount)")

            return pixels
        }
}
