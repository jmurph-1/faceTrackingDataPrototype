//
//  ContrastCalculator.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/27/25.
//

import UIKit
import CoreGraphics

struct ContrastCalculator {
    
    // MARK: - Main Contrast Calculation
    
    /// Calculates the overall contrast level between facial features
    /// - Parameters:
    ///   - skinColor: Average color of skin
    ///   - hairColor: Average color of hair
    ///   - eyeColor: Average color of eyes
    /// - Returns: Contrast value from 0.0 (low) to 1.0 (high)
    static func calculateFeatureContrast(skinColor: UIColor, hairColor: UIColor, eyeColor: UIColor) -> Double {
        // Use the existing ColorConverters to get Lab colors
        let skinLab = ColorConverters.colorToLab(skinColor)
        let hairLab = ColorConverters.colorToLab(hairColor)
        let eyeLab = ColorConverters.colorToLab(eyeColor)
        
        // Calculate individual contrasts using the existing deltaE2000 method
        let skinHairContrast = skinLab.deltaE2000(to: hairLab)
        let skinEyeContrast = skinLab.deltaE2000(to: eyeLab)
        let hairEyeContrast = hairLab.deltaE2000(to: eyeLab)
        
        // Weight the contrasts (skin-hair is most important for seasonal analysis)
        let weightedContrast = (Double(skinHairContrast) * 0.5) +
                              (Double(skinEyeContrast) * 0.3) +
                              (Double(hairEyeContrast) * 0.2)
        
        // Normalize to 0-1 scale
        // Delta E values: 0-25 (low), 25-50 (medium), 50-100 (high)
        // We'll map 0-100 to 0-1, with sigmoid smoothing
        return normalizeContrast(deltaE: weightedContrast)
    }
    
    /// Calculates contrast using simpler luminance-based method
    /// - Parameters:
    ///   - skinColor: Average color of skin
    ///   - hairColor: Average color of hair
    ///   - eyeColor: Average color of eyes
    /// - Returns: Contrast value from 0.0 (low) to 1.0 (high)
    static func calculateSimpleContrast(skinColor: UIColor, hairColor: UIColor, eyeColor: UIColor) -> Double {
        let skinLuminance = getLuminance(color: skinColor)
        let hairLuminance = getLuminance(color: hairColor)
        let eyeLuminance = getLuminance(color: eyeColor)
        
        // Calculate luminance differences
        let skinHairDiff = abs(skinLuminance - hairLuminance)
        let skinEyeDiff = abs(skinLuminance - eyeLuminance)
        let hairEyeDiff = abs(hairLuminance - eyeLuminance)
        
        // Weight the differences
        let weightedDiff = (skinHairDiff * 0.5) + (skinEyeDiff * 0.3) + (hairEyeDiff * 0.2)
        
        // Luminance differences range from 0 to 1, no normalization needed
        return weightedDiff
    }
    
    // MARK: - Contrast Level Classification
    
    enum ContrastLevel: String {
        case low = "low"
        case lowMedium = "low-medium"
        case medium = "medium"
        case mediumHigh = "medium-high"
        case high = "high"
        
        static func fromValue(_ value: Double) -> ContrastLevel {
            switch value {
            case 0..<0.2:
                return .low
            case 0.2..<0.4:
                return .lowMedium
            case 0.4..<0.6:
                return .medium
            case 0.6..<0.8:
                return .mediumHigh
            default:
                return .high
            }
        }
        
        var description: String {
            switch self {
            case .low:
                return "Your features blend together harmoniously with minimal contrast"
            case .lowMedium:
                return "Your features have gentle, subtle contrast"
            case .medium:
                return "Your features have balanced, moderate contrast"
            case .mediumHigh:
                return "Your features show clear distinction with noticeable contrast"
            case .high:
                return "Your features have striking, dramatic contrast"
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private static func getLuminance(color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Use relative luminance formula
        return 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
    }
    
    private static func normalizeContrast(deltaE: Double) -> Double {
        // Use sigmoid function to smooth the mapping
        // Delta E of 50 maps to ~0.5, 100 maps to ~0.88
        let normalized = 1.0 / (1.0 + exp(-0.04 * (deltaE - 50.0)))
        return min(max(normalized, 0.0), 1.0)
    }
    
    // MARK: - Analysis Result
    
    struct ContrastAnalysisResult {
        let value: Double
        let level: ContrastLevel
        let description: String
        let skinHairContrast: Double
        let skinEyeContrast: Double
        let hairEyeContrast: Double
        
        var recommendation: String {
            switch level {
            case .low:
                return "Your low contrast coloring suits soft, muted color palettes best. Look for seasons like Soft Summer or Soft Autumn."
            case .lowMedium:
                return "Your gentle contrast works well with slightly muted colors. Consider Light or Soft seasonal palettes."
            case .medium:
                return "Your balanced contrast gives you flexibility. True seasons or those with medium depth may suit you well."
            case .mediumHigh:
                return "Your clear contrast can handle more saturated colors. Consider Clear or Deep seasonal palettes."
            case .high:
                return "Your dramatic contrast is enhanced by bold, clear colors. Winter palettes often work well for high contrast."
            }
        }
    }
    
    static func analyzeContrast(skinColor: UIColor, hairColor: UIColor, eyeColor: UIColor) -> ContrastAnalysisResult {
        // Use the existing ColorConverters for Lab conversion
        let skinLab = ColorConverters.colorToLab(skinColor)
        let hairLab = ColorConverters.colorToLab(hairColor)
        let eyeLab = ColorConverters.colorToLab(eyeColor)
        
        // Calculate individual contrasts using deltaE2000
        let skinHairContrast = Double(skinLab.deltaE2000(to: hairLab))
        let skinEyeContrast = Double(skinLab.deltaE2000(to: eyeLab))
        let hairEyeContrast = Double(hairLab.deltaE2000(to: eyeLab))
        
        // Calculate overall contrast value
        let overallValue = calculateFeatureContrast(skinColor: skinColor, hairColor: hairColor, eyeColor: eyeColor)
        let level = ContrastLevel.fromValue(overallValue)
        
        return ContrastAnalysisResult(
            value: overallValue,
            level: level,
            description: level.description,
            skinHairContrast: normalizeContrast(deltaE: skinHairContrast),
            skinEyeContrast: normalizeContrast(deltaE: skinEyeContrast),
            hairEyeContrast: normalizeContrast(deltaE: hairEyeContrast)
        )
    }
}

// MARK: - Usage Example

extension ContrastCalculator {
    static func example() {
        // Example colors extracted from MediaPipe segmentation
        let skinColor = UIColor(red: 0.85, green: 0.75, blue: 0.65, alpha: 1.0) // Light skin
        let hairColor = UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)   // Dark hair
        let eyeColor = UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0)     // Blue eyes
        
        let result = analyzeContrast(skinColor: skinColor, hairColor: hairColor, eyeColor: eyeColor)
        
        print("Contrast Analysis:")
        print("Overall Value: \(String(format: "%.2f", result.value))")
        print("Level: \(result.level.rawValue)")
        print("Description: \(result.description)")
        print("Recommendation: \(result.recommendation)")
        print("\nDetailed Contrasts:")
        print("Skin-Hair: \(String(format: "%.2f", result.skinHairContrast))")
        print("Skin-Eye: \(String(format: "%.2f", result.skinEyeContrast))")
        print("Hair-Eye: \(String(format: "%.2f", result.hairEyeContrast))")
    }
}
