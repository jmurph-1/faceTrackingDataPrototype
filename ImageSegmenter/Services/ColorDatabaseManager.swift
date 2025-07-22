//
//  ColorDatabaseManager.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import UIKit
import SwiftUI

/// Manages the color database loaded from colors.json
class ColorDatabaseManager {

    // MARK: - Singleton

    static let shared = ColorDatabaseManager()

    // MARK: - Properties

    private var colorDatabase: [ColorData] = []
    private var hexToColorCache: [String: ColorData] = [:]
    private var isLoaded = false
    private let loadQueue = DispatchQueue(label: "com.season13.colordb", qos: .utility)

    // MARK: - Initialization

    private init() {
        loadColorDatabase()
    }

    // MARK: - Public Methods

    /// Get color name for a hex value
    /// - Parameter hexValue: Hex string to look up
    /// - Returns: Color name if found, nil otherwise
    func getColorName(for hexValue: String) -> String? {
        return getColorData(for: hexValue)?.name
    }

    /// Get full color data for a hex value
    /// - Parameter hexValue: Hex string to look up
    /// - Returns: ColorData if found, nil otherwise
    func getColorData(for hexValue: String) -> ColorData? {
        let normalizedHex = normalizeHex(hexValue)
        return hexToColorCache[normalizedHex]
    }

    /// Get all colors for a specific season
    /// - Parameter season: Season name to filter by
    /// - Returns: Array of ColorData for the season
    func getColors(for season: String) -> [ColorData] {
        return colorDatabase.filter { $0.season.lowercased() == season.lowercased() }
    }

    /// Get colors for a season and category
    /// - Parameters:
    ///   - season: Season name to filter by
    ///   - category: Category to filter by
    /// - Returns: Array of ColorData matching both filters
    func getColors(for season: String, category: String) -> [ColorData] {
        return colorDatabase.filter {
            $0.season.lowercased() == season.lowercased() &&
            $0.category.lowercased() == category.lowercased()
        }
    }

    /// Get recommended colors based on Season DNA
    /// - Parameters:
    ///   - seasonDNA: Season DNA analysis
    ///   - category: Optional category filter
    ///   - limit: Maximum number of colors to return
    /// - Returns: Array of ColorData recommendations
    func getRecommendedColors(for seasonDNA: SeasonDNA, category: String? = nil, limit: Int = 12) -> [ColorData] {
        var recommendations: [ColorData] = []

        // Get colors from primary season (70% weight)
        let primaryColors = category != nil ?
            getColors(for: seasonDNA.primary.season, category: category!) :
            getColors(for: seasonDNA.primary.season)

        let primaryCount = Int(Float(limit) * seasonDNA.primary.weight)
        recommendations.append(contentsOf: Array(primaryColors.prefix(primaryCount)))

        // Get colors from secondary season if exists
        if let secondary = seasonDNA.secondary, recommendations.count < limit {
            let secondaryColors = category != nil ?
                getColors(for: secondary.season, category: category!) :
                getColors(for: secondary.season)

            let secondaryCount = Int(Float(limit) * secondary.weight)
            let remainingSlots = limit - recommendations.count
            let colorsToAdd = min(secondaryCount, remainingSlots)

            recommendations.append(contentsOf: Array(secondaryColors.prefix(colorsToAdd)))
        }

        // Get colors from tertiary season if exists and we still have room
        if let tertiary = seasonDNA.tertiary, recommendations.count < limit {
            let tertiaryColors = category != nil ?
                getColors(for: tertiary.season, category: category!) :
                getColors(for: tertiary.season)

            let remainingSlots = limit - recommendations.count
            recommendations.append(contentsOf: Array(tertiaryColors.prefix(remainingSlots)))
        }

        return Array(recommendations.prefix(limit))
    }

