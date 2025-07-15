//
//  PersonalizedSeasonData.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - SeasonDNA Support

/// Represents a season weight in DNA analysis
struct SeasonWeight: Codable {
    let season: String
    let weight: Float // 0.0 to 1.0
    
    init(season: String, weight: Float) {
        self.season = season
        self.weight = max(0.0, min(1.0, weight)) // Clamp to valid range
    }
    
    /// Weight as percentage string
    var percentageString: String {
        return "\(Int(weight * 100))%"
    }
}

/// Season DNA analysis showing primary/secondary/tertiary season influences
struct SeasonDNA: Codable {
    let primary: SeasonWeight
    let secondary: SeasonWeight?
    let tertiary: SeasonWeight?
    let explanation: String
    let classificationConfidence: Float
    let blendJustification: String?
    
    init(primary: SeasonWeight, 
         secondary: SeasonWeight? = nil, 
         tertiary: SeasonWeight? = nil,
         explanation: String,
         classificationConfidence: Float,
         blendJustification: String? = nil) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.explanation = explanation
        self.classificationConfidence = classificationConfidence
        self.blendJustification = blendJustification
    }
    
    /// True if this is a pure match (primary weight > 85% and no meaningful secondary)
    var isPureMatch: Bool {
        return primary.weight > 0.85 && (secondary?.weight ?? 0.0) < 0.15
    }
    
    /// User-friendly description of the DNA blend
    var blendDescription: String {
        if isPureMatch {
            return "Pure \(primary.season)"
        } else if let secondary = secondary {
            if let tertiary = tertiary {
                return "\(primary.season) with \(secondary.season) and \(tertiary.season) influences"
            } else {
                return "\(primary.season) with \(secondary.season) influence"
            }
        } else {
            return primary.season
        }
    }
    
    /// All seasons in the DNA blend
    var allSeasons: [SeasonWeight] {
        var seasons = [primary]
        if let secondary = secondary { seasons.append(secondary) }
        if let tertiary = tertiary { seasons.append(tertiary) }
        return seasons
    }
}

// MARK: - Enhanced Color Support

/// Enhanced color item with database-backed context
struct ColorItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let hexValue: String
    let usageContext: String
    let harmonyReason: String
    
    init(id: UUID = UUID(), 
         name: String, 
         hexValue: String, 
         usageContext: String, 
         harmonyReason: String) {
        self.id = id
        self.name = name
        self.hexValue = hexValue
        self.usageContext = usageContext
        self.harmonyReason = harmonyReason
    }
    
    /// Normalized hex value (lowercase with #)
    var normalizedHex: String {
        let cleaned = hexValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            return cleaned.lowercased()
        } else {
            return "#\(cleaned.lowercased())"
        }
    }
}

/// Enhanced color recommendation with detailed context
struct DetailedColorRecommendation: Codable {
    let description: String
    let colors: [ColorItem]
    let priority: String
    let usageInstructions: String
    let categoryExplanation: String
    
    init(description: String,
         colors: [ColorItem],
         priority: String,
         usageInstructions: String,
         categoryExplanation: String) {
        self.description = description
        self.colors = colors
        self.priority = priority
        self.usageInstructions = usageInstructions
        self.categoryExplanation = categoryExplanation
    }
}

/// Enhanced color recommendations with detailed context
struct EnhancedColorRecommendations: Codable {
    let bestNeutrals: DetailedColorRecommendation
    let bestAccents: DetailedColorRecommendation
    let bestBaseColors: DetailedColorRecommendation
    let lipColors: DetailedColorRecommendation
    let eyeColors: DetailedColorRecommendation
    let hairColorSuggestions: DetailedColorRecommendation?
    
    init(bestNeutrals: DetailedColorRecommendation,
         bestAccents: DetailedColorRecommendation,
         bestBaseColors: DetailedColorRecommendation,
         lipColors: DetailedColorRecommendation,
         eyeColors: DetailedColorRecommendation,
         hairColorSuggestions: DetailedColorRecommendation? = nil) {
        self.bestNeutrals = bestNeutrals
        self.bestAccents = bestAccents
        self.bestBaseColors = bestBaseColors
        self.lipColors = lipColors
        self.eyeColors = eyeColors
        self.hairColorSuggestions = hairColorSuggestions
    }
}

// MARK: - Main PersonalizedSeasonData

