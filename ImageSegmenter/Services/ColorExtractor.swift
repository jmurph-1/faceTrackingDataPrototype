import UIKit
import Metal
import MediaPipeTasksVision // For NormalizedLandmark
import CoreGraphics // For CGPoint, CGFloat

// Assuming LoggingService and BufferPoolManager are globally accessible singletons as in the original file.
// Assuming SegmentationClass will be accessible from MultiClassSegmentedImageRenderer or a shared file.

// MARK: - White Balance Calibration
public struct WhiteBalanceCalibration {
    public let redFactor: Float
    public let greenFactor: Float
    public let blueFactor: Float

    public static let identity = WhiteBalanceCalibration(
        redFactor: 1.0,
        greenFactor: 1.0,
        blueFactor: 1.0
    )

    public init(redFactor: Float, greenFactor: Float, blueFactor: Float) {
        self.redFactor = redFactor
        self.greenFactor = greenFactor
        self.blueFactor = blueFactor
    }

    public static func calculate(from referenceColor: (r: Float, g: Float, b: Float)) -> WhiteBalanceCalibration {
        // Method 1: Using 255 as reference (maximum white)
        let maxPossibleValue: Float = 255.0
        let method1Factors = (
            r: maxPossibleValue / referenceColor.r,
            g: maxPossibleValue / referenceColor.g,
            b: maxPossibleValue / referenceColor.b
        )

        // Method 2: Using highest channel as reference
        let maxChannel = max(referenceColor.r, max(referenceColor.g, referenceColor.b))
        let method2Factors = (
            r: maxChannel / referenceColor.r,
            g: maxChannel / referenceColor.g,
            b: maxChannel / referenceColor.b
        )

        // Log both methods for comparison
        LoggingService.debug("WHITE_BALANCE: Method 1 (255 reference) factors - R:\(method1Factors.r) G:\(method1Factors.g) B:\(method1Factors.b)")
        LoggingService.debug("WHITE_BALANCE: Method 2 (max channel) factors - R:\(method2Factors.r) G:\(method2Factors.g) B:\(method2Factors.b)")

        // Use Method 2 (max channel reference) as it preserves exposure better
        return WhiteBalanceCalibration(
            redFactor: method2Factors.r,
            greenFactor: method2Factors.g,
            blueFactor: method2Factors.b
        )
    }
}

// MARK: - Color Extractor
class ColorExtractor {
    static let faceSkinClassID: UInt8 = 3

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
    #if DEBUG
    private(set) var latestTextureFrameIndex: Int = -1
    private(set) var latestMaskFrameIndex: Int   = -1
    #endif

    public let metalDevice: MTLDevice
    public let commandQueue: MTLCommandQueue?

    private var isCalibrated: Bool = false
    private var whiteBalance = WhiteBalanceCalibration.identity

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

    #if DEBUG
    /// Call right after you publish a texture
    func updateTextureFrameIndex(_ index: Int) {
        latestTextureFrameIndex = index
    }

    /// Call right after you publish a segmentation mask
    func updateMaskFrameIndex(_ index: Int) {
        latestMaskFrameIndex = index
    }
    #endif

    /// Logs whether the most recent texture / mask indices line up.
    /// Pass a short `context` so the log tells you which call-path performed the check.
    func debugCheckFrameSync(context: String) {
        #if DEBUG
        guard latestTextureFrameIndex >= 0, latestMaskFrameIndex >= 0 else { return }

        if latestTextureFrameIndex == latestMaskFrameIndex {
            LoggingService.info("ColorExtractor: Frame sync OK (\(context)) – idx \(latestTextureFrameIndex)")
        } else {
            LoggingService.warning("ColorExtractor: FRAME DESYNC (\(context)) – texture \(latestTextureFrameIndex) vs mask \(latestMaskFrameIndex)")
        }
        #endif
    }

    // MARK: - Public extraction entry point
    func extractColorsOptimized(
        from texture: MTLTexture,
        segmentMask: UnsafePointer<UInt8>,
        width: Int,
        height: Int
    ) {
        // Skip color extraction if not calibrated
        guard isCalibrated else {
            LoggingService.debug("COLOR_FLOW: Skipping color extraction - not calibrated")
            return
        }

        LoggingService.verbose("COLOR_FLOW: Starting optimized color extraction")

        // Production path → highest-accuracy algorithm
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

    public func setWhiteBalance(_ calibration: WhiteBalanceCalibration) {
        LoggingService.info("COLOR_FLOW: Setting white balance calibration - R:\(calibration.redFactor) G:\(calibration.greenFactor) B:\(calibration.blueFactor)")
        self.whiteBalance = calibration
        self.isCalibrated = true
        LoggingService.info("COLOR_FLOW: White balance calibration set and color extractor marked as calibrated")
    }

    private func applyWhiteBalance(to color: (r: Float, g: Float, b: Float)) -> (r: Float, g: Float, b: Float) {
        let corrected = (
            r: min(255, color.r * whiteBalance.redFactor),
            g: min(255, color.g * whiteBalance.greenFactor),
            b: min(255, color.b * whiteBalance.blueFactor)
        )
        LoggingService.verbose("COLOR_FLOW: Applied white balance correction - Original(R:\(color.r) G:\(color.g) B:\(color.b)) -> Corrected(R:\(corrected.r) G:\(corrected.g) B:\(corrected.b))")
        return corrected
    }

    public func extractWhiteReferenceColor(
        from texture: MTLTexture,
        region: CGRect,
        width: Int,
        height: Int
    ) -> (r: Float, g: Float, b: Float)? {
        LoggingService.debug("COLOR_FLOW: Attempting to extract white reference color from region: \(region)")

        // Create a temporary buffer to store color data
        let bytesPerPixel = 4
        let regionWidth = Int(region.width * CGFloat(width))
        let regionHeight = Int(region.height * CGFloat(height))
        let regionX = Int(region.minX * CGFloat(width))
        let regionY = Int(region.minY * CGFloat(height))

        let bufferSize = regionWidth * regionHeight * bytesPerPixel
        guard let buffer = metalDevice.makeBuffer(length: bufferSize, options: .storageModeShared) else {
            LoggingService.error("COLOR_FLOW: Failed to create metal buffer for white reference extraction")
            return nil
        }

        // Create a region for copying
        let region = MTLRegion(
            origin: MTLOrigin(x: regionX, y: regionY, z: 0),
            size: MTLSize(width: regionWidth, height: regionHeight, depth: 1)
        )

        // Copy texture region to buffer
        texture.getBytes(buffer.contents(),
                        bytesPerRow: regionWidth * bytesPerPixel,
                        from: region,
                        mipmapLevel: 0)

        // Calculate average color
        var totalR: Float = 0
        var totalG: Float = 0
        var totalB: Float = 0
        let pixels = buffer.contents().bindMemory(to: UInt8.self, capacity: bufferSize)
        let totalPixels = regionWidth * regionHeight

        for pixelIndex in stride(from: 0, to: bufferSize, by: bytesPerPixel) {
            totalB += Float(pixels[pixelIndex])
            totalG += Float(pixels[pixelIndex + 1])
            totalR += Float(pixels[pixelIndex + 2])
        }

        let averageColor = (
            r: totalR / Float(totalPixels),
            g: totalG / Float(totalPixels),
            b: totalB / Float(totalPixels)
        )

        LoggingService.debug("COLOR_FLOW: Extracted white reference color - R:\(averageColor.r) G:\(averageColor.g) B:\(averageColor.b)")
        return averageColor
    }
}
