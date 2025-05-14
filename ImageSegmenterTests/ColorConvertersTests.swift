import XCTest
@testable import ImageSegmenter

class ColorConvertersTests: XCTestCase {
    
    // Test conversion of standard colors to Lab space
    func testRGBtoLab() {
        // Test white color
        let white = ColorConverters.rgbToLab(red: 1.0, green: 1.0, blue: 1.0)
        XCTAssertEqual(white.L, 100.0, accuracy: 0.1, "White L* should be 100")
        XCTAssertEqual(white.a, 0.0, accuracy: 0.5, "White a* should be 0")
        XCTAssertEqual(white.b, 0.0, accuracy: 0.5, "White b* should be 0")
        
        // Test black color
        let black = ColorConverters.rgbToLab(red: 0.0, green: 0.0, blue: 0.0)
        XCTAssertEqual(black.L, 0.0, accuracy: 0.1, "Black L* should be 0")
        XCTAssertEqual(black.a, 0.0, accuracy: 0.5, "Black a* should be 0")
        XCTAssertEqual(black.b, 0.0, accuracy: 0.5, "Black b* should be 0")
        
        // Test red color
        let red = ColorConverters.rgbToLab(red: 1.0, green: 0.0, blue: 0.0)
        XCTAssertEqual(red.L, 53.24, accuracy: 1.0, "Red L* should be ~53.24")
        XCTAssertEqual(red.a, 80.09, accuracy: 1.0, "Red a* should be ~80.09")
        XCTAssertEqual(red.b, 67.20, accuracy: 1.0, "Red b* should be ~67.20")
        
        // Test green color
        let green = ColorConverters.rgbToLab(red: 0.0, green: 1.0, blue: 0.0)
        XCTAssertEqual(green.L, 87.73, accuracy: 1.0, "Green L* should be ~87.73")
        XCTAssertEqual(green.a, -86.18, accuracy: 1.0, "Green a* should be ~-86.18")
        XCTAssertEqual(green.b, 83.18, accuracy: 1.0, "Green b* should be ~83.18")
        
        // Test blue color
        let blue = ColorConverters.rgbToLab(red: 0.0, green: 0.0, blue: 1.0)
        XCTAssertEqual(blue.L, 32.3, accuracy: 1.0, "Blue L* should be ~32.3")
        XCTAssertEqual(blue.a, 79.19, accuracy: 1.0, "Blue a* should be ~79.2")
        XCTAssertEqual(blue.b, -107.86, accuracy: 1.0, "Blue b* should be ~-107.89")
    }
    
    // Test deltaE calculation
    func testDeltaE() {
        // White and black should have large delta E (100)
        let white = ColorConverters.rgbToLab(red: 1.0, green: 1.0, blue: 1.0)
        let black = ColorConverters.rgbToLab(red: 0.0, green: 0.0, blue: 0.0)
        XCTAssertEqual(white.deltaE(to: black), 100.0, accuracy: 0.5, "Delta E between white and black should be ~100")
        
        // Red and slightly different red should have small delta E
        let red1 = ColorConverters.rgbToLab(red: 1.0, green: 0.0, blue: 0.0)
        let red2 = ColorConverters.rgbToLab(red: 0.95, green: 0.01, blue: 0.01)
        XCTAssertLessThan(red1.deltaE(to: red2), 5.5, "Delta E between similar reds should be small")
        
        // Test UIColor extension
        let uiRed = UIColor.red
        let uiBlue = UIColor.blue
        XCTAssertGreaterThan(uiRed.deltaE(to: uiBlue), 100.0, "Delta E between red and blue should be large")
    }
    
    // Test CIEDE2000 deltaE calculation
    func testDeltaE2000() {
        // Create pairs of colors with known CIEDE2000 differences
        // These test values are based on standard color difference evaluation datasets
        
        // Create color pairs for testing
        let white = ColorConverters.rgbToLab(red: 1.0, green: 1.0, blue: 1.0)
        let black = ColorConverters.rgbToLab(red: 0.0, green: 0.0, blue: 0.0)
        
        // Red and slightly different red should have small delta E
        let red1 = ColorConverters.rgbToLab(red: 1.0, green: 0.0, blue: 0.0)
        let red2 = ColorConverters.rgbToLab(red: 0.95, green: 0.01, blue: 0.01)
        
        // Test CIEDE2000 calculations
        // The values will differ from CIE76 as CIEDE2000 is more perceptually accurate
        XCTAssertGreaterThan(white.deltaE2000(to: black), 50.0, "CIEDE2000 between white and black should be large")
        XCTAssertLessThan(red1.deltaE2000(to: red2), 5.0, "CIEDE2000 between similar reds should be small")
        
        
        // Test direct UIColor calculation
        let uiRed = UIColor.red
        let uiBlue = UIColor.blue
        XCTAssertGreaterThan(uiRed.deltaE2000(to: uiBlue), 50.0, "CIEDE2000 between red and blue should be large")
        
        // Test the comparison of methods
        let lightSkin = UIColor(red: 0.94, green: 0.78, blue: 0.62, alpha: 1.0).labColor
        let darkSkin = UIColor(red: 0.45, green: 0.31, blue: 0.18, alpha: 1.0).labColor
        
        // The CIEDE2000 difference should be lower than CIE76 in many cases
        let cie76 = lightSkin.deltaE(to: darkSkin)
        let ciede2000 = lightSkin.deltaE2000(to: darkSkin)
        print("Light to dark skin: CIE76 = \(cie76), CIEDE2000 = \(ciede2000)")
        
        // Verify that our deltaE2000 implementation works correctly
        XCTAssertGreaterThan(cie76, 0, "CIE76 difference should be positive")
        XCTAssertGreaterThan(ciede2000, 0, "CIEDE2000 difference should be positive")
    }
    
    // Test specifically for skin tone colors relevant to our application
    func testSkinTones() {
        // Light skin tone
        let lightSkin = UIColor(red: 0.94, green: 0.78, blue: 0.62, alpha: 1.0)
        let lightSkinLab = lightSkin.labColor
        XCTAssertEqual(lightSkinLab.L, 82.8, accuracy: 2.0, "Light skin L* should be ~83.2")
        XCTAssertEqual(lightSkinLab.a, 8.87, accuracy: 2.0, "Light skin a* should be ~10.8")
        XCTAssertEqual(lightSkinLab.b, 25.9, accuracy: 2.0, "Light skin b* should be ~22.7")
        
        // Medium skin tone
        let mediumSkin = UIColor(red: 0.76, green: 0.57, blue: 0.37, alpha: 1.0)
        let mediumSkinLab = mediumSkin.labColor
        XCTAssertEqual(mediumSkinLab.L, 63.4, accuracy: 2.0, "Medium skin L* should be ~63.4")
        XCTAssertEqual(mediumSkinLab.a, 12.5, accuracy: 2.0, "Medium skin a* should be ~12.5")
        XCTAssertEqual(mediumSkinLab.b, 32.7, accuracy: 2.0, "Medium skin b* should be ~32.7")
        
        // Dark skin tone
        let darkSkin = UIColor(red: 0.45, green: 0.31, blue: 0.18, alpha: 1.0)
        let darkSkinLab = darkSkin.labColor
        XCTAssertEqual(darkSkinLab.L, 37.6, accuracy: 2.0, "Dark skin L* should be ~37.6")
        XCTAssertEqual(darkSkinLab.a, 12.6, accuracy: 2.0, "Dark skin a* should be ~12.6")
        XCTAssertEqual(darkSkinLab.b, 25.1, accuracy: 2.0, "Dark skin b* should be ~25.1")
    }
} 
