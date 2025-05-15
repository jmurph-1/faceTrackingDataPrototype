import Foundation
import UIKit

/// A rule-based classifier for the 4 macro-seasons
class SeasonClassifier {

    /// The four macro-seasons
    enum Season: String, CaseIterable {
        case spring = "Spring"
        case summer = "Summer"
        case autumn = "Autumn"
        case winter = "Winter"

        /// Get a brief description of the season
        var description: String {
            switch self {
            case .spring:
                return "Warm and bright colors that bring energy and freshness"
            case .summer:
                return "Cool and soft colors with blue undertones"
            case .autumn:
                return "Warm and muted colors with golden undertones"
            case .winter:
                return "Cool and clear colors with blue undertones"
            }
        }
    }

    /// Classification result with season and confidence metrics
    struct ClassificationResult {
        let season: Season
        let confidence: Float
        let deltaEToNextClosest: Float
        let nextClosestSeason: Season
    }

    /// Threshold parameters for classification
    struct Thresholds: Decodable {
        let warmCoolThreshold: Float
        let lightDarkThreshold: Float
        let brightThreshold: Float
        let softThreshold: Float

        /// Default thresholds based on standard values
        static let `default` = Thresholds(
            warmCoolThreshold: 12.0,   // b* value: >= 12 = warm, < 12 = cool
            lightDarkThreshold: 65.0,  // L* value: >= 65 = light, < 65 = dark
            brightThreshold: 40.0,     // Chroma: >= 40 = bright
            softThreshold: 35.0        // Chroma: <= 35 = soft, in between = medium
        )
    }

    // Current thresholds
    private var thresholds: Thresholds

    /// Initialize with custom thresholds or use defaults
    init(thresholds: Thresholds = .default) {
        self.thresholds = thresholds
        loadThresholdsFromFile()
    }

