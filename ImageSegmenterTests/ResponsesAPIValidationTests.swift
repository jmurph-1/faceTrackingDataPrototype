//
//  ResponsesAPIValidationTests.swift
//  ImageSegmenterTests
//
//  Created by Claude Code on 1/6/25.
//

import XCTest
@testable import ImageSegmenter

class ResponsesAPIValidationTests: XCTestCase {
    
    var personalizationService: PersonalizationService!
    var vectorStoreManager: VectorStoreManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        personalizationService = PersonalizationService()
        vectorStoreManager = VectorStoreManager.shared
        
        print("🧪 ResponsesAPI Validation Test Setup")
        print("🔧 Configuration Status:")
        AppConfiguration.shared.printConfigurationStatus()
    }
    
    override func tearDownWithError() throws {
        personalizationService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Full API Response Validation Test
    
    func testCompleteResponsesAPIResponseStructure() throws {
        let expectation = XCTestExpectation(description: "API returns complete response with seasonDNA and enhancedColorData")
        
        print("\n" + String(repeating: "=", count: 80))
        print("🧪 TESTING COMPLETE RESPONSES API RESPONSE STRUCTURE")
        print(String(repeating: "=", count: 80))
        
        // Create sample analysis result for True Spring
        let testAnalysisResult = createSampleTrueSpringAnalysisResult()
        let seasonData = createTestSeasonData()
        let detailedSeasonName = "True Spring"
        
        print("📊 Test Input:")
        print("   • Season: \(detailedSeasonName)")
        print("   • Skin Lab: L=\(testAnalysisResult.skinColorLab?.L ?? 0), a=\(testAnalysisResult.skinColorLab?.a ?? 0), b=\(testAnalysisResult.skinColorLab?.b ?? 0)")
        print("   • Hair Lab: L=\(testAnalysisResult.hairColorLab?.L ?? 0), a=\(testAnalysisResult.hairColorLab?.a ?? 0), b=\(testAnalysisResult.hairColorLab?.b ?? 0)")
        print("   • Eye Lab: L=\(testAnalysisResult.averageEyeColorLab?.L ?? 0), a=\(testAnalysisResult.averageEyeColorLab?.a ?? 0), b=\(testAnalysisResult.averageEyeColorLab?.b ?? 0)")
        print("   • Confidence: \(testAnalysisResult.confidence)")
        print("   • Contrast: \(testAnalysisResult.contrastLevel)")
        
        // Test the API call
        personalizationService.generateResponsesAPIPersonalization(
            for: testAnalysisResult,
            seasonData: seasonData,
            detailedSeasonName: detailedSeasonName
        ) { result in
            switch result {
            case .success(let personalizedData):
                print("\n✅ API CALL SUCCESSFUL")
                self.validateCompleteResponse(personalizedData, expectation: expectation)
                
            case .failure(let error):
                print("\n❌ API CALL FAILED")
                print("Error: \(error.localizedDescription)")
                
                // Still fulfill expectation but mark as failed
                XCTFail("API call failed: \(error.localizedDescription)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 60.0) // Longer timeout for API calls
    }
    
    // MARK: - Response Validation Methods
    
    private func validateCompleteResponse(_ response: PersonalizedSeasonData, expectation: XCTestExpectation) {
        print("\n" + String(repeating: "-", count: 60))
        print("📋 RESPONSE VALIDATION & DETAILED REVIEW")
        print(String(repeating: "-", count: 60))
        
        // 1. Basic Fields Validation
        validateBasicFields(response)
        
        // 2. Season DNA Validation
        validateSeasonDNAFields(response)
        
        // 3. Enhanced Color Data Validation
        validateEnhancedColorDataFields(response)
        
        // 4. Color Recommendations Validation
        validateColorRecommendations(response)
        
        // 5. Print Complete Response for Review
        printCompleteResponseForReview(response)
        
        print("\n✅ ALL VALIDATIONS PASSED - API RESPONSE IS COMPLETE")
        expectation.fulfill()
    }
    
    private func validateBasicFields(_ response: PersonalizedSeasonData) {
        print("\n🔍 BASIC FIELDS VALIDATION:")
        
        // Required string fields
        XCTAssertFalse(response.personalizedTagline.isEmpty, "personalizedTagline should not be empty")
        XCTAssertFalse(response.userCharacteristics.isEmpty, "userCharacteristics should not be empty")
        XCTAssertFalse(response.personalizedOverview.isEmpty, "personalizedOverview should not be empty")
        
        print("   ✅ personalizedTagline: Present (\(response.personalizedTagline.count) chars)")
        print("   ✅ userCharacteristics: Present (\(response.userCharacteristics.count) chars)")
        print("   ✅ personalizedOverview: Present (\(response.personalizedOverview.count) chars)")
        
        // Emphasized colors and colors to avoid
        XCTAssertGreaterThanOrEqual(response.emphasizedColors.count, 3, "emphasizedColors should have at least 3 colors")
        XCTAssertGreaterThanOrEqual(response.colorsToAvoid.count, 3, "colorsToAvoid should have at least 3 colors")
        
        print("   ✅ emphasizedColors: \(response.emphasizedColors.count) colors")
        print("   ✅ colorsToAvoid: \(response.colorsToAvoid.count) colors")
        
        // Confidence score
        XCTAssertGreaterThanOrEqual(response.confidence, 0.70, "confidence should be >= 0.70")
        XCTAssertLessThanOrEqual(response.confidence, 0.95, "confidence should be <= 0.95")
        
        print("   ✅ confidence: \(response.confidence)")
    }
    
    private func validateSeasonDNAFields(_ response: PersonalizedSeasonData) {
        print("\n🧬 SEASON DNA VALIDATION:")
        
        // Check if seasonDNAData exists (from API) or fallback is used
        if let seasonDNAData = response.seasonDNAData {
            print("   ✅ seasonDNAData: Present (from API response)")
            print("   • Primary: \(seasonDNAData.primary.season) (\(seasonDNAData.primary.weight))")
            
            if let secondary = seasonDNAData.secondary {
                print("   • Secondary: \(secondary.season) (\(secondary.weight))")
            } else {
                print("   • Secondary: None")
            }
            
            if let tertiary = seasonDNAData.tertiary {
                print("   • Tertiary: \(tertiary.season) (\(tertiary.weight))")
            } else {
                print("   • Tertiary: None")
            }
            
            print("   • Explanation: \(seasonDNAData.explanation.prefix(100))...")
            print("   • Classification Confidence: \(seasonDNAData.classificationConfidence)")
            
            // Validate season weights
            XCTAssertGreaterThan(seasonDNAData.primary.weight, 0.0, "Primary season weight should be > 0")
            XCTAssertLessThanOrEqual(seasonDNAData.primary.weight, 1.0, "Primary season weight should be <= 1.0")
            
        } else {
            print("   ⚠️  seasonDNAData: Not present in API response (using fallback)")
        }
        
        // The computed seasonDNA property should always be available
        let seasonDNA = response.seasonDNA
        XCTAssertFalse(seasonDNA.explanation.isEmpty, "seasonDNA explanation should not be empty")
        
        print("   ✅ seasonDNA (computed): Always available")
        print("   • Primary: \(seasonDNA.primary.season) (\(seasonDNA.primary.weight))")
        print("   • Is Blended: \(!seasonDNA.isPureMatch)")
    }
    
    private func validateEnhancedColorDataFields(_ response: PersonalizedSeasonData) {
        print("\n🎨 ENHANCED COLOR DATA VALIDATION:")
        
        if let enhancedColorData = response.enhancedColorData {
            print("   ✅ enhancedColorData: Present (from API response)")
            
            // Validate each category
            validateColorCategory("bestNeutrals", enhancedColorData.bestNeutrals)
            validateColorCategory("bestAccents", enhancedColorData.bestAccents)
            validateColorCategory("bestBaseColors", enhancedColorData.bestBaseColors)
            
            if let hairColorSuggestions = enhancedColorData.hairColorSuggestions {
                validateColorCategory("hairColorSuggestions", hairColorSuggestions)
            } else {
                print("   • hairColorSuggestions: Not provided")
            }
            
        } else {
            print("   ❌ enhancedColorData: NOT PRESENT in API response")
            XCTFail("enhancedColorData should be present in API response")
        }
    }
    
    private func validateColorCategory(_ categoryName: String, _ category: DetailedColorRecommendation) {
        print("   📋 \(categoryName):")
        print("     • Description: \(category.description.prefix(50))...")
        print("     • Colors: \(category.colors.count)")
        print("     • Priority: \(category.priority)")
        print("     • Usage Instructions: \(category.usageInstructions.prefix(50))...")
        
        // Validate color count (should be 3-4 colors)
        XCTAssertGreaterThanOrEqual(category.colors.count, 3, "\(categoryName) should have at least 3 colors")
        XCTAssertLessThanOrEqual(category.colors.count, 4, "\(categoryName) should have at most 4 colors")
        
        // Validate each color item
        for (index, colorItem) in category.colors.enumerated() {
            XCTAssertFalse(colorItem.name.isEmpty, "\(categoryName)[\(index)] name should not be empty")
            XCTAssertTrue(colorItem.hexValue.hasPrefix("#"), "\(categoryName)[\(index)] hexValue should start with #")
            XCTAssertEqual(colorItem.hexValue.count, 7, "\(categoryName)[\(index)] hexValue should be 7 characters (#RRGGBB)")
            XCTAssertFalse(colorItem.usageContext.isEmpty, "\(categoryName)[\(index)] usageContext should not be empty")
            XCTAssertFalse(colorItem.harmonyReason.isEmpty, "\(categoryName)[\(index)] harmonyReason should not be empty")
            
            print("       [\(index)] \(colorItem.name): \(colorItem.hexValue)")
        }
    }
    
    private func validateColorRecommendations(_ response: PersonalizedSeasonData) {
        print("\n🎯 COLOR RECOMMENDATIONS VALIDATION:")
        
        let colorRecs = response.colorRecommendations
        
        // Validate each legacy category
        validateLegacyColorCategory("bestNeutrals", colorRecs.bestNeutrals)
        validateLegacyColorCategory("bestAccents", colorRecs.bestAccents)
        validateLegacyColorCategory("bestBaseColors", colorRecs.bestBaseColors)
    }
    
    private func validateLegacyColorCategory(_ categoryName: String, _ category: ColorRecommendation) {
        print("   📋 Legacy \(categoryName):")
        print("     • Description: \(category.description.prefix(50))...")
        print("     • Colors: \(category.colors.count)")
        print("     • Priority: \(category.priority)")
        print("     • Usage Instructions: \(category.usageInstructions.prefix(50))...")
        
        // Should have exactly 3 colors in legacy format
        XCTAssertEqual(category.colors.count, 3, "Legacy \(categoryName) should have exactly 3 colors")
        
        // Validate hex color format
        for (index, hexColor) in category.colors.enumerated() {
            XCTAssertTrue(hexColor.hasPrefix("#"), "Legacy \(categoryName)[\(index)] should start with #")
            XCTAssertEqual(hexColor.count, 7, "Legacy \(categoryName)[\(index)] should be 7 characters (#RRGGBB)")
            print("       [\(index)] \(hexColor)")
        }
    }
    
    private func printCompleteResponseForReview(_ response: PersonalizedSeasonData) {
        print("\n" + String(repeating: "=", count: 80))
        print("📄 COMPLETE API RESPONSE DETAILS FOR REVIEW")
        print(String(repeating: "=", count: 80))
        
        print("\n📝 PERSONALIZATION CONTENT:")
        print("   • Tagline: \(response.personalizedTagline)")
        print("   • Characteristics: \(response.userCharacteristics)")
        print("   • Overview: \(response.personalizedOverview)")
        
        print("\n🎨 EMPHASIZED & AVOID COLORS:")
        print("   • Emphasized: \(response.emphasizedColors)")
        print("   • To Avoid: \(response.colorsToAvoid)")
        
        if let enhancedData = response.enhancedColorData {
            print("\n🌟 ENHANCED COLOR DATA:")
            print("   • Best Neutrals:")
            for color in enhancedData.bestNeutrals.colors {
                print("     - \(color.name) (\(color.hexValue)): \(color.usageContext)")
            }
            print("   • Best Accents:")
            for color in enhancedData.bestAccents.colors {
                print("     - \(color.name) (\(color.hexValue)): \(color.usageContext)")
            }
            print("   • Best Base Colors:")
            for color in enhancedData.bestBaseColors.colors {
                print("     - \(color.name) (\(color.hexValue)): \(color.usageContext)")
            }
        }
        
        if let seasonDNAData = response.seasonDNAData {
            print("\n🧬 SEASON DNA DATA:")
            print("   • Primary: \(seasonDNAData.primary.season) (\(Int(seasonDNAData.primary.weight * 100))%)")
            if let secondary = seasonDNAData.secondary {
                print("   • Secondary: \(secondary.season) (\(Int(secondary.weight * 100))%)")
            }
            if let tertiary = seasonDNAData.tertiary {
                print("   • Tertiary: \(tertiary.season) (\(Int(tertiary.weight * 100))%)")
            }
            print("   • Explanation: \(seasonDNAData.explanation)")
            print("   • Confidence: \(seasonDNAData.classificationConfidence)")
        }
        
        print(String(repeating: "=", count: 80))
    }
    
    // MARK: - Helper Methods
    
    private func createTestSeasonData() -> Season {
        // Create a minimal Season struct for testing
        return Season(
            name: "Spring",
            tagline: "Fresh and vibrant",
            introduction: "Test introduction",
            characteristics: Season.Characteristics(
                note: "Test note",
                overview: "Test overview",
                features: Season.Characteristics.Features(
                    eyes: Season.Characteristics.Features.EyeFeatureDescription(
                        description: "Test eyes",
                        eyeColors: ["Green", "Blue"],
                        image: nil
                    ),
                    skin: Season.Characteristics.Features.SkinFeatureDescription(
                        description: "Test skin",
                        skinTones: nil,
                        image: nil
                    ),
                    hair: Season.Characteristics.Features.HairFeatureDescription(
                        description: "Test hair",
                        hairColors: nil,
                        image: nil
                    ),
                    contrast: Season.Characteristics.Features.Contrast(
                        value: "Medium",
                        description: "Test contrast"
                    )
                )
            ),
            palette: Season.Palette(
                description: "Test palette",
                hue: Season.Palette.ColorAspect(value: "Warm", explanation: "Test hue"),
                value: Season.Palette.ColorAspect(value: "Light", explanation: "Test value"),
                chroma: Season.Palette.ColorAspect(value: "Clear", explanation: "Test chroma"),
                sisterPalettes: Season.Palette.SisterPalettes(
                    description: "Test sisters",
                    sisters: [],
                    image: nil
                ),
                paletteImgUrl: nil
            ),
            styling: Season.Styling(
                neutrals: Season.Styling.StyleDescription(description: "Test neutrals", image: nil),
                colorsToAvoid: Season.Styling.ColorsToAvoid(description: "Test avoid", colors: [], image: nil),
                colorCombinations: nil,
                patternsAndPrints: nil,
                metalsAndAccessories: nil
            )
        )
    }
    
    private func createSampleTrueSpringAnalysisResult() -> AnalysisResult {
        // True Spring characteristics: warm, bright, clear
        // Based on typical True Spring coloring: golden blonde hair, clear eyes, warm peachy skin
        
        let skinLab = (L: 72.0 as CGFloat, a: 8.5 as CGFloat, b: 16.2 as CGFloat)  // Warm, light peachy skin
        let hairLab = (L: 65.0 as CGFloat, a: 5.0 as CGFloat, b: 22.0 as CGFloat)   // Golden blonde hair
        let eyeLab = (L: 55.0 as CGFloat, a: 2.0 as CGFloat, b: 15.0 as CGFloat)    // Clear hazel/green eyes
        
        return AnalysisResult(
            season: .spring,
            detailedSeasonName: "True Spring",
            confidence: 0.87,
            deltaEToNextClosest: 18.5,
            nextClosestSeason: .summer,
            skinColor: UIColor(red: 0.92, green: 0.84, blue: 0.76, alpha: 1.0), // Warm peachy
            skinColorLab: skinLab,
            hairColor: UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0), // Golden blonde
            hairColorLab: hairLab,
            leftEyeColor: UIColor(red: 0.65, green: 0.70, blue: 0.45, alpha: 1.0), // Clear hazel
            leftEyeColorLab: eyeLab,
            rightEyeColor: UIColor(red: 0.65, green: 0.70, blue: 0.45, alpha: 1.0), // Clear hazel
            rightEyeColorLab: eyeLab,
            averageEyeColor: UIColor(red: 0.65, green: 0.70, blue: 0.45, alpha: 1.0), // Clear hazel
            averageEyeColorLab: eyeLab,
            leftEyeConfidence: 0.82,
            rightEyeConfidence: 0.84,
            contrastValue: 0.68, // Medium-high contrast typical of True Spring
            contrastLevel: "Medium-High",
            contrastDescription: "Clear contrast between warm hair and bright eyes typical of True Spring",
            thumbnail: nil
        )
    }
    
    // MARK: - Schema Validation Test
    
    func testResponsesAPISchemaStructure() {
        print("\n🧪 Testing Responses API Schema Structure")
        
        let textFormat = ResponsesAPISchemaFactory.createPersonalizationTextFormat()
        let schema = textFormat.format
        
        print("📋 Schema Validation:")
        XCTAssertEqual(schema.type, "json_schema", "Should be json_schema type")
        XCTAssertEqual(schema.name, "Season13Personalization", "Should have correct schema name")
        XCTAssertTrue(schema.strict, "Should use strict validation")
        
        // Validate required fields include our new ones
        let requiredFields = schema.schema.required
        let expectedFields = [
            "personalizedTagline",
            "userCharacteristics",
            "personalizedOverview",
            "colorRecommendations",
            "emphasizedColors",
            "colorsToAvoid",
            "confidence",
            "seasonDNA",           // NEW
            "enhancedColorData"    // NEW
        ]
        
        print("   • Required fields validation:")
        for field in expectedFields {
            XCTAssertTrue(requiredFields.contains(field), "Should require field: \(field)")
            print("     ✅ \(field)")
        }
        
        print("✅ Schema structure validation passed")
    }
}