    /// Find colors similar to a given hex value within a season
    /// - Parameters:
    ///   - hexValue: Target hex value
    ///   - season: Season to search within
    ///   - limit: Maximum number of similar colors to return
    /// - Returns: Array of similar ColorData sorted by similarity
    func findSimilarColors(to hexValue: String, in season: String, limit: Int = 5) -> [ColorData] {
        guard let targetColor = UIColor(hex: hexValue) else { return [] }

        let seasonColors = getColors(for: season)

        // Calculate color distances and sort by similarity
        let colorDistances = seasonColors.compactMap { colorData -> (ColorData, Double)? in
            guard let color = UIColor(hex: colorData.hexValue) else { return nil }
            let distance = calculateColorDistance(targetColor, color)
            return (colorData, distance)
        }

        let sortedColors = colorDistances.sorted { $0.1 < $1.1 } // Sort by distance (ascending)
        return Array(sortedColors.prefix(limit).map { $0.0 })
    }

    /// Validate that the color database loaded correctly
    /// - Returns: Validation result with statistics
    func validateDatabase() -> DatabaseValidation {
        // If not loaded yet, wait a moment for async loading
        if !isLoaded {
            let semaphore = DispatchSemaphore(value: 0)
            loadQueue.async {
                semaphore.signal()
            }
            semaphore.wait()
        }

        let totalColors = colorDatabase.count
        let uniqueSeasons = Set(colorDatabase.map { $0.season }).count
        let uniqueCategories = Set(colorDatabase.map { $0.category }).count
        let cacheSize = hexToColorCache.count

        return DatabaseValidation(
            isValid: totalColors > 0 && isLoaded,
            totalColors: totalColors,
            uniqueSeasons: uniqueSeasons,
            uniqueCategories: uniqueCategories,
            cacheSize: cacheSize,
            isLoaded: isLoaded
        )
    }

    /// Get all available season names
    var availableSeasons: [String] {
        return Array(Set(colorDatabase.map { $0.season })).sorted()
    }

    /// Get all available category names
    var availableCategories: [String] {
        return Array(Set(colorDatabase.map { $0.category })).sorted()
    }

    // MARK: - Private Methods

    private func loadColorDatabase() {
        loadQueue.async { [weak self] in
            guard let self = self else { return }

            #if DEBUG
            print("🔵 ColorDatabaseManager: Starting to load colors.json")
            #endif

            // Try to load from bundle root first
            guard let url = Bundle.main.url(forResource: "colors", withExtension: "json") else {
                #if DEBUG
                print("🔴 ColorDatabaseManager: Could not find colors.json in bundle")
                #endif
                return
            }

            do {
                let data = try Data(contentsOf: url)
                let colors = try JSONDecoder().decode([ColorData].self, from: data)

                self.colorDatabase = colors
                self.buildHexCache()
                self.isLoaded = true

                #if DEBUG
                print("🟢 ColorDatabaseManager: Successfully loaded \(colors.count) colors")
                print("🔵 ColorDatabaseManager: Built cache with \(self.hexToColorCache.count) entries")
                #endif

            } catch {
                #if DEBUG
                print("🔴 ColorDatabaseManager: Error loading colors.json: \(error)")
                #endif
            }
        }
    }

    private func buildHexCache() {
        hexToColorCache.removeAll()

        for color in colorDatabase {
            let normalizedHex = normalizeHex(color.hexValue)
            hexToColorCache[normalizedHex] = color
        }
    }

    private func normalizeHex(_ hex: String) -> String {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return cleaned.hasPrefix("#") ? cleaned : "#\(cleaned)"
    }

    /// Calculate color distance using simple RGB Euclidean distance
    /// In a more sophisticated implementation, you might use Delta-E (CIEDE2000)
    private func calculateColorDistance(_ color1: UIColor, _ color2: UIColor) -> Double {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let deltaR = Double(r1 - r2)
        let deltaG = Double(g1 - g2)
        let deltaB = Double(b1 - b2)

        return sqrt(deltaR * deltaR + deltaG * deltaG + deltaB * deltaB)
    }
}

// MARK: - Supporting Data Structures

