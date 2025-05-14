// swiftlint:disable identifier_name
import UIKit
import simd

/// Convenience color utilities
class ColorUtils {
    /// Convert RGB color to Lab values
    /// - Parameter color: UIColor to convert
    /// - Returns: Lab values as a tuple (L, a, b)
    static func convertRGBToLab(color: UIColor) -> (L: CGFloat, a: CGFloat, b: CGFloat) {
        let labColor = ColorConverters.colorToLab(color)
        return (labColor.L, labColor.a, labColor.b)
    }

    /// Calculate the color difference (ΔE) between two Lab colors using CIEDE2000 formula
    /// - Parameters:
    ///   - lab1: First Lab color as (L, a, b) tuple
    ///   - lab2: Second Lab color as (L, a, b) tuple
    /// - Returns: Color difference value
    static func deltaE2000(lab1: (L: CGFloat, a: CGFloat, b: CGFloat),
                          lab2: (L: CGFloat, a: CGFloat, b: CGFloat)) -> CGFloat {
        let color1 = ColorConverters.LabColor(L: lab1.L, a: lab1.a, b: lab1.b)
        let color2 = ColorConverters.LabColor(L: lab2.L, a: lab2.a, b: lab2.b)
        return color1.deltaE2000(to: color2)
    }
}

/// Color conversion utilities for image analysis
struct ColorConverters {

    /// CIELAB color representation
    struct LabColor {
        let L: CGFloat  // Lightness (0-100)
        let a: CGFloat  // Green-Red (-128 to +127)
        let b: CGFloat  // Blue-Yellow (-128 to +127)

        /// Calculate the color difference (ΔE) between two Lab colors using CIE76 formula
        func deltaE(to other: LabColor) -> CGFloat {
            let deltaL = L - other.L
            let deltaA = a - other.a
            let deltaB = b - other.b

            // CIE76 color difference formula
            return sqrt(deltaL * deltaL + deltaA * deltaA + deltaB * deltaB)
        }

        /// Calculate the color difference (ΔE) between two Lab colors using CIEDE2000 formula
        func deltaE2000(to other: LabColor) -> CGFloat {
            // Convert Lab values to the ranges used by the CIEDE2000 formula
            let L1 = Double(L)
            let a1 = Double(a)
            let b1 = Double(b)

            let L2 = Double(other.L)
            let a2 = Double(other.a)
            let b2 = Double(other.b)

            // Calculate CIEDE2000 (simplified implementation)
            let kL = 1.0  // Lightness parameter
            let kC = 1.0  // Chroma parameter
            let kH = 1.0  // Hue parameter

            // Step 1: Calculate C1, C2, C̄, ΔL′, ΔC′, ΔH′
            let C1 = sqrt(a1 * a1 + b1 * b1)
            let C2 = sqrt(a2 * a2 + b2 * b2)
            let Cbar = (C1 + C2) / 2.0

            // Compensate a values
            let G = 0.5 * (1.0 - sqrt(pow(Cbar, 7) / (pow(Cbar, 7) + pow(25.0, 7))))
            let a1Prime = a1 * (1.0 + G)
            let a2Prime = a2 * (1.0 + G)

            // Recalculate C values
            let C1Prime = sqrt(a1Prime * a1Prime + b1 * b1)
            let C2Prime = sqrt(a2Prime * a2Prime + b2 * b2)
            let CbarPrime = (C1Prime + C2Prime) / 2.0

            // Calculate h' values
            var h1Prime = atan2(b1, a1Prime) * 180.0 / Double.pi
            if h1Prime < 0.0 { h1Prime += 360.0 }

            var h2Prime = atan2(b2, a2Prime) * 180.0 / Double.pi
            if h2Prime < 0.0 { h2Prime += 360.0 }

            // Calculate ΔH'
            var deltaHPrime: Double
            let diffHPrime = h2Prime - h1Prime

            if C1Prime * C2Prime == 0.0 {
                deltaHPrime = 0.0
            } else if abs(diffHPrime) <= 180.0 {
                deltaHPrime = diffHPrime
            } else if diffHPrime > 180.0 {
                deltaHPrime = diffHPrime - 360.0
            } else {
                deltaHPrime = diffHPrime + 360.0
            }

            // Calculate ΔH'
            let deltaLPrime = L2 - L1
            let deltaCPrime = C2Prime - C1Prime
            deltaHPrime = 2.0 * sqrt(C1Prime * C2Prime) * sin(deltaHPrime * Double.pi / 360.0)

            // Calculate CIEDE2000 components
            let Lbar = (L1 + L2) / 2.0
            let SL = 1.0 + (0.015 * pow(Lbar - 50.0, 2)) / sqrt(20.0 + pow(Lbar - 50.0, 2))
            let SC = 1.0 + 0.045 * CbarPrime
            let T = 1.0 - 0.17 * cos((CbarPrime - 30.0) * Double.pi / 180.0) +
                   0.24 * cos(2.0 * CbarPrime * Double.pi / 180.0) +
                   0.32 * cos((3.0 * CbarPrime + 6.0) * Double.pi / 180.0) -
                   0.20 * cos((4.0 * CbarPrime - 63.0) * Double.pi / 180.0)
            let SH = 1.0 + 0.015 * CbarPrime * T

            let hbarPrime = (h1Prime + h2Prime) / 2.0
            let deltaTheta = 30.0 * exp(-pow((hbarPrime - 275.0) / 25.0, 2))
            let RC = 2.0 * sqrt(pow(CbarPrime, 7) / (pow(CbarPrime, 7) + pow(25.0, 7)))
            let RT = -RC * sin(2.0 * deltaTheta * Double.pi / 180.0)

            // Calculate final CIEDE2000 value
            let deltaE = sqrt(
                pow(deltaLPrime / (kL * SL), 2) +
                pow(deltaCPrime / (kC * SC), 2) +
                pow(deltaHPrime / (kH * SH), 2) +
                RT * (deltaCPrime / (kC * SC)) * (deltaHPrime / (kH * SH))
            )

            return CGFloat(deltaE)
        }

