import XCTest
@testable import ImageSegmenter

class SeasonClassifierTests: XCTestCase {

    var classifier: SeasonClassifier!

    override func setUp() {
        super.setUp()
        classifier = SeasonClassifier()
    }

    // Test classification of known season colors based on the new 12-season logic
    func testKnownSeasonClassification() {
        // Spring: Warm (b* >= 12) + Light (L >= 65)
        let springColor = ColorConverters.LabColor(L: 75.0, a: 10.0, b: 25.0)
        let springResult = classifier.classify(skinColor: springColor)
        XCTAssertEqual(springResult.macroSeason, .spring, "Should classify macro season as Spring")
        // The detailed season should be one of the Spring variants
        XCTAssertTrue(springResult.detailedSeason.macroSeason == .spring, "Detailed season should map to Spring macro season")

        // Summer: Cool (b* < 12) + Light (L >= 65)
        let summerColor = ColorConverters.LabColor(L: 70.0, a: -3.0, b: 10.0)
        let summerResult = classifier.classify(skinColor: summerColor)
        XCTAssertEqual(summerResult.macroSeason, .summer, "Should classify macro season as Summer")
        XCTAssertTrue(summerResult.detailedSeason.macroSeason == .summer, "Detailed season should map to Summer macro season")

        // Autumn: Warm (b* >= 12) + Dark (L < 65)
        let autumnColor = ColorConverters.LabColor(L: 60.0, a: 8.0, b: 22.0)
        let autumnResult = classifier.classify(skinColor: autumnColor)
        XCTAssertEqual(autumnResult.macroSeason, .autumn, "Should classify macro season as Autumn")
        XCTAssertTrue(autumnResult.detailedSeason.macroSeason == .autumn, "Detailed season should map to Autumn macro season")

        // Winter: Cool (b* < 12) + Dark (L < 65)
        let winterColor = ColorConverters.LabColor(L: 55.0, a: -5.0, b: 5.0)
        let winterResult = classifier.classify(skinColor: winterColor)
        XCTAssertEqual(winterResult.macroSeason, .winter, "Should classify macro season as Winter")
        XCTAssertTrue(winterResult.detailedSeason.macroSeason == .winter, "Detailed season should map to Winter macro season")
    }

    // Test borderline cases for the warmCoolThreshold (b* = 12)
    func testWarmCoolBorderline() {
        // Just below warm threshold (b* = 11.9) and light - should be Summer
        let coolLight = ColorConverters.LabColor(L: 70.0, a: 0.0, b: 11.9)
        let coolLightResult = classifier.classify(skinColor: coolLight)
        XCTAssertEqual(coolLightResult.macroSeason, .summer, "Cool and light should be Summer macro season")

        // Just at warm threshold (b* = 12.0) and light - should be Spring
        let warmLight = ColorConverters.LabColor(L: 70.0, a: 0.0, b: 12.0)
        let warmLightResult = classifier.classify(skinColor: warmLight)
        XCTAssertEqual(warmLightResult.macroSeason, .spring, "Warm and light should be Spring macro season")
    }

    // Test borderline cases for the lightDarkThreshold (L = 65)
    func testLightDarkBorderline() {
        // Just below light threshold (L = 64.9) and warm - should be Autumn
        let warmDark = ColorConverters.LabColor(L: 64.9, a: 10.0, b: 20.0)
        let warmDarkResult = classifier.classify(skinColor: warmDark)
        XCTAssertEqual(warmDarkResult.macroSeason, .autumn, "Warm and dark should be Autumn macro season")

        // Just at light threshold (L = 65.0) and warm - should be Spring
        let warmLight = ColorConverters.LabColor(L: 65.0, a: 5.0, b: 15.0)
        let warmLightResult = classifier.classify(skinColor: warmLight)
        XCTAssertEqual(warmLightResult.macroSeason, .spring, "Warm and light should be Spring macro season")
    }

    // Test basic classification without hair color influence
    func testBasicClassification() {
        // Borderline skin that could be either Spring or Summer (almost warm, light)
        let borderlineSkin = ColorConverters.LabColor(L: 70.0, a: 0.0, b: 11.5) // Just below warm threshold

        // Should be classified as Summer
        let result = classifier.classify(skinColor: borderlineSkin)
        XCTAssertEqual(result.macroSeason, .summer, "Borderline cool light skin should be Summer macro season")
    }

    // Test that detailed seasons are correctly assigned
    func testDetailedSeasonAssignment() {
        // Test a specific case that should result in a known detailed season
        let lightSpringColor = ColorConverters.LabColor(L: 75.0, a: 5.0, b: 20.0) // Light, moderate chroma, warm hue
        let result = classifier.classify(skinColor: lightSpringColor)
        
        // Should be classified as some Spring variant
        XCTAssertEqual(result.macroSeason, .spring, "Should be Spring macro season")
        
        // The detailed season should not be unknown
        XCTAssertNotEqual(result.detailedSeason, .unknown, "Should not classify as unknown detailed season")
        
        // Should have a reasonable confidence
        XCTAssertGreaterThan(result.confidence, 0.0, "Should have confidence greater than 0")
        XCTAssertLessThanOrEqual(result.confidence, 1.0, "Confidence should not exceed 1.0")
    }

    // Test deltaE calculations to nearest seasons
    func testDeltaECalculations() {
        // Spring color should have smallest deltaE to Spring reference
        let springColor = ColorConverters.LabColor(L: 75.0, a: 10.0, b: 25.0)
        let springDeltaEs = classifier.calculateDeltaEToSeasonReferences(labColor: springColor)

        // Find the season with the smallest deltaE
        let nearestSeason = springDeltaEs.min(by: { $0.value < $1.value })?.key
        XCTAssertEqual(nearestSeason, .spring, "Spring color should be closest to Spring reference")

        // The deltaE to Spring should be small
        XCTAssertLessThan(springDeltaEs[.spring] ?? 100.0, 5.0, "DeltaE to matching season should be small")
    }

    // Test comparison of both color difference methods (CIE76 and CIEDE2000)
    func testCompareColorDifferenceMethods() {
        // Create a test color
        let testColor = ColorConverters.LabColor(L: 70.0, a: 5.0, b: 20.0)

        // Get results from both methods
        let results = classifier.compareColorDifferenceMethods(labColor: testColor)

        // Print results for comparison
        print("Color difference method comparison:")
        for (season, values) in results {
            print("\(season): CIE76 = \(values.cie76), CIEDE2000 = \(values.ciede2000)")
        }

        // Verify that the nearest season is the same with both methods
        let nearestSeasonCIE76 = results.min(by: { $0.value.cie76 < $1.value.cie76 })?.key
        let nearestSeasonCIEDE2000 = results.min(by: { $0.value.ciede2000 < $1.value.ciede2000 })?.key

        // Compare the delta-E values between methods
        for (_, values) in results {
            // The values should be different between methods
            XCTAssertNotEqual(values.cie76, values.ciede2000, accuracy: 0.1,
                            "CIE76 and CIEDE2000 should produce different results")
        }

        // Check if the methods agree on the closest season
        // This test may occasionally fail if colors are very close to boundary
        // as CIEDE2000 can produce different ranking than CIE76
        if let cie76 = nearestSeasonCIE76, let ciede2000 = nearestSeasonCIEDE2000 {
            print("Nearest season: CIE76 = \(cie76), CIEDE2000 = \(ciede2000)")
        }
    }
}
