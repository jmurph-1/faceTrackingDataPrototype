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
        let brightMutedThreshold: Float
        let clearSoftThreshold: Float
        
        /// Default thresholds based on standard values
        static let `default` = Thresholds(
            warmCoolThreshold: 0.0,   // a* value in Lab: positive = warm, negative = cool
            brightMutedThreshold: 65.0, // L* value: higher = brighter, lower = muted
            clearSoftThreshold: 25.0   // Chroma (a*2 + b*2)^0.5: higher = clear, lower = soft
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
    
    /// Classify colors into one of the four seasons
    /// - Parameters:
    ///   - skinColor: The skin color in Lab color space
    ///   - hairColor: The hair color in Lab color space (optional)
    /// - Returns: Classification result with season and confidence metrics
    func classify(
        skinColor: ColorConverters.LabColor,
        hairColor: ColorConverters.LabColor? = nil
    ) -> ClassificationResult {
        
        // Calculate the scores for each season based on the skin color
        var seasonScores = [Season: Float]()
        
        // Extract Lab values from skin color
        let skinL = Float(skinColor.L)
        let skinA = Float(skinColor.a)
        let skinB = Float(skinColor.b)
        
        // Calculate chroma (color intensity)
        let skinChroma = sqrt(skinA * skinA + skinB * skinB)
        
        // Extract Lab values from hair color if available
        var hairL: Float = 0
        var hairA: Float = 0
        var hairB: Float = 0
        var hairChroma: Float = 0
        
        let useHairColor = hairColor != nil
        
        if let hair = hairColor {
            hairL = Float(hair.L)
            hairA = Float(hair.a)
            hairB = Float(hair.b)
            hairChroma = sqrt(hairA * hairA + hairB * hairB)
        }
        
        // Feature 1: Warm vs Cool (based on b* value)
        // Positive b* = blue/yellow, Negative b* = blue/cool
        let warmCoolValue = skinB
        let isWarm = warmCoolValue >= thresholds.warmCoolThreshold
        
        // Feature 2: Bright vs Muted (based on L* value)
        // High L* = bright, Low L* = muted
        let brightMutedValue = skinL
        let isBright = brightMutedValue > thresholds.brightMutedThreshold
        
        // Feature 3: Clear vs Soft (based on chroma)
        // High chroma = clear, Low chroma = soft
        let clearSoftValue = skinChroma
        let isClear = clearSoftValue > thresholds.clearSoftThreshold
        
        // Calculate scores for each season based on features
        for season in Season.allCases {
            var score: Float = 0
            
            switch season {
            case .spring:
                // Spring: Warm + Bright
                if isWarm { score += 1 }
                if isBright { score += 1 }
                if isClear { score += 0.5 }
                
            case .summer:
                // Summer: Cool + Bright + Soft
                if !isWarm { score += 1 }
                if isBright { score += 0.5 }
                if !isClear { score += 1 }
                
            case .autumn:
                // Autumn: Warm + Muted
                if isWarm { score += 1 }
                if !isBright { score += 1 }
                if !isClear { score += 0.5 }
                
            case .winter:
                // Winter: Cool + Clear
                if !isWarm { score += 1 }
                if isClear { score += 1 }
                if !isBright { score += 0.5 }
            }
            
            // Add hair color influence if available
            if useHairColor {
                let hairInfluenceFactor: Float = 0.3 // 30% influence from hair color
                
                // Adjust score based on hair color properties
                switch season {
                case .spring:
                    // Spring hair is typically warm and lighter
                    if hairA > 0 { score += 0.2 * hairInfluenceFactor }
                    if hairL > 50 { score += 0.2 * hairInfluenceFactor }
                    
                case .summer:
                    // Summer hair is typically ashy (cool) and medium to light
                    if hairA < 0 { score += 0.2 * hairInfluenceFactor }
                    if hairL > 40 && hairL < 70 { score += 0.2 * hairInfluenceFactor }
                    
                case .autumn:
                    // Autumn hair is typically warm and darker
                    if hairA > 0 { score += 0.2 * hairInfluenceFactor }
                    if hairL < 50 { score += 0.2 * hairInfluenceFactor }
                    
                case .winter:
                    // Winter hair is typically cool and very dark or very light
                    if hairA < 0 { score += 0.2 * hairInfluenceFactor }
                    if hairL < 30 || hairL > 80 { score += 0.2 * hairInfluenceFactor }
                }
            }
            
            seasonScores[season] = score
        }
        
        // Find the season with the highest score
        let sortedSeasons = seasonScores.sorted { $0.value > $1.value }
        let bestSeason = sortedSeasons[0].key
        let bestScore = sortedSeasons[0].value
        let secondBestSeason = sortedSeasons[1].key
        let secondBestScore = sortedSeasons[1].value
        
        // Calculate confidence and difference to next closest
        let maxPossibleScore: Float = useHairColor ? 3.0 : 2.5
        let confidence = bestScore / maxPossibleScore
        let deltaE = bestScore - secondBestScore
        
        return ClassificationResult(
            season: bestSeason,
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
            .spring: ColorConverters.LabColor(L: 75.0, a: 10.0, b: 25.0),   // Warm, bright peach
            .summer: ColorConverters.LabColor(L: 70.0, a: -3.0, b: 10.0),   // Cool, soft pink
            .autumn: ColorConverters.LabColor(L: 60.0, a: 8.0, b: 22.0),    // Warm, muted golden
            .winter: ColorConverters.LabColor(L: 65.0, a: -5.0, b: 5.0)     // Cool, clear olive
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
            .spring: ColorConverters.LabColor(L: 75.0, a: 10.0, b: 25.0),   // Warm, bright peach
            .summer: ColorConverters.LabColor(L: 70.0, a: -3.0, b: 10.0),   // Cool, soft pink
            .autumn: ColorConverters.LabColor(L: 60.0, a: 8.0, b: 22.0),    // Warm, muted golden
            .winter: ColorConverters.LabColor(L: 65.0, a: -5.0, b: 5.0)     // Cool, clear olive
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
} 
