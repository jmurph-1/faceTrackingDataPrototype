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
