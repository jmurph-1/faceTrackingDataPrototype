//
//  MockMetalRecommendations.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation

/// Extension to provide metal recommendations for mock data
extension MockPersonalizedSeasonDataFactory {

    static func createMetalRecommendations(for season: String) -> [MetalRecommendation] {
        switch season {
        case "Bright Spring":
            return createBrightSpringMetals()
        case "Soft Autumn":
            return createSoftAutumnMetals()
        case "Dark Winter":
            return createDarkWinterMetals()
        case "True Autumn":
            return createTrueAutumnMetals()
        default:
            // For any unhandled season, return a minimal set of metals
            print("⚠️ Warning: Using default metal recommendations for season: \(season)")
            return createDefaultMetals(for: season)
        }
    }

    private static func createBrightSpringMetals() -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "Gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Bright", priority: .great, seasonSource: "Bright Spring"),
                    MetalRecommendation.FinishOption(name: "Rose", priority: .great, seasonSource: "Bright Spring"),
                    MetalRecommendation.FinishOption(name: "Brushed", priority: .good, seasonSource: "Bright Spring")
                ],
                priority: .great,
                seasonSources: ["Bright Spring"]
            ),
            MetalRecommendation(
                name: "Silver",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Bright", priority: .good, seasonSource: "Bright Spring"),
                    MetalRecommendation.FinishOption(name: "Polished", priority: .good, seasonSource: "Bright Spring")
                ],
                priority: .good,
                seasonSources: ["Bright Spring"]
            )
        ]
    }

    private static func createSoftAutumnMetals() -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "Gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Antique", priority: .great, seasonSource: "Soft Autumn")
                ],
                priority: .great,
                seasonSources: ["Soft Autumn"]
            ),
            MetalRecommendation(
                name: "Bronze",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Antique", priority: .great, seasonSource: "Soft Autumn")
                ],
                priority: .great,
                seasonSources: ["Soft Autumn"]
            ),
            MetalRecommendation(
                name: "Copper",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Brushed", priority: .good, seasonSource: "Soft Autumn")
                ],
                priority: .good,
                seasonSources: ["Soft Autumn"]
            )
        ]
    }

    private static func createDarkWinterMetals() -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "Silver",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Bright", priority: .great, seasonSource: "Dark Winter"),
                    MetalRecommendation.FinishOption(name: "Oxidized", priority: .great, seasonSource: "Dark Winter")
                ],
                priority: .great,
                seasonSources: ["Dark Winter"]
            ),
            MetalRecommendation(
                name: "Platinum",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Polished", priority: .great, seasonSource: "Dark Winter")
                ],
                priority: .great,
                seasonSources: ["Dark Winter"]
            ),
            MetalRecommendation(
                name: "White Gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Bright", priority: .good, seasonSource: "Dark Winter"),
                    MetalRecommendation.FinishOption(name: "Brushed", priority: .good, seasonSource: "Dark Winter")
                ],
                priority: .good,
                seasonSources: ["Dark Winter"]
            )
        ]
    }

    private static func createTrueAutumnMetals() -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "Gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Antique", priority: .great, seasonSource: "True Autumn"),
                    MetalRecommendation.FinishOption(name: "Brushed", priority: .great, seasonSource: "True Autumn")
                ],
                priority: .great,
                seasonSources: ["True Autumn"]
            ),
            MetalRecommendation(
                name: "Bronze",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Antique", priority: .great, seasonSource: "True Autumn")
                ],
                priority: .great,
                seasonSources: ["True Autumn"]
            ),
            MetalRecommendation(
                name: "Copper",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Antique", priority: .good, seasonSource: "True Autumn"),
                    MetalRecommendation.FinishOption(name: "Brushed", priority: .good, seasonSource: "True Autumn")
                ],
                priority: .good,
                seasonSources: ["True Autumn"]
            )
        ]
    }

    private static func createDefaultMetals(for season: String) -> [MetalRecommendation] {
        return [
            MetalRecommendation(
                name: "Gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Polished", priority: .good, seasonSource: season)
                ],
                priority: .good,
                seasonSources: [season]
            )
        ]
    }
}
