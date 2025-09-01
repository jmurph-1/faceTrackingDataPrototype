//
//  MockPersonalizedSeasonDataFactory.swift
//  ImageSegmenter
//
//  Created by John Murphy on 12/27/24.
//

import Foundation
import SwiftUI

/// Factory for creating mock PersonalizedSeasonData for testing and debugging
struct MockPersonalizedSeasonDataFactory {

    // MARK: - Quick Mock Methods

    /// Create a mock Bright Spring with DNA blend
    static func brightSpringWithBlend() -> PersonalizedSeasonData {
        return createMockData(
            season: "Bright Spring",
            seasonDNA: SeasonDNA(
                primary: SeasonWeight(season: "Bright Spring", weight: 0.75),
                secondary: SeasonWeight(season: "Clear Winter", weight: 0.20),
                tertiary: SeasonWeight(season: "True Spring", weight: 0.05),
                explanation: "Your coloring shows strong Bright Spring characteristics with Clear Winter's dramatic contrast and True Spring's warmth.",
                classificationConfidence: 0.85,
                blendJustification: "The high contrast in your features suggests Winter influence, while your warm undertones confirm Spring."
            ),
            emphasizedColors: ["#FF6B35", "#FFD23F", "#06FFA5", "#4ECDC4", "#45B7D1"],
            colorsToAvoid: ["#8B4513", "#556B2F", "#2F4F4F"]
        )
    }

    /// Create a mock Soft Autumn (pure season)
    static func softAutumn() -> PersonalizedSeasonData {
        return createMockData(
            season: "Soft Autumn",
            seasonDNA: SeasonDNA(
                primary: SeasonWeight(season: "Soft Autumn", weight: 0.95),
                explanation: "Your coloring is a classic Soft Autumn with consistent muted, warm characteristics.",
                classificationConfidence: 0.92
            ),
            emphasizedColors: ["#B8860B", "#CD853F", "#A0522D", "#8B4513", "#DAA520"],
            colorsToAvoid: ["#FF69B4", "#00FFFF", "#FF0000"]
        )
    }

    /// Create a mock Deep Winter with tertiary blend
    static func deepWinterComplex() -> PersonalizedSeasonData {
        return createMockData(
            season: "Dark Winter",
            seasonDNA: SeasonDNA(
                primary: SeasonWeight(season: "Dark Winter", weight: 0.60),
                secondary: SeasonWeight(season: "Dark Autumn", weight: 0.30),
                tertiary: SeasonWeight(season: "True Winter", weight: 0.10),
                explanation: "Your coloring shows Deep Winter intensity with Dark Autumn richness and True Winter clarity.",
                classificationConfidence: 0.78,
                blendJustification: "The richness in your coloring suggests Autumn influence, balancing Winter's coolness."
            ),
            emphasizedColors: ["#000080", "#8B0000", "#2F4F4F", "#4B0082", "#191970"],
            colorsToAvoid: ["#FFB347", "#98FB98", "#F0E68C"]
        )
    }

    // MARK: - Helper Method

    private static func createMockData(
        season: String,
        seasonDNA: SeasonDNA,
        emphasizedColors: [String],
        colorsToAvoid: [String]
    ) -> PersonalizedSeasonData {

        let enhancedColors = createEnhancedColorData(for: season, emphasizedColors: emphasizedColors)
        let metals = createMetalRecommendations(for: season)

        return PersonalizedSeasonData(
            baseSeason: season,
            personalizedTagline: "Your unique \(season) palette brings out your natural radiance",
            userCharacteristics: "You have \(season.lowercased()) coloring with \(getCharacteristics(for: season))",
            personalizedOverview: getOverview(for: season),
            colorRecommendations: createColorRecommendations(for: season),
            emphasizedColors: emphasizedColors,
            colorsToAvoid: colorsToAvoid,
            confidence: seasonDNA.classificationConfidence,
            seasonDNAData: seasonDNA,
            enhancedColorData: enhancedColors,
            metals: metals
        )
    }

    private static func getCharacteristics(for season: String) -> String {
        let characteristics: [String: String] = [
            "Bright Spring": "clear, bright eyes with warm undertones and high contrast features",
            "Soft Autumn": "muted, warm coloring with gentle contrasts and golden undertones",
            "Dark Winter": "deep, rich coloring with high contrast and cool undertones"
        ]
        return characteristics[season] ?? "natural beauty that complements this season's palette"
    }

    private static func getOverview(for season: String) -> String {
        let overviews: [String: String] = [
            "Bright Spring": "Your coloring thrives on clear, bright colors that match your natural vibrancy. You can wear both warm and cool tones as long as they're clear and saturated.",
            "Soft Autumn": "Your gentle, muted coloring is enhanced by soft, warm colors. You look beautiful in earthy tones that aren't too bright or stark.",
            "Dark Winter": "Your dramatic coloring can handle deep, rich colors with high contrast. You look stunning in bold, cool-toned colors that match your natural intensity."
        ]
        return overviews[season] ?? "Your unique coloring is enhanced by colors that complement your natural beauty."
    }

