//
//  PersonalizedSeasonViewModel.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import UIKit
import SwiftUI
import Combine

class PersonalizedSeasonViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var personalizedData: PersonalizedSeasonData
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Properties

    private let personalizationService = PersonalizationService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(personalizedData: PersonalizedSeasonData) {
        self.personalizedData = personalizedData
    }

    // MARK: - Computed Properties

    var seasonName: String {
        return personalizedData.displaySeasonName
    }

    var personalizedTagline: String {
        return personalizedData.personalizedTagline
    }

    var userCharacteristics: String {
        return personalizedData.userCharacteristics
    }

    var personalizedOverview: String {
        return personalizedData.personalizedOverview
    }

    var emphasizedColors: [Color] {
        return personalizedData.emphasizedUIColors.map { Color($0) }
    }

    var colorsToAvoid: [Color] {
        return personalizedData.colorsToAvoidUIColors.map { Color($0) }
    }

    var confidence: String {
        return personalizedData.confidencePercentage
    }

    var formattedDate: String {
        return personalizedData.formattedDate
    }

    // MARK: - DNA-Specific Properties

    /// Get Season DNA with intelligent fallback
    var seasonDNA: SeasonDNA {
        return personalizedData.seasonDNA
    }

    /// Check if this is a DNA blend (not a pure season)
    var isDNABlended: Bool {
        return !seasonDNA.isPureMatch
    }

    /// Get DNA confidence level description
    var dnaConfidenceLevel: String {
        let confidence = seasonDNA.classificationConfidence
        if confidence >= 0.9 {
            return "Very High"
        } else if confidence >= 0.8 {
            return "High"
        } else if confidence >= 0.7 {
            return "Medium"
        } else {
            return "Moderate"
        }
    }

    /// Get DNA confidence color for UI
    var dnaConfidenceColor: Color {
        let confidence = seasonDNA.classificationConfidence
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.8 {
            return .green.opacity(0.8)
        } else if confidence >= 0.7 {
            return .orange
        } else {
            return .orange.opacity(0.7)
        }
    }

    /// Get colors for DNA ring chart visualization
    var dnaVisualizationColors: (primary: Color, secondary: Color?, tertiary: Color?) {
        let primaryColor = Color.seasonAccentColor(for: seasonDNA.primary.season)

        let secondaryColor = seasonDNA.secondary != nil ?
            Color.seasonAccentColor(for: seasonDNA.secondary!.season) : nil

        let tertiaryColor = seasonDNA.tertiary != nil ?
            Color.seasonAccentColor(for: seasonDNA.tertiary!.season) : nil

        return (primaryColor, secondaryColor, tertiaryColor)
    }

    // MARK: - Color Recommendations

    var bestNeutrals: ColorRecommendation {
        return personalizedData.colorRecommendations.bestNeutrals
    }

    var bestAccents: ColorRecommendation {
        return personalizedData.colorRecommendations.bestAccents
    }

    var bestBaseColors: ColorRecommendation {
        return personalizedData.colorRecommendations.bestBaseColors
    }


    var hairColorSuggestions: ColorRecommendation? {
        return personalizedData.colorRecommendations.hairColorSuggestions
    }


    // MARK: - Helper Methods

    /// Get colors for a specific recommendation as SwiftUI Color objects
    /// - Parameter recommendation: The color recommendation
    /// - Returns: Array of SwiftUI Color objects
    func getColorsForRecommendation(_ recommendation: ColorRecommendation) -> [Color] {
        #if DEBUG
        print("🎨 Processing colors for recommendation: \(recommendation.description)")
        print("🎨 Input colors: \(recommendation.colors)")
        #endif
        
        let processedColors = recommendation.colors.compactMap { hexString in
            if let uiColor = UIColor(hex: hexString) {
                #if DEBUG
                print("✅ Successfully parsed: \(hexString)")
                #endif
                return Color(uiColor)
            } else {
                #if DEBUG
                print("❌ Failed to parse: \(hexString)")
                #endif
                return nil
            }
        }
        
        #if DEBUG
        print("🎨 Output: \(processedColors.count) valid colors")
        #endif
        
        return processedColors
    }

    /// Get all color recommendations grouped by category
    /// - Returns: Dictionary with category names as keys and recommendations as values
    func getAllColorRecommendations() -> [String: ColorRecommendation] {
        #if DEBUG
        print("🔍 getAllColorRecommendations called:")
        print("   Best Neutrals: \(bestNeutrals.colors.count) colors")
        print("   Best Accents: \(bestAccents.colors.count) colors")
        print("   Best Base Colors: \(bestBaseColors.colors.count) colors")
        #endif
        
        return [
            "Best Neutrals": bestNeutrals,
            "Best Accents": bestAccents,
            "Best Base Colors": bestBaseColors
        ]
    }


    /// Check if personalization data is high confidence
    /// - Returns: True if confidence is above 75%
    var isHighConfidence: Bool {
        return personalizedData.confidence > 0.75
    }

    /// Get color priority level as an integer for sorting
    /// - Parameter recommendation: The color recommendation
    /// - Returns: Priority as integer (1 = high, 2 = medium, 3 = low)
    func getPriorityLevel(for recommendation: ColorRecommendation) -> Int {
        switch recommendation.priority.lowercased() {
        case "high":
            return 1
        case "medium":
            return 2
        case "low":
            return 3
        default:
            return 2 // Default to medium
        }
    }

    /// Get sorted color recommendations by priority
    /// - Returns: Array of tuples with category name and recommendation, sorted by priority
    func getSortedColorRecommendations() -> [(String, ColorRecommendation)] {
        let recommendations = getAllColorRecommendations()
        return recommendations.sorted { first, second in
            let firstPriority = getPriorityLevel(for: first.value)
            let secondPriority = getPriorityLevel(for: second.value)
            return firstPriority < secondPriority
        }
    }

    /// Update personalized data (useful for refreshing from Core Data)
    /// - Parameter newData: Updated personalized season data
    func updatePersonalizedData(_ newData: PersonalizedSeasonData) {
        DispatchQueue.main.async {
            self.personalizedData = newData
        }
    }

    /// Clear any error state
    func clearError() {
        DispatchQueue.main.async {
            self.error = nil
        }
    }

    // MARK: - Metal Recommendations

    /// Compute personalized metal recommendations based on season data
    var personalizedMetals: [MetalRecommendation] {
        var metalFinishCombinations: [String: [MetalRecommendation.FinishOption]] = [:]
        var metalSeasonSources: [String: Set<String>] = [:]
        var primarySeasonMetals: Set<String> = [] // Track metals from primary season
        var metals: [MetalRecommendation] = [] // Declare metals array at the start

        // First, process primary season to get list of allowed metals
        guard let primarySeasonData = loadSeasonData(for: personalizedData.baseSeason) else {
            return []
        }
        
        // Get list of metals that are explicitly marked as "bad" in primary season
        let badMetals: [String] = {
            if let metalTypes = primarySeasonData.styling.metalsAndAccessories?.metals?.type {
                return metalTypes.filter { $0.value == "bad" }
                    .map { $0.key.lowercased() }
            }
            return []
        }()
        
        let primaryFinishOptions = extractFinishOptionsFromSeason(primarySeasonData, 
                                                                seasonSource: personalizedData.baseSeason, 
                                                                isPrimarySeason: true)
        
        // Store primary season metals for reference
        primarySeasonMetals = Set(primaryFinishOptions.keys)
        
        // Add primary season metals to our collections
        for (metalType, finishes) in primaryFinishOptions {
            metalFinishCombinations[metalType] = finishes
            metalSeasonSources[metalType] = [personalizedData.baseSeason]
        }

        // Then process secondary season only (skip tertiary) if DNA blended
        if isDNABlended, let secondarySeason = seasonDNA.secondary?.season {
            guard let seasonData = loadSeasonData(for: secondarySeason) else { return [] }
            
            // Get only "great" metals from secondary season, but mark them as "good"
            let secondaryFinishOptions = extractFinishOptionsFromSeason(seasonData, 
                                                                      seasonSource: secondarySeason, 
                                                                      isPrimarySeason: false)
            
            for (metalType, finishes) in secondaryFinishOptions {
                // Skip if this metal is marked as "bad" in primary season
                if badMetals.contains(metalType.lowercased()) {
                    continue
                }
                
                if metalFinishCombinations[metalType] == nil {
                    metalFinishCombinations[metalType] = []
                    metalSeasonSources[metalType] = []
                }
                metalFinishCombinations[metalType]!.append(contentsOf: finishes)
                metalSeasonSources[metalType]!.insert(secondarySeason)
            }
        }

        // Convert to MetalRecommendation objects
        for (metalType, finishes) in metalFinishCombinations {
            let seasonSources = Array(metalSeasonSources[metalType] ?? [])
            
            // Determine overall priority:
            // - If it's from primary season, use its original priority
            // - If it's from secondary season only, mark as "good"
            let isPrimarySeasonMetal = primarySeasonMetals.contains(metalType)
            let bestFinishPriority = finishes.max { $0.priority.rawValue < $1.priority.rawValue }?.priority ?? .good
            let priority: MetalRecommendation.MetalPriority = isPrimarySeasonMetal ? bestFinishPriority : .good

            let metalRecommendation = MetalRecommendation(
                name: metalType,
                availableFinishes: finishes,
                priority: priority,
                seasonSources: seasonSources
            )

            metals.append(metalRecommendation)
        }

        // Sort metals: "great" first, then "good", then alphabetically within each group
        return metals.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority == .great
            }
            return lhs.name < rhs.name
        }.deduplicated
    }

    /// Check if there are metal recommendations available
    var hasMetalRecommendations: Bool {
        !personalizedMetals.isEmpty
    }

    // MARK: - Enhanced Color Methods

    /// Get best colors with database context
    /// - Returns: Array of ColorItem with rich context information
    func getBestColorsWithContext() -> [ColorItem] {
        if personalizedData.hasEnhancedColorData,
           let enhancedData = personalizedData.enhancedColorData {
            return enhancedData.bestNeutrals.colors + enhancedData.bestAccents.colors
        } else {
            // Fallback: Create ColorItems from basic hex values using database lookup
            return personalizedData.emphasizedColors.compactMap { hexValue in
                createColorItemFromHex(hexValue)
            }
        }
    }

    /// Get colors to avoid with database context
    /// - Returns: Array of ColorItem for colors to avoid
    func getColorsToAvoidWithContext() -> [ColorItem] {
        return personalizedData.colorsToAvoid.compactMap { hexValue in
            createColorItemFromHex(hexValue, isAvoidColor: true)
        }
    }

    /// Get enhanced color recommendations by category
    /// - Returns: Dictionary with category names and ColorItem arrays
    func getEnhancedColorRecommendations() -> [String: [ColorItem]] {
        if personalizedData.hasEnhancedColorData,
           let enhancedData = personalizedData.enhancedColorData {
            return [
                "Best Neutrals": enhancedData.bestNeutrals.colors,
                "Best Accents": enhancedData.bestAccents.colors,
                "Best Base Colors": enhancedData.bestBaseColors.colors
            ]
        } else {
            // Fallback: Generate ColorItems from basic recommendations
            return [
                "Best Neutrals": bestNeutrals.colors.compactMap { createColorItemFromHex($0) },
                "Best Accents": bestAccents.colors.compactMap { createColorItemFromHex($0) },
                "Best Base Colors": bestBaseColors.colors.compactMap { createColorItemFromHex($0) }
            ]
        }
    }

    /// Get DNA-based color recommendations
    /// - Parameter category: Optional category filter
    /// - Returns: Array of ColorItem based on Season DNA
    func getDNABasedColorRecommendations(category: String? = nil) -> [ColorItem] {
        let colorDB = ColorDatabaseManager.shared
        let dnaColors = colorDB.getRecommendedColors(for: seasonDNA, category: category, limit: 12)

        return dnaColors.map { colorData in
            colorData.toColorItem(
                usageContext: generateUsageContext(for: colorData, category: category),
                harmonyReason: generateHarmonyReason(for: colorData)
            )
        }
    }

    /// Get full palette colors for all seasons in the user's DNA
    /// - Returns: Array of ColorItem representing the complete palette
    func getFullPaletteColors() -> [ColorItem] {
        let colorDB = ColorDatabaseManager.shared
        var combinedColors: [ColorData] = []

        // Always include primary season colors
        combinedColors.append(contentsOf: colorDB.getColors(for: seasonDNA.primary.season))

        // Include secondary and tertiary if available
        if let secondary = seasonDNA.secondary?.season {
            combinedColors.append(contentsOf: colorDB.getColors(for: secondary))
        }

        if let tertiary = seasonDNA.tertiary?.season {
            combinedColors.append(contentsOf: colorDB.getColors(for: tertiary))
        }

        // Build set of recommended color hex values for highlighting
        var recommendedHexes: Set<String> = []
        if personalizedData.hasEnhancedColorData,
           let enhanced = personalizedData.enhancedColorData {
            let recommendedItems = enhanced.bestNeutrals.colors +
                                  enhanced.bestAccents.colors +
                                  enhanced.bestBaseColors.colors
            recommendedHexes = Set(recommendedItems.map { $0.normalizedHex })
        } else {
            let hexes = bestNeutrals.colors + bestAccents.colors + bestBaseColors.colors
            recommendedHexes = Set(hexes.map { normalizeHex($0) })
        }

        // Convert to ColorItems, marking those that are recommended
        var seenHexes: Set<String> = []
        var colorItems: [ColorItem] = []

        for colorData in combinedColors {
            let normalized = colorData.normalizedHex
            if seenHexes.contains(normalized) { continue }
            seenHexes.insert(normalized)
            let isRecommended = recommendedHexes.contains(normalized)
            colorItems.append(colorData.toColorItem(isRecommended: isRecommended))
        }

        return colorItems
    }

    // MARK: - Private Helper Methods

    private func createColorItemFromHex(_ hexValue: String, isAvoidColor: Bool = false) -> ColorItem? {
        // First, try to get color data from database
        if let colorData = ColorDatabaseManager.shared.getColorData(for: hexValue) {
            let usageContext = isAvoidColor ?
                "Avoid this color as it may wash you out" :
                "Perfect for your \(seasonName) coloring"
            let harmonyReason = isAvoidColor ?
                "May clash with your natural undertones" :
                "Harmonizes beautifully with your Season DNA"

            return colorData.toColorItem(
                usageContext: usageContext,
                harmonyReason: harmonyReason
            )
        } else {
            // Fallback: Create generic ColorItem
            let colorName = generateGenericColorName(for: hexValue)
            let usageContext = isAvoidColor ?
                "Avoid this color" :
                "Complements your coloring"
            let harmonyReason = isAvoidColor ?
                "May not suit your undertones" :
                "Works well with your Season DNA"

            return ColorItem(
                name: colorName,
                hexValue: hexValue,
                usageContext: usageContext,
                harmonyReason: harmonyReason
            )
        }
    }

    private func generateGenericColorName(for hexValue: String) -> String {
        // Simple color name generation based on hex value
        guard let uiColor = UIColor(hex: hexValue) else { return "Unknown Color" }

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)

        let redComponent = Int(red * 255)
        let greenComponent = Int(green * 255)
        let blueComponent = Int(blue * 255)

        // Basic color classification
        if redComponent > 200 && greenComponent < 100 && blueComponent < 100 {
            return "Red Tone"
        } else if greenComponent > 200 && redComponent < 100 && blueComponent < 100 {
            return "Green Tone"
        } else if blueComponent > 200 && redComponent < 100 && greenComponent < 100 {
            return "Blue Tone"
        } else if redComponent > 200 && greenComponent > 200 && blueComponent < 100 {
            return "Yellow Tone"
        } else if redComponent > 150 && greenComponent > 150 && blueComponent > 150 {
            return "Light Neutral"
        } else if redComponent < 100 && greenComponent < 100 && blueComponent < 100 {
            return "Dark Neutral"
        } else {
            return "Mixed Tone"
        }
    }

    private func generateUsageContext(for colorData: ColorData, category: String?) -> String {
        if let category = category {
            return "Perfect \(category.lowercased()) color for your DNA blend"
        } else {
            return "Ideal for your \(seasonName) coloring"
        }
    }

    private func generateHarmonyReason(for colorData: ColorData) -> String {
        if isDNABlended {
            return "Harmonizes with your \(seasonDNA.primary.season) primary and \(seasonDNA.secondary?.season ?? "pure") influences"
        } else {
            return "Perfect match for your pure \(seasonDNA.primary.season) coloring"
        }
    }

    /// Normalize a hex string to include leading '#' and lowercase letters
    private func normalizeHex(_ hex: String) -> String {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return cleaned.hasPrefix("#") ? cleaned : "#\(cleaned)"
    }

}

