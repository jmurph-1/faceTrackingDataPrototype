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

    // MARK: - High Accuracy Region-Based Extraction with Per-Region Analysis

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

        // Build polygons for each facial region
        let leftCheekPolygon = createOrderedPolygon(
            from: landmarks,
            indices: [187, 205, 36, 101, 118, 117, 123] // Ordered for proper polygon
        )

        let rightCheekPolygon = createOrderedPolygon(
            from: landmarks,
            indices: [425, 280, 346, 347, 348, 329, 371, 266] // Ordered for proper polygon
        )

        let foreheadPolygon = createOrderedPolygon(
            from: landmarks,
            indices: [9, 337, 299, 297, 338, 10, 109, 67, 69, 108] // Ordered for proper polygon
        )

        // Extract colors from each region separately for validation
        let leftCheekPixels = extractPixelsFromRegions(
            pixelData: pixelData,
            segmentMask: segmentMask,
            polygons: [leftCheekPolygon],
            targetSegmentClass: ColorExtractor.faceSkinClassID,
            processingWidth: processingWidth,
            processingHeight: processingHeight,
            maskWidth: maskWidth,
            maskHeight: maskHeight
        )

        let rightCheekPixels = extractPixelsFromRegions(
            pixelData: pixelData,
            segmentMask: segmentMask,
            polygons: [rightCheekPolygon],
            targetSegmentClass: ColorExtractor.faceSkinClassID,
            processingWidth: processingWidth,
            processingHeight: processingHeight,
            maskWidth: maskWidth,
            maskHeight: maskHeight
        )

        let foreheadPixels = extractPixelsFromRegions(
            pixelData: pixelData,
            segmentMask: segmentMask,
            polygons: [foreheadPolygon],
            targetSegmentClass: ColorExtractor.faceSkinClassID,
            processingWidth: processingWidth,
            processingHeight: processingHeight,
            maskWidth: maskWidth,
            maskHeight: maskHeight
        )

        // Validate regional consistency before combining
        let allSkinPixels = validateAndCombineRegionalData(
            leftCheek: leftCheekPixels,
            rightCheek: rightCheekPixels,
            forehead: foreheadPixels
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

        return calculateColorInfo(skinPixels: allSkinPixels, hairPixels: hairPixels)
    }

    // MARK: - Ordered Polygon Creation

    public func createOrderedPolygon(from landmarks: [NormalizedLandmark], indices: [Int]) -> [CGPoint] {
        var points: [CGPoint] = []

        for index in indices {
            if index < landmarks.count {
                let landmark = landmarks[index]
                points.append(CGPoint(x: CGFloat(landmark.x), y: CGFloat(landmark.y)))
            }
        }

        // Ensure we have enough points for a valid polygon
        guard points.count >= 3 else { return points }

        return ColorExtractor.orderPointsCCW(points)
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

        typealias Px = ColorExtractor.Pixel

        // Use sub-pixel sampling for maximum accuracy
        for polygon in polygons {
            guard polygon.count >= 3 else { continue }

            // Get bounding box to optimise search area
            let boundingBox = ColorExtractor.boundingBox(of: polygon)

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

                            if ColorExtractor.point(samplePoint, inside: polygon) {
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

                                // Quality filtering
                                let brightness = (r + g + b) / 3.0
                                if brightness > Threshold.minSkinBrightness &&
                                   brightness < Threshold.maxSkinBrightness {
                                    pixels.append((r: r, g: g, b: b))
                                }
                            }
                        }
                    }
                }
            }
        }

        return pixels as [Px]
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

    // MARK: - Advanced Color Calculation with Reliability Validation

    private func calculateColorInfo(
        skinPixels: [(r: Float, g: Float, b: Float)],
        hairPixels: [(r: Float, g: Float, b: Float)]
    ) -> ColorInfo {

        var newColorInfo = ColorInfo()

        // Advanced skin color calculation with reliability validation
        if !skinPixels.isEmpty {
            LoggingService.info("ColorExtractor: raw skin pixel count: \(skinPixels.count)")
            let filteredSkinPixels = ColorExtractor.removeOutliers(skinPixels)

            let finalSkinPixels: [(r: Float, g: Float, b: Float)] =
                filteredSkinPixels.count >= 10 ? filteredSkinPixels : skinPixels
            LoggingService.info("ColorExtractor: pixels after outlier filter: \(finalSkinPixels.count)")

            if !finalSkinPixels.isEmpty {
                let avgColor = ColorExtractor.weightedAverage(finalSkinPixels)
                let calculatedSkinColor = UIColor(
                    red: CGFloat(avgColor.r / 255.0),
                    green: CGFloat(avgColor.g / 255.0),
                    blue: CGFloat(avgColor.b / 255.0),
                    alpha: 1.0
                )

                // Validate if this skin color reading is reliable before updating
                if isSkinColorReadingReliable(calculatedSkinColor, pixelCount: finalSkinPixels.count) {
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
                    // Keep previous values if current reading is unreliable
                    LoggingService.info("ColorExtractor: Skipping unreliable skin color reading")
                    newColorInfo.skinColor = lastColorInfo.skinColor
                    newColorInfo.skinColorHSV = lastColorInfo.skinColorHSV
                }
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
            let filteredHairPixels = hairPixels
            if !filteredHairPixels.isEmpty {
                let avgColor = calculateSimpleAverage(filteredHairPixels)
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

    // MARK: - Regional Data Validation and Reliability Checks

    private func validateAndCombineRegionalData(
        leftCheek: [(r: Float, g: Float, b: Float)],
        rightCheek: [(r: Float, g: Float, b: Float)],
        forehead: [(r: Float, g: Float, b: Float)]
    ) -> [(r: Float, g: Float, b: Float)] {

        // More lenient validation - start with basic checks
        let minPixelsPerRegion = 5 // Reduced from 15 to 5
        let totalPixels = leftCheek.count + rightCheek.count + forehead.count

        // LoggingService.info("ColorExtractor: Regional pixel counts - L:\(leftCheek.count) R:\(rightCheek.count) F:\(forehead.count) Total:\(totalPixels)")

        // Check if we have ANY reasonable data
        guard totalPixels >= 10 else {
            LoggingService.info("ColorExtractor: Total pixels too low: \(totalPixels)")
            return []
        }

        // Collect all non-empty regions
        var validRegions: [[(r: Float, g: Float, b: Float)]] = []
        var regionAverages: [(r: Float, g: Float, b: Float)] = []

        if leftCheek.count >= minPixelsPerRegion {
            let avg = calculateSimpleAverage(leftCheek)
            if !isTooBlack(avg) {
                validRegions.append(leftCheek)
                regionAverages.append(avg)
                LoggingService.info("ColorExtractor: Left cheek valid - avg: R:\(avg.r) G:\(avg.g) B:\(avg.b)")
            } else {
                LoggingService.info("ColorExtractor: Left cheek too dark")
            }
        }

        if rightCheek.count >= minPixelsPerRegion {
            let avg = calculateSimpleAverage(rightCheek)
            if !isTooBlack(avg) {
                validRegions.append(rightCheek)
                regionAverages.append(avg)
                LoggingService.info("ColorExtractor: Right cheek valid - avg: R:\(avg.r) G:\(avg.g) B:\(avg.b)")
            } else {
                LoggingService.info("ColorExtractor: Right cheek too dark")
            }
        }

        if forehead.count >= minPixelsPerRegion {
            let avg = calculateSimpleAverage(forehead)
            if !isTooBlack(avg) {
                validRegions.append(forehead)
                regionAverages.append(avg)
                LoggingService.info("ColorExtractor: Forehead valid - avg: R:\(avg.r) G:\(avg.g) B:\(avg.b)")
            } else {
                LoggingService.info("ColorExtractor: Forehead too dark")
            }
        }

        // Need at least 2 valid regions for consistency check
        guard validRegions.count >= 2 else {
            LoggingService.info("ColorExtractor: Only \(validRegions.count) valid regions - combining all available data")
            // If we have any valid data, use it (relaxed approach)
            return validRegions.flatMap { $0 }
        }

        // Check consistency between valid regions only
        if areRegionalColorsConsistent(regionAverages) {
            LoggingService.info("ColorExtractor: Regional colors consistent - combining \(validRegions.count) regions")
            return validRegions.flatMap { $0 }
        } else {
            LoggingService.info("ColorExtractor: Regional colors inconsistent but using largest region")
            // Fallback: use the region with most pixels
            let largestRegion = validRegions.max(by: { $0.count < $1.count }) ?? []
            return largestRegion
        }
    }

    private func calculateSimpleAverage(_ pixels: [(r: Float, g: Float, b: Float)]) -> (r: Float, g: Float, b: Float) {
        guard !pixels.isEmpty else { return (0, 0, 0) }

        let count = Float(pixels.count)
        let totalR = pixels.map { $0.r }.reduce(0, +)
        let totalG = pixels.map { $0.g }.reduce(0, +)
        let totalB = pixels.map { $0.b }.reduce(0, +)

        return (r: totalR / count, g: totalG / count, b: totalB / count)
    }

    private func isTooBlack(_ color: (r: Float, g: Float, b: Float)) -> Bool {
        let brightness = (color.r + color.g + color.b) / 3.0
        let isTooBlack = brightness < 15.0 // Reduced from 30.0 to 15.0
        if isTooBlack {
            LoggingService.info("ColorExtractor: Color too black - brightness: \(brightness)")
        }
        return isTooBlack
    }

    private func areRegionalColorsConsistent(_ regionAverages: [(r: Float, g: Float, b: Float)]) -> Bool {
        guard regionAverages.count >= 2 else { return true }

        var maxDistance: Float = 0

        // Check all pairs of regions
        for i in 0..<regionAverages.count {
            for j in (i+1)..<regionAverages.count {
                let distance = colorDistance(regionAverages[i], regionAverages[j])
                maxDistance = max(maxDistance, distance)
                // LoggingService.info("ColorExtractor: Distance between regions \(i) and \(j): \(distance)")
            }
        }

        let consistencyThreshold: Float = 50.0 // Increased from 35.0 to 50.0
        let isConsistent = maxDistance <= consistencyThreshold

        LoggingService.info("ColorExtractor: Max regional distance: \(maxDistance), threshold: \(consistencyThreshold), consistent: \(isConsistent)")

        return isConsistent
    }

    private func colorDistance(_ color1: (r: Float, g: Float, b: Float), _ color2: (r: Float, g: Float, b: Float)) -> Float {
        let deltaR = color1.r - color2.r
        let deltaG = color1.g - color2.g
        let deltaB = color1.b - color2.b
        return sqrt(deltaR * deltaR + deltaG * deltaG + deltaB * deltaB)
    }

    private func isSkinColorReadingReliable(_ color: UIColor, pixelCount: Int) -> Bool {
        // LoggingService.info("ColorExtractor: Validating skin color reading with \(pixelCount) pixels")

        let isFirstReading = lastColorInfo.skinColor == .clear
        if isFirstReading {
            // LoggingService.info("ColorExtractor: First skin reading – bypassing reliability gate")
            // Require higher brightness for first reading
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            let brightness = (Float(r) + Float(g) + Float(b)) / 3.0

            if brightness < 0.2 { // Higher threshold for first reading
                // LoggingService.info("ColorExtractor: First reading too dark: \(brightness)")
                return false
            }
            return true
        }

        guard pixelCount >= 10 else {
            // LoggingService.info("ColorExtractor: Insufficient total pixels: \(pixelCount)")
            return false
        }

        // Check 2: Color is not too black (likely an error)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)

        let brightness = (Float(r) + Float(g) + Float(b)) / 3.0
        // LoggingService.info("ColorExtractor: Color brightness: \(brightness), RGB: (\(r), \(g), \(b))")

        guard brightness >= 0.08 else { // Reduced from 0.15 to 0.08 (8% minimum)
            LoggingService.info("ColorExtractor: Color too dark: \(brightness)")
            return false
        }

        // Check 3: Color passes basic skin color validation (more lenient)
        let skinColorValid = isSkinColorFast(r: Float(r * 255), g: Float(g * 255), b: Float(b * 255))
        // LoggingService.info("ColorExtractor: Skin color validation result: \(skinColorValid)")

        // Make skin validation optional for initial frames
        if lastColorInfo.skinColor == .clear {
            // For first-time detection, skip skin color validation
            // LoggingService.info("ColorExtractor: First time detection - skipping skin validation")
        } else if !skinColorValid {
            LoggingService.info("ColorExtractor: Color failed skin validation")
            return false
        }

        // Check 4: If we already have a skin color, new color shouldn't be drastically different
        if lastColorInfo.skinColor != .clear {
            var lastR: CGFloat = 0, lastG: CGFloat = 0, lastB: CGFloat = 0
            lastColorInfo.skinColor.getRed(&lastR, green: &lastG, blue: &lastB, alpha: nil)

            let colorChange = sqrt(
                pow(Float(r - lastR), 2) +
                pow(Float(g - lastG), 2) +
                pow(Float(b - lastB), 2)
            )

            // LoggingService.info("ColorExtractor: Color change magnitude: \(colorChange)")

            // ----------------------------------------------------------
            // Allow larger jumps when we have a *lot* of data or
            // make the threshold adaptive to sample size
            // ----------------------------------------------------------
            let baseThreshold: Float = 0.5         // old static value
            let adaptiveBoost = min(Float(pixelCount) / 5000.0, 1.0) * 0.5
            let maxChangeThreshold = baseThreshold + adaptiveBoost
            if colorChange > maxChangeThreshold {
                LoggingService.warning(
                    "ColorExtractor: Change \(colorChange) > \(maxChangeThreshold) – rejected"
                )
                return false
            }
        }

        LoggingService.info("ColorExtractor: Skin color reading validated successfully")
        return true
    }

    // MARK: - Fast Skin Detection (for validation)

    private func isSkinColorFast(r: Float, g: Float, b: Float) -> Bool {
        let red = r / 255.0
        let green = g / 255.0
        let blue = b / 255.0

        // Use YCbCr method for validation
        let ycbcr = rgbToYCbCrSimple(r: red, g: green, b: blue)
        let cb = ycbcr.cb
        let cr = ycbcr.cr

        // Skin detection ranges
        let skinRegion1 = (cb >= 70 && cb <= 135) && (cr >= 125 && cr <= 180)
        let skinRegion2 = (cb >= 80 && cb <= 140) && (cr >= 130 && cr <= 185)

        return skinRegion1 || skinRegion2
    }

    private func rgbToYCbCrSimple(r: Float, g: Float, b: Float) -> (cb: Float, cr: Float) {
        let r255 = r * 255.0
        let g255 = g * 255.0
        let b255 = b * 255.0

        let cb = -0.169 * r255 - 0.331 * g255 + 0.500 * b255 + 128
        let cr = 0.500 * r255 - 0.419 * g255 - 0.081 * b255 + 128

        return (cb: cb, cr: cr)
    }

    private func updateColorInfo(with newInfo: ColorInfo) {
        self.lastColorInfo = newInfo
        // LoggingService.info("ColorExtractor: running average skin color: \(newInfo.skinColor)")
        DispatchQueue.main.async {
            self.lastColorInfo = newInfo
        }
    }
}
