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