    /// Load thresholds from configuration file if available
    private func loadThresholdsFromFile() {
        // Attempt to load thresholds.json from the app bundle
        if let url = Bundle.main.url(forResource: "thresholds", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                self.thresholds = try decoder.decode(Thresholds.self, from: data)
            } catch {
                print("Error loading thresholds.json: \(error). Using default thresholds.")
            }
        }
    }

    /// Determines the season directly based on the color properties using the rule-based approach
    private func determineSeasonFromProperties(isWarm: Bool, isLight: Bool) -> Season {
        if isWarm && isLight {
            return .spring
        } else if !isWarm && isLight {
            return .summer
        } else if isWarm && !isLight {
            return .autumn
        } else {
            return .winter // !isWarm && !isLight
        }
    }

    /// Calculate season scores based on color properties
    private func calculateSeasonScores(isWarm: Bool, isLight: Bool) -> [Season: Float] {
        var seasonScores = [Season: Float]()

        // Calculate basic scores for each season based on skin properties
        for season in Season.allCases {
            var score: Float = 0

            switch season {
            case .spring:
                // Spring: Warm + Light
                if isWarm { score += 1.5 }
                if isLight { score += 1.5 }

            case .summer:
                // Summer: Cool + Light
                if !isWarm { score += 1.5 }
                if isLight { score += 1.5 }

            case .autumn:
                // Autumn: Warm + Dark
                if isWarm { score += 1.5 }
                if !isLight { score += 1.5 }

            case .winter:
                // Winter: Cool + Dark
                if !isWarm { score += 1.5 }
                if !isLight { score += 1.5 }
            }

            seasonScores[season] = score
        }

        return seasonScores
    }

    /// Classify colors into one of the four seasons
    /// - Parameters:
    ///   - skinColor: The skin color in Lab color space
    ///   - hairColor: The hair color in Lab color space (optional, not currently used)
    /// - Returns: Classification result with season and confidence metrics
    func classify(
        skinColor: ColorConverters.LabColor,
        hairColor: ColorConverters.LabColor? = nil
    ) -> ClassificationResult {

        // Extract Lab values from skin color
        let skinL = Float(skinColor.L)
        let skinA = Float(skinColor.a)
        let skinB = Float(skinColor.b)

        // Calculate chroma (color intensity)
        let skinChroma = sqrt(skinA * skinA + skinB * skinB)

        // Feature 1: Undertone - Warm vs Cool (based on b* value)
        // b* >= 12 = warm, b* < 12 = cool
        let isWarm = skinB >= thresholds.warmCoolThreshold

        // Feature 2: Value - Light vs Dark (based on L* value)
        // L* >= 65 = light, L* < 65 = dark
        let isLight = skinL >= thresholds.lightDarkThreshold

        // Determine the season based on the rule-based approach (ignoring softness)
        let season = determineSeasonFromProperties(isWarm: isWarm, isLight: isLight)

        // Calculate scores for confidence calculation
        let seasonScores = calculateSeasonScores(isWarm: isWarm, isLight: isLight)

        // Sort seasons by score
        let sortedSeasons = seasonScores.sorted { $0.value > $1.value }
        let bestScore = sortedSeasons[0].value
        let secondBestSeason = sortedSeasons[1].key
        let secondBestScore = sortedSeasons[1].value

        // Calculate confidence based on the difference between best and second best
        let scoreDifference = bestScore - secondBestScore
        let maxPossibleScore: Float = 3.0
        
        // Calculate confidence as a ratio of the difference to the maximum possible difference
        let confidence = min(0.95, (scoreDifference / 1.5) + 0.5)
        
        // Calculate actual deltaE using color difference to reference colors
        let skinLabColor = ColorConverters.LabColor(L: CGFloat(skinL), a: CGFloat(skinA), b: CGFloat(skinB))
        let deltaEs = calculateDeltaEToSeasonReferences(labColor: skinLabColor)
        
        // Sort seasons by deltaE (lower is better)
        let sortedDeltaEs = deltaEs.sorted { $0.value < $1.value }
        
        let bestSeasonDeltaE = sortedDeltaEs[0].value
        let secondBestSeasonDeltaE = sortedDeltaEs[1].value
        
        // Calculate the difference between the deltaE values
        let deltaE = Float(secondBestSeasonDeltaE - bestSeasonDeltaE)

        return ClassificationResult(
            season: season,
            confidence: confidence,
            deltaEToNextClosest: deltaE,
            nextClosestSeason: secondBestSeason
        )
    }

    /// Calculate ΔE (color difference) between a given color and reference colors for each season
    /// Useful for analytics and threshold tuning
    func calculateDeltaEToSeasonReferences(labColor: ColorConverters.LabColor) -> [Season: CGFloat] {
        // Reference Lab colors for each season (based on typical skin tones)
        let referenceColors: [Season: ColorConverters.LabColor] = [
            .spring: ColorConverters.LabColor(L: 75.0, a: 10.0, b: 25.0),   // Warm, light, bright
            .summer: ColorConverters.LabColor(L: 70.0, a: -3.0, b: 10.0),   // Cool, light
            .autumn: ColorConverters.LabColor(L: 60.0, a: 8.0, b: 22.0),    // Warm, dark
            .winter: ColorConverters.LabColor(L: 55.0, a: -5.0, b: 5.0)     // Cool, dark
        ]

        // Calculate ΔE to each reference color using CIEDE2000 formula for better accuracy
        var deltaEs = [Season: CGFloat]()
        for (season, reference) in referenceColors {
            deltaEs[season] = labColor.deltaE2000(to: reference)
        }

        return deltaEs
    }

    /// Calculate ΔE using both methods (CIE76 and CIEDE2000) for comparison
    /// - Parameter labColor: The Lab color to compare
    /// - Returns: Dictionary with results from both methods for each season
    func compareColorDifferenceMethods(labColor: ColorConverters.LabColor) -> [Season: (cie76: CGFloat, ciede2000: CGFloat)] {
        // Reference Lab colors for each season (based on typical skin tones)
        let referenceColors: [Season: ColorConverters.LabColor] = [
            .spring: ColorConverters.LabColor(L: 75.0, a: 10.0, b: 25.0),   // Warm, light, bright
            .summer: ColorConverters.LabColor(L: 70.0, a: -3.0, b: 10.0),   // Cool, light
            .autumn: ColorConverters.LabColor(L: 60.0, a: 8.0, b: 22.0),    // Warm, dark
            .winter: ColorConverters.LabColor(L: 55.0, a: -5.0, b: 5.0)     // Cool, dark
        ]

        // Calculate using both methods
        var results = [Season: (cie76: CGFloat, ciede2000: CGFloat)]()
        for (season, reference) in referenceColors {
            let cie76 = labColor.deltaE(to: reference)
            let ciede2000 = labColor.deltaE2000(to: reference)
            results[season] = (cie76: cie76, ciede2000: ciede2000)
        }

        return results
    }

    // MARK: - Static helper methods

    /// Static helper to classify skin and hair colors into a season
    /// - Parameters:
    ///   - skinLab: Skin color in Lab space as a tuple
    ///   - hairLab: Hair color in Lab space as a tuple (optional)
    /// - Returns: Classification result
    static func classifySeason(
        skinLab: (L: CGFloat, a: CGFloat, b: CGFloat),
        hairLab: (L: CGFloat, a: CGFloat, b: CGFloat)? = nil
    ) -> ClassificationResult {
        // Create Lab color objects
        let skinLabColor = ColorConverters.LabColor(L: skinLab.L, a: skinLab.a, b: skinLab.b)
        var hairLabColor: ColorConverters.LabColor?
        if let hair = hairLab {
            hairLabColor = ColorConverters.LabColor(L: hair.L, a: hair.a, b: hair.b)
        }

        // Create classifier and classify
        let classifier = SeasonClassifier()
        return classifier.classify(skinColor: skinLabColor, hairColor: hairLabColor)
    }

    /// Calculate delta-E to all season reference colors using CIEDE2000
    /// - Parameter skinLab: Skin color in Lab space
    /// - Returns: Dictionary mapping seasons to delta-E values
    static func calculateDeltaEToAllSeasons(skinLab: ColorConverters.LabColor) -> [Season: CGFloat] {
        let classifier = SeasonClassifier()
        return classifier.calculateDeltaEToSeasonReferences(labColor: skinLab)
    }
}
