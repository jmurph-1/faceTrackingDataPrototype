//
//  MetalRecommendation.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import SwiftUI

struct MetalRecommendation: Identifiable, Equatable, Codable {
    // MARK: - Coding Keys
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case availableFinishes
        case priority
        case seasonSources
    }

    let id: UUID
    let name: String
    let availableFinishes: [FinishOption]
    let priority: MetalPriority
    let seasonSources: [String] // Which seasons this comes from

    init(name: String, availableFinishes: [FinishOption], priority: MetalPriority, seasonSources: [String], id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.availableFinishes = availableFinishes
        self.priority = priority
        self.seasonSources = seasonSources
    }

    enum MetalPriority: String, CaseIterable, Codable {
        case great = "great"
        case good = "good"

        var displayName: String {
            switch self {
            case .great:
                return "Best"
            case .good:
                return "Good"
            }
        }
    }

    struct FinishOption: Identifiable, Equatable, Codable {
        // MARK: - Coding Keys
        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case priority
            case seasonSource
        }

        let id: UUID
        let name: String
        let priority: MetalPriority
        let seasonSource: String

        init(name: String, priority: MetalPriority, seasonSource: String, id: UUID = UUID()) {
            self.id = id
            self.name = name
            self.priority = priority
            self.seasonSource = seasonSource
        }

        var displayName: String {
            name.capitalized
        }
    }

    // Computed property for display name
    var displayName: String {
        name.capitalized
    }

    // Unique identifier for deduplication
    var uniqueKey: String {
        name.lowercased()
    }

    // Get the best finish option
    var bestFinish: FinishOption? {
        availableFinishes.first { $0.priority == .great } ?? availableFinishes.first
    }

    // Get the metallic gradient colors based on metal type and best finish
    var metallicGradient: [Color] {
        switch name.lowercased() {
        // Gold variations
        case "gold", "yellow gold":
            return [
                Color(hex: "#FFD700"),   // Pure gold
                Color(hex: "#FFBF00"),   // Richer gold
                Color(hex: "#DAA520"),   // Golden rod
                Color(hex: "#FFBF00"),   // Richer gold
                Color(hex: "#FFD700")    // Pure gold
            ]
        case "rose gold":
            return [
                Color(hex: "#FFB199"),   // Light rose
                Color(hex: "#FF9966"),   // Medium rose
                Color(hex: "#FF8080"),   // Deep rose
                Color(hex: "#FF9966"),   // Medium rose
                Color(hex: "#FFB199")    // Light rose
            ]
        case "white gold":
            return [
                Color(hex: "#E8E8E8"),   // Light
                Color(hex: "#D4D4D4"),   // Medium
                Color(hex: "#C0C0C0"),   // Deep
                Color(hex: "#D4D4D4"),   // Medium
                Color(hex: "#E8E8E8")    // Light
            ]

        // Mixed metal (gold and silver)
        case "mixed":
            return [
                Color(hex: "#FFD700"),   // Pure gold
                Color(hex: "#FFD700"),   // Pure gold (repeated to extend gold section)
                Color(hex: "#E8E8E8"),   // Transition
                Color(hex: "#C0C0C0"),   // Silver
                Color(hex: "#C0C0C0")    // Silver (repeated to balance)
            ]

        // Silver variations
        case "silver", "cool silver":
            return [
                Color(hex: "#E8E8E8"),   // Light
                Color(hex: "#D4D4D4"),   // Medium light
                Color(hex: "#C0C0C0"),   // Medium
                Color(hex: "#D4D4D4"),   // Medium light
                Color(hex: "#E8E8E8")    // Light
            ]
        case "warm silver":
            return [
                Color(hex: "#E0D5C7"),   // Warm light
                Color(hex: "#C0B5A8"),   // Warm medium
                Color(hex: "#A89B8C"),   // Warm deep
                Color(hex: "#C0B5A8"),   // Warm medium
                Color(hex: "#E0D5C7")    // Warm light
            ]

        // Platinum
        case "platinum":
            return [
                Color(hex: "#E5E4E2"),   // Light
                Color(hex: "#D8D8D6"),   // Medium
                Color(hex: "#C9C9C7"),   // Deep
                Color(hex: "#D8D8D6"),   // Medium
                Color(hex: "#E5E4E2")    // Light
            ]

        // Copper
        case "copper":
            return [
                Color(hex: "#FFA07A"),   // Light
                Color(hex: "#E08D3C"),   // Medium
                Color(hex: "#B87333"),   // Deep
                Color(hex: "#E08D3C"),   // Medium
                Color(hex: "#FFA07A")    // Light
            ]

        // Bronze
        case "bronze":
            return [
                Color(hex: "#CD853F"),   // Light
                Color(hex: "#B8734B"),   // Medium
                Color(hex: "#8B4513"),   // Deep
                Color(hex: "#B8734B"),   // Medium
                Color(hex: "#CD853F")    // Light
            ]

        // Brass
        case "brass":
            return [
                Color(hex: "#DAA520"),   // Light
                Color(hex: "#B8860B"),   // Medium
                Color(hex: "#996515"),   // Deep
                Color(hex: "#B8860B"),   // Medium
                Color(hex: "#DAA520")    // Light
            ]

        // Pewter
        case "pewter":
            return [
                Color(hex: "#A9A9A9"),   // Light
                Color(hex: "#808080"),   // Medium
                Color(hex: "#696969"),   // Deep
                Color(hex: "#808080"),   // Medium
                Color(hex: "#A9A9A9")    // Light
            ]

        // Default metallic
        default:
            print("⚠️ Warning: Unrecognized metal type: \(name)")  // Add debug logging
            return [
                Color(hex: "#D4D4D4"),   // Light
                Color(hex: "#C0C0C0"),   // Medium
                Color(hex: "#A8A8A8"),   // Deep
                Color(hex: "#C0C0C0"),   // Medium
                Color(hex: "#D4D4D4")    // Light
            ]
        }
    }

    // Whether this metal is a mixed type
    var isMixed: Bool {
        return name.lowercased() == "mixed"
    }

    // Get whether this is a warm or cool metal (for categorization)
    var temperatureCategory: TemperatureCategory {
        switch name.lowercased() {
        case "gold", "copper", "bronze":
            return .warm
        case "silver", "platinum", "pewter":
            return .cool
        default:
            return .neutral
        }
    }

    enum TemperatureCategory: String, Codable {
        case warm = "warm"
        case cool = "cool"
        case neutral = "neutral"

        var displayName: String {
            switch self {
            case .warm:
                return "Warm"
            case .cool:
                return "Cool"
            case .neutral:
                return "Neutral"
            }
        }
    }

    // Get description for this metal recommendation
    var description: String {
        let finishName = bestFinish?.name.lowercased() ?? "bright"
        switch (name.lowercased(), finishName) {
        case ("gold", "bright"):
            return "Classic bright gold with warm undertones"
        case ("gold", "antique"):
            return "Aged gold with muted, sophisticated finish"
        case ("gold", "rose"):
            return "Romantic rose gold with pink undertones"
        case ("gold", "white"):
            return "Cool-toned white gold alternative"
        case ("gold", "brushed"):
            return "Matte gold with subtle texture"
        case ("silver", "bright"):
            return "Polished silver with cool reflective finish"
        case ("silver", "antique"):
            return "Tarnished silver with vintage appeal"
        case ("silver", "brushed"):
            return "Matte silver with subtle texture"
        case ("silver", "oxidized"):
            return "Darkened silver with dramatic contrast"
        case ("platinum", _):
            return "Luxurious platinum with pure white metal finish"
        case ("copper", "bright"):
            return "Vibrant copper with warm orange tones"
        case ("copper", "antique"):
            return "Aged copper with earthy patina"
        case ("copper", "rose"):
            return "Soft rose copper with pink undertones"
        case ("bronze", _):
            return "Rich bronze with warm brown undertones"
        case ("pewter", _):
            return "Matte pewter with soft gray finish"
        default:
            return "Metallic finish in \(name) with \(finishName) treatment"
        }
    }

    // Usage suggestions for this metal
    var usageSuggestions: [String] {
        switch priority {
        case .great:
            return [
                "Best for statement jewelry pieces",
                "Ideal for watches and accessories",
                "Perfect for belt buckles and hardware",
                "Great for eyewear frames"
            ]
        case .good:
            return [
                "Good for accent pieces",
                "Suitable for casual accessories",
                "Works well mixed with other metals"
            ]
        }
    }
}

// MARK: - Metal Collection Utilities

extension Array where Element == MetalRecommendation {

    /// Group metals by temperature category
    var groupedByTemperature: [MetalRecommendation.TemperatureCategory: [MetalRecommendation]] {
        Dictionary(grouping: self) { $0.temperatureCategory }
    }

    /// Get only the "great" priority metals
    var greatMetals: [MetalRecommendation] {
        self.filter { $0.priority == .great }
    }

    /// Get only the "good" priority metals
    var goodMetals: [MetalRecommendation] {
        self.filter { $0.priority == .good }
    }

    /// Remove duplicates based on uniqueKey
    var deduplicated: [MetalRecommendation] {
        var seen = Set<String>()
        return self.filter { metal in
            if seen.contains(metal.uniqueKey) {
                return false
            }
            seen.insert(metal.uniqueKey)
            return true
        }
    }
}
