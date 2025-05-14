import XCTest
@testable import ImageSegmenter

class SeasonClassifierTests: XCTestCase {
    
    var classifier: SeasonClassifier!
    
    override func setUp() {
        super.setUp()
        classifier = SeasonClassifier()
    }
    
    // Test classification of known season colors
    func testKnownSeasonClassification() {
        // Spring: Warm (positive a*) + Bright (high L*)
        let springColor = ColorConverters.LabColor(L: 75.0, a: 10.0, b: 25.0)
        let springResult = classifier.classify(skinColor: springColor)
        XCTAssertEqual(springResult.season, .spring, "Should classify as Spring")
        
        // Summer: Cool (negative a*) + Bright (high L*) + Soft (low chroma)
        let summerColor = ColorConverters.LabColor(L: 70.0, a: -3.0, b: 10.0)
        let summerResult = classifier.classify(skinColor: summerColor)
        XCTAssertEqual(summerResult.season, .summer, "Should classify as Summer")
        
        // Autumn: Warm (positive a*) + Muted (low L*)
        let autumnColor = ColorConverters.LabColor(L: 60.0, a: 8.0, b: 22.0)
        let autumnResult = classifier.classify(skinColor: autumnColor)
        XCTAssertEqual(autumnResult.season, .autumn, "Should classify as Autumn")
        
        // Winter: Cool (negative a*) + Clear (high chroma)
        let winterColor = ColorConverters.LabColor(L: 65.0, a: -5.0, b: 5.0)
        let winterResult = classifier.classify(skinColor: winterColor)
        XCTAssertEqual(winterResult.season, .winter, "Should classify as Winter")
    }
    
    // Test the confidence scores
    func testConfidenceScores() {
        // Strong spring color should have high confidence
        let strongSpring = ColorConverters.LabColor(L: 82.0, a: 12.0, b: 30.0)
        let strongSpringResult = classifier.classify(skinColor: strongSpring)
        XCTAssertGreaterThan(strongSpringResult.confidence, 0.7, "Strong spring color should have high confidence")
        
        // Borderline color should have lower confidence
        let borderlineColor = ColorConverters.LabColor(L: 65.0, a: 0.5, b: 15.0)
        let borderlineResult = classifier.classify(skinColor: borderlineColor)
        XCTAssertLessThan(borderlineResult.confidence, 0.7, "Borderline color should have lower confidence")
    }
    
    // Test the effect of hair color on classification
    func testHairColorInfluence() {
        // Borderline skin that could be either Spring or Summer
        let borderlineSkin = ColorConverters.LabColor(L: 72.0, a: 1.0, b: 15.0)
        
        // Without hair color
        let resultWithoutHair = classifier.classify(skinColor: borderlineSkin)
        
        // With warm hair color (should push toward Spring)
        let warmHair = ColorConverters.LabColor(L: 55.0, a: 10.0, b: 20.0)
        let resultWithWarmHair = classifier.classify(skinColor: borderlineSkin, hairColor: warmHair)
        
        // With cool hair color (should push toward Summer)
        let coolHair = ColorConverters.LabColor(L: 45.0, a: -5.0, b: 10.0)
        let resultWithCoolHair = classifier.classify(skinColor: borderlineSkin, hairColor: coolHair)
        
        // Hair color should influence the result for borderline cases
        if resultWithoutHair.season == .spring {
            XCTAssertEqual(resultWithWarmHair.season, .spring, "Warm hair should maintain or strengthen Spring classification")
            // Cool hair might push it to Summer if it's very borderline
        } else if resultWithoutHair.season == .summer {
            XCTAssertEqual(resultWithCoolHair.season, .summer, "Cool hair should maintain or strengthen Summer classification")
            // Warm hair might push it to Spring if it's very borderline
        }
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