        /// Convert Lab color to UIColor (for use with ColorKit)
        private func labToUIColor(_ lab: LabColor) -> UIColor {
            // Since ColorKit doesn't have a direct constructor for Lab colors,
            // we'll convert to RGB first and create a UIColor
            var red: CGFloat = 0.0
            var green: CGFloat = 0.0
            var blue: CGFloat = 0.0

            // Simple Lab to RGB conversion for ColorKit compatibility
            // This is a simplification, but should work for our comparisons
            return UIColor(red: lab.L/100.0,
                          green: (lab.a + 128)/255.0,
                          blue: (lab.b + 128)/255.0,
                          alpha: 1.0)
        }
    }

    /// Convert RGB to CIELAB color space using GPU-accelerated matrix math
    /// - Parameters:
    ///   - red: Red component (0-1)
    ///   - green: Green component (0-1)
    ///   - blue: Blue component (0-1)
    /// - Returns: CIELAB color values
    static func rgbToLab(red: CGFloat, green: CGFloat, blue: CGFloat) -> LabColor {

        // --- sRGB → Linear RGB ---
        let rgb = simd_float3(Float(red), Float(green), Float(blue))
        let linear = simd_float3(
            rgba_to_linear(rgb.x),
            rgba_to_linear(rgb.y),
            rgba_to_linear(rgb.z)
        )

        // --- Linear RGB → XYZ (D65) ---
        let rgbToXYZ = simd_float3x3(
            simd_float3(0.4124564, 0.2126729, 0.0193339),
            simd_float3(0.3575761, 0.7151522, 0.1191920),
            simd_float3(0.1804375, 0.0721750, 0.9503041)
        )
        let xyz = rgbToXYZ * linear

        // --- XYZ → Lab ---
        let white = simd_float3(0.95047, 1.00000, 1.08883)      // D65
        let xr = xyz.x / white.x
        let yr = xyz.y / white.y
        let zr = xyz.z / white.z

        let fx = xyz_to_lab(xr)
        let fy = xyz_to_lab(yr)
        let fz = xyz_to_lab(zr)

        let L = max(0, 116 * fy - 16)
        let a = 500 * (fx - fy)
        let b = 200 * (fy - fz)

        return LabColor(L: CGFloat(L), a: CGFloat(a), b: CGFloat(b))
    }

    /// Convert UIColor to Lab
    static func colorToLab(_ color: UIColor) -> LabColor {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return rgbToLab(red: red, green: green, blue: blue)
    }

    // MARK: - Helper functions

    /// Convert sRGB component to linear RGB
    private static func rgba_to_linear(_ c: Float) -> Float {
        if c <= 0.04045 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }

    /// XYZ to Lab conversion helper function
    private static func xyz_to_lab(_ c: Float) -> Float {
        let epsilon: Float = 0.008856
        let kappa: Float = 903.3

        if c > epsilon {
            return pow(c, 1.0 / 3.0)
        } else {
            return (kappa * c + 16.0) / 116.0
        }
    }
}

// MARK: - UIColor extension for Lab color

extension UIColor {
    /// Convert UIColor to Lab color space
    var labColor: ColorConverters.LabColor {
        return ColorConverters.colorToLab(self)
    }

    /// Calculate the color difference (ΔE) to another color using CIE76
    func deltaE(to otherColor: UIColor) -> CGFloat {
        return self.labColor.deltaE(to: otherColor.labColor)
    }

    /// Calculate the color difference (ΔE) to another color using CIEDE2000
    func deltaE2000(to otherColor: UIColor) -> CGFloat {
        return self.labColor.deltaE2000(to: otherColor.labColor)
    }
}
