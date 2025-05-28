//
//  ColorExtractor+Utils.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/22/25.
//

import UIKit
import CoreGraphics
import MediaPipeTasksVision

/// Common helper logic shared by the various ColorExtractor paths.
/// (No stored state – this is purely functional/utility.)
extension ColorExtractor {

    // MARK: - Type-aliases
    typealias Pixel = (r: Float, g: Float, b: Float)

    // MARK: - Geometry helpers
    static func orderPointsCCW(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        let centroid = points.reduce(CGPoint.zero) { res, p in
            CGPoint(x: res.x + p.x, y: res.y + p.y)
        } / CGFloat(points.count)

        return points.sorted {
            atan2($0.y - centroid.y, $0.x - centroid.x)
          < atan2($1.y - centroid.y, $1.x - centroid.x)
        }
    }

    static func point(_ p: CGPoint, inside polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let (xi, yi) = (polygon[i].x, polygon[i].y)
            let (xj, yj) = (polygon[j].x, polygon[j].y)
            if (yi > p.y) != (yj > p.y),
               p.x < (xj - xi) * (p.y - yi) / (yj - yi) + xi {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var (minX, maxX, minY, maxY) =
            (first.x, first.x, first.y, first.y)
        for p in points.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY,
                      width: maxX - minX,
                      height: maxY - minY)
    }

    // MARK: Statistics --------------------------------------------------
    static func weightedAverage(_ pixels: [Pixel]) -> Pixel {
        let cnt = Float(pixels.count)
        let sums = pixels.reduce((0, 0, 0)) { res, px in
            (res.0 + px.r, res.1 + px.g, res.2 + px.b)
        }
        return (sums.0 / cnt, sums.1 / cnt, sums.2 / cnt)
    }

    static func removeOutliers(_ px: [Pixel]) -> [Pixel] {
        guard px.count > 10 else { return px }
        func channel(_ key: KeyPath<Pixel, Float>) -> (Float, Float) {
            let arr = px.map { $0[keyPath: key] }
            let mean = arr.reduce(0, +) / Float(arr.count)
            let var_ = arr.reduce(0) { $0 + pow($1 - mean, 2) } / Float(arr.count)
            let std = sqrt(var_)
            return (mean, std)
        }
        let (mR, sR) = channel(\.r)
        let (mG, sG) = channel(\.g)
        let (mB, sB) = channel(\.b)
        return px.filter { p in
            abs(p.r - mR) <= 2*sR &&
            abs(p.g - mG) <= 2*sG &&
            abs(p.b - mB) <= 2*sB
        }
    }
}

// MARK: - Tunable thresholds used by color extraction
extension ColorExtractor {
    enum Threshold {
        static let minSkinBrightness: Float = 20.0
        static let maxSkinBrightness: Float = 240.0

        static let minHairBrightness: Float = 5.0
        static let maxHairBrightness: Float = 250.0
    }
    
    // Eye color extraction thresholds
    enum EyeExtractionThreshold {
        static let minIrisBrightness: Float = 30.0  // Increased from 10.0 to better exclude pupil
        static let maxIrisBrightness: Float = 200.0
        static let minPixelCount: Int = 20
        static let maxReflectionBrightness: Float = 240.0
        static let minConfidenceScore: Float = 0.3
        static let minSaturation: Float = 0.1  // Minimum saturation to exclude very desaturated pixels
        static let maxPupilBrightness: Float = 50.0  // Maximum brightness for pupil detection
        static let pupilExclusionRadius: Float = 0.3  // Radius around pupil center to exclude (as fraction of iris)
    }
}

// MARK: - CGPoint helpers ----------------------------------------------
private extension CGPoint {
    /// Divide a point’s components by a scalar (handy for centroids, scaling, etc.)
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
}