/// Color data structure matching colors.json format
struct ColorData: Codable, Identifiable {
    let name: String
    let hexValue: String
    let category: String
    let season: String

    // Generate ID from name and hex for Identifiable conformance
    var id: String {
        return "\(name)_\(normalizedHex)"
    }

    /// Normalized hex value (lowercase with #)
    var normalizedHex: String {
        let cleaned = hexValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return cleaned.hasPrefix("#") ? cleaned : "#\(cleaned)"
    }

    /// SwiftUI Color computed property for backward compatibility
    var color: Color {
        return Color(hex: hexValue)
    }

    /// Convert to ColorItem for use in PersonalizedSeasonData
    func toColorItem(usageContext: String = "", harmonyReason: String = "") -> ColorItem {
        let context = usageContext.isEmpty ? "Perfect for \(category.lowercased()) in \(season)" : usageContext
        let reason = harmonyReason.isEmpty ? "Harmonizes beautifully with \(season) characteristics" : harmonyReason

        return ColorItem(
            name: name,
            hexValue: normalizedHex,
            usageContext: context,
            harmonyReason: reason
        )
    }
}

/// Database validation result
struct DatabaseValidation {
    let isValid: Bool
    let totalColors: Int
    let uniqueSeasons: Int
    let uniqueCategories: Int
    let cacheSize: Int
    let isLoaded: Bool

    /// Summary string for debugging
    var summary: String {
        return """
        Database Status: \(isValid ? "✅ Valid" : "❌ Invalid")
        Total Colors: \(totalColors)
        Unique Seasons: \(uniqueSeasons)
        Unique Categories: \(uniqueCategories)
        Cache Size: \(cacheSize)
        Loaded: \(isLoaded ? "Yes" : "No")
        """
    }
}

// MARK: - Convenience Extensions

extension ColorDatabaseManager {

    /// Get enhanced color items for a specific season and category with context
    /// - Parameters:
    ///   - season: Season name
    ///   - category: Category name
    ///   - limit: Maximum colors to return
    ///   - contextPrefix: Prefix for usage context
    /// - Returns: Array of ColorItem with generated context
    func getEnhancedColorItems(
        for season: String,
        category: String,
        limit: Int = 4,
        contextPrefix: String = ""
    ) -> [ColorItem] {
        let colors = getColors(for: season, category: category)

        return Array(colors.prefix(limit)).map { colorData in
            let usageContext = generateUsageContext(for: colorData, prefix: contextPrefix)
            let harmonyReason = generateHarmonyReason(for: colorData, season: season)

            return colorData.toColorItem(
                usageContext: usageContext,
                harmonyReason: harmonyReason
            )
        }
    }

    private func generateUsageContext(for colorData: ColorData, prefix: String) -> String {
        let categoryLower = colorData.category.lowercased()

        if !prefix.isEmpty {
            return "\(prefix) \(categoryLower)"
        }

        switch categoryLower {
        case "neutrals":
            return "Perfect foundation color for everyday wear"
        case "base colors":
            return "Ideal for main wardrobe pieces and larger color blocks"
        case "palette":
            return "Beautiful accent color for special occasions"
        case "lip colors", "makeup":
            return "Enhances your natural beauty"
        case "eye colors":
            return "Brings out your eye color beautifully"
        default:
            return "Complements your \(colorData.season) coloring"
        }
    }

    private func generateHarmonyReason(for colorData: ColorData, season: String) -> String {
        let seasonLower = season.lowercased()

        if seasonLower.contains("spring") {
            return "The warm, clear tones enhance your Spring vitality"
        } else if seasonLower.contains("summer") {
            return "The cool, soft tones complement your Summer elegance"
        } else if seasonLower.contains("autumn") {
            return "The warm, muted tones match your Autumn richness"
        } else if seasonLower.contains("winter") {
            return "The cool, clear tones highlight your Winter drama"
        } else {
            return "Harmonizes perfectly with your natural coloring"
        }
    }
}