/// Represents personalized season data generated by LLM based on user's specific characteristics
struct PersonalizedSeasonData: Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for this personalization
    let id: UUID
    
    /// Date when personalization was created
    let createdDate: Date
    
    /// User's assigned season
    let baseSeason: String
    
    /// Personalized tagline for the user
    let personalizedTagline: String
    
    /// User's unique characteristics description
    let userCharacteristics: String
    
    /// Personalized overview text
    let personalizedOverview: String
    
    /// Color recommendations specific to the user
    let colorRecommendations: PersonalizedColorRecommendations
    
    /// Styling advice tailored to the user
    let stylingAdvice: PersonalizedStylingAdvice
    
    /// Best colors from the palette for this specific user
    let emphasizedColors: [String] // Hex color values
    
    /// Colors to especially avoid for this user
    let colorsToAvoid: [String] // Hex color values
    
    /// Confidence score for the personalization (0.0 - 1.0)
    let confidence: Float
    
    /// Original analysis result ID this personalization is based on
    let analysisResultId: UUID?
    
    // MARK: - Enhanced Properties (Optional for backward compatibility)
    
    /// Season DNA analysis with primary/secondary/tertiary influences
    let seasonDNAData: SeasonDNA?
    
    /// Enhanced color recommendations with database-backed context
    let enhancedColorData: EnhancedColorRecommendations?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        createdDate: Date = Date(),
        baseSeason: String,
        personalizedTagline: String,
        userCharacteristics: String,
        personalizedOverview: String,
        colorRecommendations: PersonalizedColorRecommendations,
        stylingAdvice: PersonalizedStylingAdvice,
        emphasizedColors: [String],
        colorsToAvoid: [String],
        confidence: Float,
        analysisResultId: UUID? = nil,
        seasonDNAData: SeasonDNA? = nil,
        enhancedColorData: EnhancedColorRecommendations? = nil
    ) {
        self.id = id
        self.createdDate = createdDate
        self.baseSeason = baseSeason
        self.personalizedTagline = personalizedTagline
        self.userCharacteristics = userCharacteristics
        self.personalizedOverview = personalizedOverview
        self.colorRecommendations = colorRecommendations
        self.stylingAdvice = stylingAdvice
        self.emphasizedColors = emphasizedColors
        self.colorsToAvoid = colorsToAvoid
        self.confidence = confidence
        self.analysisResultId = analysisResultId
        self.seasonDNAData = seasonDNAData
        self.enhancedColorData = enhancedColorData
    }
}

// MARK: - PersonalizedColorRecommendations

struct PersonalizedColorRecommendations: Codable {
    
    /// Best neutral colors for this user
    let bestNeutrals: ColorRecommendation
    
    /// Best accent colors for this user
    let bestAccents: ColorRecommendation
    
    /// Base colors that work particularly well
    let bestBaseColors: ColorRecommendation
    
    /// Lip color recommendations
    let lipColors: ColorRecommendation
    
    /// Eye makeup color recommendations
    let eyeColors: ColorRecommendation
    
    /// Hair color suggestions (if applicable)
    let hairColorSuggestions: ColorRecommendation?
}

// MARK: - ColorRecommendation

struct ColorRecommendation: Codable {
    
    /// Description of why these colors work for the user
    let description: String
    
    /// Recommended hex color values
    let colors: [String]
    
    /// Priority level (high, medium, low)
    let priority: String
    
    /// Specific usage instructions
    let usageInstructions: String
}

// MARK: - PersonalizedStylingAdvice

struct PersonalizedStylingAdvice: Codable {
    
    /// Clothing style recommendations
    let clothingAdvice: StylingRecommendation
    
    /// Accessory recommendations
    let accessoryAdvice: StylingRecommendation
    
    /// Pattern and print recommendations
    let patternAdvice: StylingRecommendation
    
    /// Metal recommendations (gold, silver, etc.)
    let metalAdvice: StylingRecommendation
    
    /// Special considerations for this user
    let specialConsiderations: String
}

// MARK: - StylingRecommendation

struct StylingRecommendation: Codable {
    
    /// Main recommendation text
    let recommendation: String
    
    /// Specific tips
    let tips: [String]
    
    /// Things to avoid
    let avoid: [String]
    
    /// Examples
    let examples: [String]
}

// MARK: - Convenience Extensions

extension PersonalizedSeasonData {
    
    /// Get emphasized colors as UIColor objects
    var emphasizedUIColors: [UIColor] {
        return emphasizedColors.compactMap { hex in
            // Use Color extension first, then convert to UIColor
            let color = Color(hex: hex)
            return UIColor(color)
        }
    }
    
    /// Get colors to avoid as UIColor objects
    var colorsToAvoidUIColors: [UIColor] {
        return colorsToAvoid.compactMap { hex in
            // Use Color extension first, then convert to UIColor
            let color = Color(hex: hex)
            return UIColor(color)
        }
    }
    
    /// Get formatted creation date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
    
    /// Get confidence as percentage
    var confidencePercentage: String {
        return "\(Int(confidence * 100))%"
    }
    
