//
//  MockAnalysisResultFactory.swift
//  ImageSegmenter
//
//  Pre-built AnalysisResult objects for LLM pipeline testing.
//  Each fixture has realistic Lab color values and contrast data
//  that match the declared season, so the full personalization
//  pipeline runs exactly as it would with a real camera analysis.
//

#if DEBUG
import UIKit

struct MockAnalysisResultFactory {

    // MARK: - Public Fixtures

    /// True Spring — warm, bright, medium contrast.
    /// Golden skin, honey-brown hair, warm hazel eyes.
    static func trueSpring() -> AnalysisResult {
        AnalysisResult(
            season: .spring,
            detailedSeasonName: "True Spring",
            confidence: 0.84,
            deltaEToNextClosest: 12.3,
            nextClosestSeason: .autumn,
            skinColor:        UIColor(hex: "#E8C99A")!,
            skinColorLab:     (L: 82, a: 7,  b: 22),
            hairColor:        UIColor(hex: "#8B6420"),
            hairColorLab:     (L: 44, a: 10, b: 28),
            leftEyeColor:     UIColor(hex: "#7A8B30"),
            leftEyeColorLab:  (L: 54, a: -8, b: 24),
            rightEyeColor:    UIColor(hex: "#7A8B30"),
            rightEyeColorLab: (L: 54, a: -8, b: 24),
            averageEyeColor:  UIColor(hex: "#7A8B30"),
            averageEyeColorLab: (L: 54, a: -8, b: 24),
            leftEyeConfidence:  0.88,
            rightEyeConfidence: 0.86,
            contrastValue:    0.45,
            contrastLevel:    "medium",
            contrastDescription: "Medium contrast between features — skin, hair, and eyes differ noticeably but don't create extreme light-dark drama."
        )
    }

    /// Soft Autumn — warm, muted, low contrast.
    /// Peachy beige skin, muted warm-brown hair, soft hazel eyes.
    static func softAutumn() -> AnalysisResult {
        AnalysisResult(
            season: .autumn,
            detailedSeasonName: "Soft Autumn",
            confidence: 0.79,
            deltaEToNextClosest: 8.6,
            nextClosestSeason: .summer,
            skinColor:        UIColor(hex: "#D9B899")!,
            skinColorLab:     (L: 76, a: 11, b: 20),
            hairColor:        UIColor(hex: "#6B4C2A"),
            hairColorLab:     (L: 34, a: 9,  b: 18),
            leftEyeColor:     UIColor(hex: "#7A6040"),
            leftEyeColorLab:  (L: 40, a: 8,  b: 16),
            rightEyeColor:    UIColor(hex: "#7A6040"),
            rightEyeColorLab: (L: 40, a: 8,  b: 16),
            averageEyeColor:  UIColor(hex: "#7A6040"),
            averageEyeColorLab: (L: 40, a: 8, b: 16),
            leftEyeConfidence:  0.82,
            rightEyeConfidence: 0.81,
            contrastValue:    0.26,
            contrastLevel:    "low",
            contrastDescription: "Low contrast — skin, hair, and eyes blend softly together with no sharp transitions."
        )
    }

    /// True Winter — cool, bright, high contrast.
    /// Cool fair skin, near-black hair, cool dark eyes.
    static func trueWinter() -> AnalysisResult {
        AnalysisResult(
            season: .winter,
            detailedSeasonName: "True Winter",
            confidence: 0.91,
            deltaEToNextClosest: 18.2,
            nextClosestSeason: .summer,
            skinColor:        UIColor(hex: "#F0E8E2")!,
            skinColorLab:     (L: 92, a: 3,  b: -3),
            hairColor:        UIColor(hex: "#1C1C1C"),
            hairColorLab:     (L: 12, a: 1,  b:  1),
            leftEyeColor:     UIColor(hex: "#2E2A30"),
            leftEyeColorLab:  (L: 18, a: 2,  b: -4),
            rightEyeColor:    UIColor(hex: "#2E2A30"),
            rightEyeColorLab: (L: 18, a: 2,  b: -4),
            averageEyeColor:  UIColor(hex: "#2E2A30"),
            averageEyeColorLab: (L: 18, a: 2, b: -4),
            leftEyeConfidence:  0.93,
            rightEyeConfidence: 0.92,
            contrastValue:    0.82,
            contrastLevel:    "high",
            contrastDescription: "High contrast — stark difference between very fair skin and near-black hair and eyes."
        )
    }

    /// True Summer — cool, muted, medium-low contrast.
    /// Cool rose-beige skin, ash-brown hair, cool grey-blue eyes.
    static func trueSummer() -> AnalysisResult {
        AnalysisResult(
            season: .summer,
            detailedSeasonName: "True Summer",
            confidence: 0.77,
            deltaEToNextClosest: 9.1,
            nextClosestSeason: .winter,
            skinColor:        UIColor(hex: "#E2D0C6")!,
            skinColorLab:     (L: 84, a: 6,  b:  5),
            hairColor:        UIColor(hex: "#9A8878"),
            hairColorLab:     (L: 58, a: 3,  b:  8),
            leftEyeColor:     UIColor(hex: "#6B7E94"),
            leftEyeColorLab:  (L: 51, a: -2, b: -16),
            rightEyeColor:    UIColor(hex: "#6B7E94"),
            rightEyeColorLab: (L: 51, a: -2, b: -16),
            averageEyeColor:  UIColor(hex: "#6B7E94"),
            averageEyeColorLab: (L: 51, a: -2, b: -16),
            leftEyeConfidence:  0.79,
            rightEyeConfidence: 0.78,
            contrastValue:    0.38,
            contrastLevel:    "medium-low",
            contrastDescription: "Medium-low contrast — features blend together with a soft, cool-toned harmony."
        )
    }

    // MARK: - Convenience

    static var all: [(label: String, result: AnalysisResult)] {
        [
            ("True Spring",  trueSpring()),
            ("Soft Autumn",  softAutumn()),
            ("True Winter",  trueWinter()),
            ("True Summer",  trueSummer())
        ]
    }
}
#endif