// MARK: - Metal Helper Methods Extension

extension PersonalizedSeasonViewModel {

    /// Load season data from JSON file
    private func loadSeasonData(for seasonName: String) -> Season? {
        guard let url = Bundle.main.url(forResource: seasonName, withExtension: "json") else {
            print("Season JSON file not found for: \(seasonName)")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let seasonData = try JSONDecoder().decode([String: Season].self, from: data)
            return seasonData[seasonName]
        } catch {
            print("Error loading season \(seasonName): \(error)")
            return nil
        }
    }

    /// Extract finish options from season data grouped by metal type
    private func extractFinishOptionsFromSeason(_ season: Season, seasonSource: String, isPrimarySeason: Bool) -> [String: [MetalRecommendation.FinishOption]] {
        var metalFinishOptions: [String: [MetalRecommendation.FinishOption]] = [:]

        guard let metalsAndAccessories = season.styling.metalsAndAccessories,
              let metalTypes = metalsAndAccessories.metals?.type,
              let metalFinishes = metalsAndAccessories.metals?.finish else {
            return [:]
        }

        // Create finish options for each metal type
        for (metalType, typeRating) in metalTypes {
            // For primary season, skip any metals rated as "bad"
            if isPrimarySeason && typeRating == "bad" {
                continue
            }
            
            // For primary season, include both "great" and "good" metals
            // For secondary season, only include "great" metals
            if !isPrimarySeason && typeRating != "great" {
                continue
            }

            var finishOptions: [MetalRecommendation.FinishOption] = []

            for (finishType, finishRating) in metalFinishes {
                // Skip bad finishes
                if finishRating == "bad" {
                    continue
                }
                
                // For secondary seasons, only include "great" finishes and mark them as "good"
                if !isPrimarySeason {
                    if finishRating != "great" { continue }
                    
                    let finishOption = MetalRecommendation.FinishOption(
                        name: finishType,
                        priority: .good, // Downgrade to good for secondary seasons
                        seasonSource: seasonSource
                    )
                    finishOptions.append(finishOption)
                    continue
                }
                
                // For primary season, keep original priorities
                let priority: MetalRecommendation.MetalPriority
                if typeRating == "great" && finishRating == "great" {
                    priority = .great
                } else {
                    priority = .good
                }

                let finishOption = MetalRecommendation.FinishOption(
                    name: finishType,
                    priority: priority,
                    seasonSource: seasonSource
                )
                finishOptions.append(finishOption)
            }

            if !finishOptions.isEmpty {
                metalFinishOptions[metalType] = finishOptions
            }
        }

        return metalFinishOptions
    }
}

// MARK: - Data Validation Extensions

extension PersonalizedSeasonViewModel {

    /// Validate that the personalized data contains sufficient information
    /// - Returns: True if data appears complete and valid
    var isDataValid: Bool {
        return !personalizedData.personalizedTagline.isEmpty &&
               !personalizedData.userCharacteristics.isEmpty &&
               !personalizedData.personalizedOverview.isEmpty &&
               !personalizedData.emphasizedColors.isEmpty
    }

    /// Get a summary of what's included in this personalization
    /// - Returns: Array of strings describing available content
    var contentSummary: [String] {
        var summary: [String] = []

        if !personalizedData.personalizedTagline.isEmpty {
            summary.append("Personalized tagline")
        }

        if !personalizedData.userCharacteristics.isEmpty {
            summary.append("Unique characteristics analysis")
        }

        if !personalizedData.emphasizedColors.isEmpty {
            summary.append("\(personalizedData.emphasizedColors.count) emphasized colors")
        }

        if !personalizedData.colorsToAvoid.isEmpty {
            summary.append("\(personalizedData.colorsToAvoid.count) colors to avoid")
        }

        let colorRecommendations = getAllColorRecommendations()
        summary.append("\(colorRecommendations.count) color recommendation categories")

        return summary
    }
}
