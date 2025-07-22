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
        let finishName = bestFinish?.name.lowercased() ?? "bright"
        switch (name.lowercased(), finishName) {
        // Gold variations
        case ("gold", "bright"):
            return [Color(hex: "#FFD700"), Color(hex: "#FFC125"), Color(hex: "#FFB90F")]
        case ("gold", "antique"):
            return [Color(hex: "#D4A76A"), Color(hex: "#B8860B"), Color(hex: "#996515")]
        case ("gold", "rose"):
            return [Color(hex: "#E0BFB8"), Color(hex: "#D4A5A5"), Color(hex: "#C9A0A0")]
        case ("gold", "white"):
            return [Color(hex: "#F5F5DC"), Color(hex: "#E8E4C9"), Color(hex: "#D4D4AA")]
        case ("gold", "brushed"):
            return [Color(hex: "#D4AF37"), Color(hex: "#B8970B"), Color(hex: "#AA8800")]

        // Silver variations
        case ("silver", "bright"):
            return [Color(hex: "#C0C0C0"), Color(hex: "#D3D3D3"), Color(hex: "#E5E5E5")]
        case ("silver", "antique"):
            return [Color(hex: "#8B8B83"), Color(hex: "#A8A8A8"), Color(hex: "#848484")]
        case ("silver", "brushed"):
            return [Color(hex: "#B8B8B8"), Color(hex: "#A9A9A9"), Color(hex: "#969696")]
        case ("silver", "oxidized"):
            return [Color(hex: "#696969"), Color(hex: "#808080"), Color(hex: "#778899")]

        // Platinum
        case ("platinum", _):
            return [Color(hex: "#E5E4E2"), Color(hex: "#D8D8D6"), Color(hex: "#C9C9C7")]

        // Copper variations
        case ("copper", "bright"):
            return [Color(hex: "#DA8A67"), Color(hex: "#C97551"), Color(hex: "#B87333")]
        case ("copper", "antique"):
            return [Color(hex: "#9C6935"), Color(hex: "#8B5A2B"), Color(hex: "#7F462C")]
        case ("copper", "rose"):
            return [Color(hex: "#CE8E8B"), Color(hex: "#C27B79"), Color(hex: "#B76E68")]

        // Bronze variations
        case ("bronze", _):
            return [Color(hex: "#CD7F32"), Color(hex: "#B8734B"), Color(hex: "#A0612F")]

        // Pewter
        case ("pewter", _):
            return [Color(hex: "#8F8F8C"), Color(hex: "#7D7D7A"), Color(hex: "#6B6B68")]

        // Default metallic
        default:
            return [Color.gray, Color.gray.opacity(0.8), Color.gray.opacity(0.6)]
        }
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
