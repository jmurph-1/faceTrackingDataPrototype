//
//  Color+Extensions.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import SwiftUI
import UIKit

// MARK: - SwiftUI Color Extensions

extension Color {

    /// Initialize Color from hex string
    /// - Parameter hex: Hex color string (with or without #)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (alpha, red, green, blue) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }

    /// Get hex string representation of Color
    var hexString: String {
        // Convert to UIColor to get components
        let uiColor = UIColor(self)
        return uiColor.hexString
    }

    // MARK: - Season Accent Colors

    /// Get accent color for a specific season
    /// - Parameter season: Season name
    /// - Returns: Accent color for the season
    static func seasonAccent(for season: String) -> Color {
        let seasonLower = season.lowercased()

        if seasonLower.contains("spring") {
            return Color(hex: "#FFB347") // Warm peach
        } else if seasonLower.contains("summer") {
            return Color(hex: "#87CEEB") // Soft blue
        } else if seasonLower.contains("autumn") {
            return Color(hex: "#CD853F") // Rich gold
        } else if seasonLower.contains("winter") {
            return Color(hex: "#4682B4") // Steel blue
        } else {
            return Color.primary // Default
        }
    }

    /// Get palette colors for a season
    /// - Parameter season: Season name
    /// - Returns: Array of colors representing the season's palette
    static func seasonPalette(for season: String) -> [Color] {
        let seasonLower = season.lowercased()

        if seasonLower.contains("spring") {
            return [
                Color(hex: "#FFB347"), // Peach
                Color(hex: "#98FB98"), // Pale green
                Color(hex: "#F0E68C"), // Khaki
                Color(hex: "#DDA0DD"), // Plum
                Color(hex: "#87CEEB")  // Sky blue
            ]
        } else if seasonLower.contains("summer") {
            return [
                Color(hex: "#87CEEB"), // Sky blue
                Color(hex: "#DDA0DD"), // Plum
                Color(hex: "#F0E68C"), // Khaki
                Color(hex: "#98FB98"), // Pale green
                Color(hex: "#FFB6C1")  // Light pink
            ]
        } else if seasonLower.contains("autumn") {
            return [
                Color(hex: "#CD853F"), // Peru
                Color(hex: "#D2691E"), // Chocolate
                Color(hex: "#B22222"), // Fire brick
                Color(hex: "#228B22"), // Forest green
                Color(hex: "#DAA520")  // Goldenrod
            ]
        } else if seasonLower.contains("winter") {
            return [
                Color(hex: "#4682B4"), // Steel blue
                Color(hex: "#2F4F4F"), // Dark slate gray
                Color(hex: "#800080"), // Purple
                Color(hex: "#DC143C"), // Crimson
                Color(hex: "#000080")  // Navy
            ]
        } else {
            return [Color.primary] // Default
        }
    }
}

// MARK: - UIColor Extensions

extension UIColor {

    /// Initialize UIColor from hex string
    /// - Parameter hex: Hex color string (with or without #)
    convenience init?(hex: String) {
        let redComponent, greenComponent, blueComponent, alphaComponent: CGFloat

        let hex = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex)
        var hexNumber: UInt64 = 0

        guard scanner.scanHexInt64(&hexNumber) else { return nil }

        switch hex.count {
        case 3: // RGB (12-bit)
            redComponent = CGFloat((hexNumber & 0xF00) >> 8) / 15.0
            greenComponent = CGFloat((hexNumber & 0x0F0) >> 4) / 15.0
            blueComponent = CGFloat(hexNumber & 0x00F) / 15.0
            alphaComponent = 1.0
        case 4: // RGB + Alpha (16-bit)
            redComponent = CGFloat((hexNumber & 0xF000) >> 12) / 15.0
            greenComponent = CGFloat((hexNumber & 0x0F00) >> 8) / 15.0
            blueComponent = CGFloat((hexNumber & 0x00F0) >> 4) / 15.0
            alphaComponent = CGFloat(hexNumber & 0x000F) / 15.0
        case 6: // RGB (24-bit)
            redComponent = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
            greenComponent = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
            blueComponent = CGFloat(hexNumber & 0x0000FF) / 255.0
            alphaComponent = 1.0
        case 8: // RGB + Alpha (32-bit)
            redComponent = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
            greenComponent = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
            blueComponent = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
            alphaComponent = CGFloat(hexNumber & 0x000000FF) / 255.0
        default:
            return nil
        }