    /// Get the display name for the season (handles both 4-season and 12-season names)
    var displaySeasonName: String {
        // If baseSeason is already a 12-season name, use it as is
        if baseSeason.contains(" ") {
            return baseSeason
        }
        
        // Otherwise, map 4-season to 12-season name
        switch baseSeason.lowercased() {
        case "spring":
            return "True Spring"
        case "summer":
            return "True Summer"
        case "autumn":
            return "True Autumn"
        case "winter":
            return "True Winter"
        default:
            return baseSeason
        }
    }
    
    /// Get Season DNA with intelligent fallback creation
    var seasonDNA: SeasonDNA {
        if let existingDNA = seasonDNAData {
            return existingDNA
        }
        
        // Create fallback DNA from existing data
        return createFallbackSeasonDNA()
    }
    
    /// Check if enhanced color data is available
    var hasEnhancedColorData: Bool {
        return enhancedColorData != nil
    }
    
    // MARK: - Private Helpers
    
    private func createFallbackSeasonDNA() -> SeasonDNA {
        let seasonName = displaySeasonName
        
        // Parse season name for potential blend detection
        let components = seasonName.components(separatedBy: " ")
        
        if components.count > 1 {
            let modifier = components.first?.lowercased()
            let baseSeason = components.dropFirst().joined(separator: " ")
            
            // Detect potential secondary season based on modifier
            var secondarySeason: SeasonWeight? = nil
            var primaryWeight: Float = 0.85
            
            switch modifier {
            case "soft":
                secondarySeason = SeasonWeight(season: detectSoftSecondary(baseSeason), weight: 0.15)
            case "clear", "bright":
                secondarySeason = SeasonWeight(season: detectClearSecondary(baseSeason), weight: 0.15)
            case "light":
                secondarySeason = SeasonWeight(season: detectLightSecondary(baseSeason), weight: 0.15)
            case "dark", "deep":
                secondarySeason = SeasonWeight(season: detectDarkSecondary(baseSeason), weight: 0.15)
            case "warm":
                secondarySeason = SeasonWeight(season: detectWarmSecondary(baseSeason), weight: 0.15)
            case "cool":
                secondarySeason = SeasonWeight(season: detectCoolSecondary(baseSeason), weight: 0.15)
            default:
                primaryWeight = 1.0 // Pure match
            }
            
            return SeasonDNA(
                primary: SeasonWeight(season: seasonName, weight: primaryWeight),
                secondary: secondarySeason,
                explanation: secondarySeason != nil ? 
                    "Your coloring shows strong \(seasonName) characteristics with subtle influences from \(secondarySeason!.season)." :
                    "Your coloring is a pure \(seasonName) type with consistent characteristics.",
                classificationConfidence: confidence,
                blendJustification: secondarySeason != nil ? 
                    "The \(modifier ?? "") quality in your coloring suggests some overlap with \(secondarySeason!.season) tones." : nil
            )
        } else {
            // Simple season name, create pure match
            return SeasonDNA(
                primary: SeasonWeight(season: seasonName, weight: 1.0),
                explanation: "Your coloring is a classic \(seasonName) type with consistent characteristics.",
                classificationConfidence: confidence
            )
        }
    }
    
    private func detectSoftSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "summer": return "Soft Autumn"
        case "autumn": return "Soft Summer"
        case "spring": return "Light Spring"
        case "winter": return "Dark Winter"
        default: return "True \(baseSeason)"
        }
    }
    
    private func detectClearSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "spring": return "Clear Winter"
        case "winter": return "Clear Spring"
        case "summer": return "Light Summer"
        case "autumn": return "Dark Autumn"
        default: return "True \(baseSeason)"
        }
    }
    
    private func detectLightSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "spring": return "Light Summer"
        case "summer": return "Light Spring"
        case "autumn": return "Warm Autumn"
        case "winter": return "Cool Winter"
        default: return "True \(baseSeason)"
        }
    }
    
    private func detectDarkSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "autumn": return "Dark Winter"
        case "winter": return "Dark Autumn"
        case "summer": return "Deep Summer"
        case "spring": return "Warm Spring"
        default: return "True \(baseSeason)"
        }
    }
    
    private func detectWarmSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "spring": return "Warm Autumn"
        case "autumn": return "Warm Spring"
        case "summer": return "True Summer"
        case "winter": return "True Winter"
        default: return "True \(baseSeason)"
        }
    }
    
    private func detectCoolSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "summer": return "Cool Winter"
        case "winter": return "Cool Summer"
        case "spring": return "True Spring"
        case "autumn": return "True Autumn"
        default: return "True \(baseSeason)"
        }
    }
}

// MARK: - Core Data Support

extension PersonalizedSeasonData {
    
    /// Convert to JSON data for Core Data storage
    func toJSONData() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    /// Create from JSON data stored in Core Data
    static func fromJSONData(_ data: Data) -> PersonalizedSeasonData? {
        return try? JSONDecoder().decode(PersonalizedSeasonData.self, from: data)
    }
}

