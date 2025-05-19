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

        // Lightness catgory
        let lightnessCategoryResult = lightnessCategory(from: skinL)
        print("Calc: Lightness Category:", lightnessCategoryResult, " ", skinL)
        
        // Chroma category
        let chromaCategoryResult = chromaCategory(chroma: skinChroma)
        print("Calc: Chroma Category:", chromaCategoryResult, " ", skinChroma)
        
        // Hue Angle
        let hueDegrees = (atan2(skinB, skinA)) * 180 / .pi
        print("Calc: Hue Degrees:", hueDegrees)
        
        // Undertone
        let undertoneResult = undertone(from: hueDegrees)
        print("Calc: Undertone:", undertoneResult, "\n")
        
        // Updated season classification
        let updatedSeasonClassification = classifySeason(lightness: skinL, chroma: skinChroma, hue: hueDegrees)
        print("Calc: 12 Season:", updatedSeasonClassification)
        
        // New seasons with confidence
        let result = classifySeasonWithConfidence(lightness: skinL, chroma: skinChroma, hue: hueDegrees)
        print("Season: \(result.season), confidence: \(result.confidence * 100)%")
        
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
    
    // Calculate undertone based on hue degrees
    func undertone(from hue: Float) -> String {
        switch hue {
        case 30..<90:
            return "warm"       // yellow → orange → red
        case 180..<300:
            return "cool"       // blue → purple
        case 90..<180, 300..<360:
            return "neutral"    // desaturated or ambiguous zones
        default:
            return "neutral"    // just in case
        }
    }
    
    func lightnessCategory(from lightness: Float) -> String {
        switch lightness {
        case 65.0...100.0:
            return "light"   // Overall brightness; light skin/hair
        case 45.0..<65.0:
            return "medium"  // Balanced tones; neither extreme
        case 15.0..<45.0:
            return "dark"    // Lower lightness; deeper contrast
        default:
            return "unknown" // Out of expected LAB range
        }
    }
    
    func chromaCategory(chroma: Float) -> String {
        switch chroma {
        case ..<30.0:
            return "soft"    // Muted / soft tones
        case 30.0...50.0:
            return "medium"  // Balanced saturation
        case let val where val > 50.0:
            return "bright"  // Vivid, jewel-like tones
        default:
            return "unknown" // Shouldn't happen for C* ≥ 0
        }
    }
    
    // Updated 12 seasons assignment
    func classifySeason(lightness: Float, chroma: Float, hue: Float) -> String {
        // Light Spring: 65–90, C 40–55, hue 60°–90°
        if lightness >= 65 && lightness <= 90 &&
           chroma >= 40 && chroma <= 55 &&
           hue >= 60 && hue <= 90
        {
            return "Light Spring"
        }
        // True Spring: 55–70, C 50–65, hue 50°–80°
        else if lightness >= 55 && lightness <= 70 &&
                chroma >= 50 && chroma <= 65 &&
                hue >= 50 && hue <= 80
        {
            return "True Spring"
        }
        // Bright Spring: 60–80, C >55, hue 50°–90°
        else if lightness >= 60 && lightness <= 80 &&
                chroma > 55 &&
                hue >= 50 && hue <= 90
        {
            return "Bright Spring"
        }
        // Light Summer: 65–90, C 30–45, hue 180°–260°
        else if lightness >= 65 && lightness <= 90 &&
                chroma >= 30 && chroma <= 45 &&
                hue >= 180 && hue <= 260
        {
            return "Light Summer"
        }
        // True Summer: 55–70, C 30–45, hue 200°–260°
        else if lightness >= 55 && lightness <= 70 &&
                chroma >= 30 && chroma <= 45 &&
                hue >= 200 && hue <= 260
        {
            return "True Summer"
        }
        // Soft Summer: 50–65, C <30, hue 220°–280°
        else if lightness >= 50 && lightness <= 65 &&
                chroma < 30 &&
                hue >= 220 && hue <= 280
        {
            return "Soft Summer"
        }
        // Soft Autumn: 45–60, C <30, hue 60°–110°
        else if lightness >= 45 && lightness <= 60 &&
                chroma < 30 &&
                hue >= 60 && hue <= 110
        {
            return "Soft Autumn"
        }
        // True Autumn: 40–55, C 35–50, hue 60°–100°
        else if lightness >= 40 && lightness <= 55 &&
                chroma >= 35 && chroma <= 50 &&
                hue >= 60 && hue <= 100
        {
            return "True Autumn"
        }
        // Deep Autumn: 30–50, C 30–45, hue 60°–100°
        else if lightness >= 30 && lightness <= 50 &&
                chroma >= 30 && chroma <= 45 &&
                hue >= 60 && hue <= 100
        {
            return "Deep Autumn"
        }
        // Deep Winter: 25–50, C 40–60, hue 200°–260°
        else if lightness >= 25 && lightness <= 50 &&
                chroma >= 40 && chroma <= 60 &&
                hue >= 200 && hue <= 260
        {
            return "Deep Winter"
        }
        // True Winter: 35–60, C 50–65, hue 220°–280°
        else if lightness >= 35 && lightness <= 60 &&
                chroma >= 50 && chroma <= 65 &&
                hue >= 220 && hue <= 280
        {
            return "True Winter"
        }
        // Bright Winter: 45–70, C >55, hue 220°–280°
        else if lightness >= 45 && lightness <= 70 &&
                chroma > 55 &&
                hue >= 220 && hue <= 280
        {
            return "Bright Winter"
        }
        // Fallback
        else {
            return "Unknown"
        }
    }
    
    func dimensionScore(value: Float, rangeMin: Float, rangeMax: Float) -> Float {
        let mid    = (rangeMin + rangeMax) / 2.0
        let half   = (rangeMax - rangeMin) / 2.0
        guard half > 0 else { return value == mid ? 1.0 : 0.0 }
        let dist   = abs(value - mid)
        return Swift.max(0.0, 1 - (dist / half))
    }

    /// Encapsulates one season's ideal ranges
    struct SeasonRule {
        let name        : String
        let lRange      : ClosedRange<Double>
        let cRange      : ClosedRange<Double>
        let hueRange    : ClosedRange<Double>
    }

    let seasonRules: [SeasonRule] = [
        SeasonRule(name: "Light Spring",
                   lRange: 65...90, cRange: 40...55, hueRange: 60...90),
        SeasonRule(name: "True Spring",
                   lRange: 55...70, cRange: 50...65, hueRange: 50...80),
        SeasonRule(name: "Bright Spring",
                   lRange: 60...80, cRange: 55...100, hueRange: 50...90),
                   
        SeasonRule(name: "Light Summer",
                   lRange: 65...90, cRange: 30...45, hueRange: 180...260),
        SeasonRule(name: "True Summer",
                   lRange: 55...70, cRange: 30...45, hueRange: 200...260),
        SeasonRule(name: "Soft Summer",
                   lRange: 50...65, cRange: 0...30,  hueRange: 220...280),
                   
        SeasonRule(name: "Soft Autumn",
                   lRange: 45...60, cRange: 0...30,  hueRange: 60...110),
        SeasonRule(name: "True Autumn",
                   lRange: 40...55, cRange: 35...50, hueRange: 60...100),
        SeasonRule(name: "Deep Autumn",
                   lRange: 30...50, cRange: 30...45, hueRange: 60...100),
                   
        SeasonRule(name: "Deep Winter",
                   lRange: 25...50, cRange: 40...60, hueRange: 200...260),
        SeasonRule(name: "True Winter",
                   lRange: 35...60, cRange: 50...65, hueRange: 220...280),
        SeasonRule(name: "Bright Winter",
                   lRange: 45...70, cRange: 55...100, hueRange: 220...280)
    ]

    /// Returns the best‐matching season plus a confidence [0…1]
    func classifySeasonWithConfidence(lightness: Float, chroma: Float, hue: Float) -> (season: String, confidence: Float) {
        var bestSeason   = seasonRules[0].name
        var bestScore: Float = -1.0
        
        for rule in seasonRules {
            let lScore = dimensionScore(value: lightness,
                                         rangeMin: Float(rule.lRange.lowerBound),
                                         rangeMax: Float(rule.lRange.upperBound))
            let cScore = dimensionScore(value: chroma,
                                         rangeMin: Float(rule.cRange.lowerBound),
                                         rangeMax: Float(rule.cRange.upperBound))
            let hScore = dimensionScore(value: hue,
                                         rangeMin: Float(rule.hueRange.lowerBound),
                                         rangeMax: Float(rule.hueRange.upperBound))
            
            let avgScore = (lScore + cScore + hScore) / 3.0  // 3.0 literal converts to Float
            if avgScore > bestScore {
                bestScore   = avgScore
                bestSeason  = rule.name
            }
        }
        
        return (bestSeason, bestScore)
    }
}