    private static func createColorRecommendations(for season: String) -> PersonalizedColorRecommendations {
        let recommendations: [String: PersonalizedColorRecommendations] = [
            "Bright Spring": PersonalizedColorRecommendations(
                bestNeutrals: ColorRecommendation(
                    description: "Clear, warm neutrals that don't overpower your brightness",
                    colors: ["#F5F5DC", "#D2B48C", "#8B7355"],
                    priority: "high",
                    usageInstructions: "Use as foundation colors in your wardrobe"
                ),
                bestAccents: ColorRecommendation(
                    description: "Bright, clear colors that match your energy",
                    colors: ["#FF6B35", "#06FFA5", "#4ECDC4"],
                    priority: "high",
                    usageInstructions: "Perfect for statement pieces and accessories"
                ),
                bestBaseColors: ColorRecommendation(
                    description: "Clear colors for everyday wear",
                    colors: ["#FFFFFF", "#000000", "#FF0000"],
                    priority: "medium",
                    usageInstructions: "Great for basics and work attire"
                ),
                hairColorSuggestions: ColorRecommendation(
                    description: "Hair colors that complement your brightness",
                    colors: ["#8B4513", "#D2691E"],
                    priority: "low",
                    usageInstructions: "Consider these shades if changing hair color"
                )
            )
        ]

        return recommendations[season] ?? createDefaultRecommendations()
    }

    private static func createDefaultRecommendations() -> PersonalizedColorRecommendations {
        return PersonalizedColorRecommendations(
            bestNeutrals: ColorRecommendation(
                description: "Versatile neutral colors",
                colors: ["#FFFFFF", "#D3D3D3", "#A9A9A9"],
                priority: "high",
                usageInstructions: "Foundation of your wardrobe"
            ),
            bestAccents: ColorRecommendation(
                description: "Beautiful accent colors",
                colors: ["#4682B4", "#CD853F", "#9932CC"],
                priority: "medium",
                usageInstructions: "Add color and interest"
            ),
            bestBaseColors: ColorRecommendation(
                description: "Reliable base colors",
                colors: ["#000000", "#FFFFFF", "#8B4513"],
                priority: "high",
                usageInstructions: "Everyday essentials"
            ),
            hairColorSuggestions: ColorRecommendation(
                description: "Hair color suggestions",
                colors: ["#654321", "#8B4513"],
                priority: "low",
                usageInstructions: "Consider if changing hair color"
            )
        )
    }


    private static func createEnhancedColorData(for season: String, emphasizedColors: [String]) -> EnhancedColorRecommendations {
        let colorItems = emphasizedColors.enumerated().map { index, hex in
            ColorItem(
                name: "Color \(index + 1)",
                hexValue: hex,
                usageContext: "Perfect for your \(season) coloring",
                harmonyReason: "Complements your natural undertones"
            )
        }

        let bestNeutrals = DetailedColorRecommendation(
            description: "Your best neutral colors",
            colors: Array(colorItems.prefix(3)),
            priority: "high",
            usageInstructions: "Use as wardrobe foundation",
            categoryExplanation: "These neutrals work perfectly with your coloring"
        )

        return EnhancedColorRecommendations(
            bestNeutrals: bestNeutrals,
            bestAccents: bestNeutrals,
            bestBaseColors: bestNeutrals
        )
    }
}

// MARK: - Quick Access Methods

extension MockPersonalizedSeasonDataFactory {
    /// Get all available mock data options
    static var allMockOptions: [PersonalizedSeasonData] {
        return [
            brightSpringWithBlend(),
            softAutumn(),
            deepWinterComplex()
        ]
    }

    /// Get random mock data
    static func random() -> PersonalizedSeasonData {
        return allMockOptions.randomElement() ?? brightSpringWithBlend()
    }
}

// MARK: - Metal Recommendations Extension

extension MockPersonalizedSeasonDataFactory {
    private static func createBrightSpringMetals() -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "yellow gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .great, seasonSource: "Bright Spring")
                ],
                priority: .great,
                seasonSources: ["Bright Spring"]
            ),
            MetalRecommendation(
                name: "rose gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .great, seasonSource: "Bright Spring")
                ],
                priority: .great,
                seasonSources: ["Bright Spring"]
            )
            // Note: Silver is intentionally excluded as it would be marked "bad" for Bright Spring
        ]
    }

    private static func createSoftAutumnMetals() -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "yellow gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .great, seasonSource: "Soft Autumn")
                ],
                priority: .great,
                seasonSources: ["Soft Autumn"]
            ),
            MetalRecommendation(
                name: "copper",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .great, seasonSource: "Soft Autumn")
                ],
                priority: .great,
                seasonSources: ["Soft Autumn"]
            ),
            MetalRecommendation(
                name: "bronze",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .good, seasonSource: "Soft Autumn")
                ],
                priority: .good,
                seasonSources: ["Soft Autumn"]
            )
        ]
    }

    private static func createDarkWinterMetals() -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "cool silver",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .great, seasonSource: "Dark Winter")
                ],
                priority: .great,
                seasonSources: ["Dark Winter"]
            ),
            MetalRecommendation(
                name: "platinum",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .great, seasonSource: "Dark Winter")
                ],
                priority: .great,
                seasonSources: ["Dark Winter"]
            ),
            MetalRecommendation(
                name: "white gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .good, seasonSource: "Dark Winter")
                ],
                priority: .good,
                seasonSources: ["Dark Winter"]
            )
        ]
    }

    private static func createTrueAutumnMetals() -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "yellow gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .great, seasonSource: "True Autumn")
                ],
                priority: .great,
                seasonSources: ["True Autumn"]
            ),
            MetalRecommendation(
                name: "bronze",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .great, seasonSource: "True Autumn")
                ],
                priority: .great,
                seasonSources: ["True Autumn"]
            ),
            MetalRecommendation(
                name: "copper",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .good, seasonSource: "True Autumn")
                ],
                priority: .good,
                seasonSources: ["True Autumn"]
            )
        ]
    }

    private static func createDefaultMetals(for season: String) -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "yellow gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "polished", priority: .good, seasonSource: season)
                ],
                priority: .good,
                seasonSources: [season]
            )
        ]
    }
}