        self.init(red: redComponent, green: greenComponent, blue: blueComponent, alpha: alphaComponent)
    }

    /// Get hex string representation of UIColor
    var hexString: String {
        guard let components = self.cgColor.components else {
            return "#000000"
        }

        let redFloat = Float(components[0])
        let greenFloat = Float(components.count > 1 ? components[1] : 0)
        let blueFloat = Float(components.count > 2 ? components[2] : 0)

        return String(format: "#%02lX%02lX%02lX",
                     lroundf(redFloat * 255),
                     lroundf(greenFloat * 255),
                     lroundf(blueFloat * 255))
    }

    /// Get season accent UIColor
    /// - Parameter season: Season name
    /// - Returns: UIColor for the season accent
    static func seasonAccent(for season: String) -> UIColor {
        return UIColor(Color.seasonAccent(for: season))
    }
}

// MARK: - Color Utilities

extension Color {

    /// Calculate luminance of color for contrast calculations
    var luminance: Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Convert to linear RGB
        let linearRed = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        let linearGreen = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        let linearBlue = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)

        // Calculate luminance
        return 0.2126 * Double(linearRed) + 0.7152 * Double(linearGreen) + 0.0722 * Double(linearBlue)
    }

    /// Calculate contrast ratio between two colors
    /// - Parameter other: Color to compare against
    /// - Returns: Contrast ratio (1:1 to 21:1)
    func contrastRatio(with other: Color) -> Double {
        let luminance1 = self.luminance
        let luminance2 = other.luminance

        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)

        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Check if color meets WCAG accessibility standards
    /// - Parameters:
    ///   - background: Background color
    ///   - level: WCAG level (.aa or .aaa)
    /// - Returns: True if accessible
    func isAccessible(on background: Color, level: AccessibilityLevel = .aa) -> Bool {
        let contrast = self.contrastRatio(with: background)

        switch level {
        case .aa:
            return contrast >= 4.5
        case .aaa:
            return contrast >= 7.0
        }
    }

    /// Check if color is dark based on luminance
    /// - Returns: True if color is considered dark
    func isDark() -> Bool {
        return luminance < 0.5
    }
}

// MARK: - Supporting Types

enum AccessibilityLevel {
    case aa
    case aaa
}

// Additional color utilities for Season DNA
extension Color {

    /// Get season-specific accent color based on season name
    /// - Parameter seasonName: Name of the season
    /// - Returns: Accent color for the season
    static func seasonAccentColor(for seasonName: String) -> Color {
        let lowerName = seasonName.lowercased()

        if lowerName.contains("spring") {
            return Color(red: 1.0, green: 0.8, blue: 0.2) // Warm yellow
        } else if lowerName.contains("summer") {
            return Color(red: 0.4, green: 0.7, blue: 1.0) // Cool blue
        } else if lowerName.contains("autumn") {
            return Color(red: 0.9, green: 0.5, blue: 0.2) // Warm orange
        } else if lowerName.contains("winter") {
            return Color(red: 0.8, green: 0.2, blue: 0.6) // Cool magenta
        } else {
            return Color.gray // Fallback
        }
    }

    /// Get contrasting text color for better readability
    var contrastingTextColor: Color {
        return isDark() ? .white : .black
    }
}

// Helper extension for hex digit validation
private extension Character {
    var isHexDigit: Bool {
        return isNumber || ("a"..."f").contains(lowercased()) || ("A"..."F").contains(self)
    }
}
