//
//  PersonalizationService+DNAHelpers.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import UIKit

// MARK: - PersonalizationService DNA Helpers

extension PersonalizationService {
    
    // MARK: - DNA Support Methods
    
    func createFallbackSeasonDNA(from analysisResult: AnalysisResult, detailedSeasonName: String) -> SeasonDNA {
        // Parse season name for DNA creation
        let components = detailedSeasonName.components(separatedBy: " ")
        
        if components.count > 1 {
            let modifier = components.first?.lowercased()
            let baseSeason = components.dropFirst().joined(separator: " ")
            
            var secondarySeason: SeasonWeight?
            var primaryWeight: Float = 0.85
            
            switch modifier {
            case "soft":
                secondarySeason = SeasonWeight(season: detectSoftSecondary(baseSeason), weight: 0.15)
            case "clear", "bright":
                secondarySeason = SeasonWeight(season: detectClearSecondary(baseSeason), weight: 0.15)
            case "light":
                secondarySeason = SeasonWeight(season: detectLightSecondary(baseSeason), weight: 0.15)
            case "dark", "deep":
                secondarySeason = SeasonWeight(season: detectDarkSecondary(baseSeason), weight: 0.15)
            case "warm":
                secondarySeason = SeasonWeight(season: detectWarmSecondary(baseSeason), weight: 0.15)
            case "cool":
                secondarySeason = SeasonWeight(season: detectCoolSecondary(baseSeason), weight: 0.15)
            default:
                primaryWeight = 1.0
            }
            
            return SeasonDNA(
                primary: SeasonWeight(season: detailedSeasonName, weight: primaryWeight),
                secondary: secondarySeason,
                explanation: secondarySeason != nil ?
                    "Your coloring shows strong \(detailedSeasonName) characteristics with subtle influences from \(secondarySeason!.season)." :
                    "Your coloring is a pure \(detailedSeasonName) type with consistent characteristics.",
                classificationConfidence: analysisResult.confidence,
                blendJustification: secondarySeason != nil ?
                    "The \(modifier ?? "") quality in your coloring suggests some overlap with \(secondarySeason!.season) tones." : nil
            )
        } else {
            return SeasonDNA(
                primary: SeasonWeight(season: detailedSeasonName, weight: 1.0),
                explanation: "Your coloring is a classic \(detailedSeasonName) type with consistent characteristics.",
                classificationConfidence: analysisResult.confidence
            )
        }
    }
    
    func createFallbackEnhancedColors(seasonDNA: SeasonDNA) -> EnhancedColorRecommendations {
        let colorDB = ColorDatabaseManager.shared
        
        let bestNeutrals = DetailedColorRecommendation(
            description: "Foundation neutrals that perfectly complement your DNA blend",
            colors: colorDB.getEnhancedColorItems(for: seasonDNA.primary.season, category: "Neutrals", limit: 4),
            priority: "high",
            usageInstructions: "Use as base colors for daily wardrobe",
            categoryExplanation: "These neutrals form the foundation of your color palette"
        )
        
        let bestAccents = DetailedColorRecommendation(
            description: "Accent colors that enhance your unique characteristics",
            colors: colorDB.getRecommendedColors(for: seasonDNA, category: "Palette", limit: 4).map { $0.toColorItem(usageContext: "Accent color", harmonyReason: "Enhances your season DNA") },
            priority: "high",
            usageInstructions: "Perfect for adding personality and vibrancy",
            categoryExplanation: "These colors bring out your best features"
        )
        
        let bestBaseColors = DetailedColorRecommendation(
            description: "Versatile base colors for your wardrobe",
            colors: colorDB.getEnhancedColorItems(for: seasonDNA.primary.season, category: "Base Colors", limit: 4),
            priority: "medium",
            usageInstructions: "Ideal for major clothing pieces",
            categoryExplanation: "Core colors for building outfits"
        )
        
        let lipColors = DetailedColorRecommendation(
            description: "Lip colors that enhance your natural beauty",
            colors: generateFallbackLipColors(for: seasonDNA),
            priority: "medium",
            usageInstructions: "Choose based on occasion and intensity preference",
            categoryExplanation: "Colors that complement your skin tone"
        )
        
        let eyeColors = DetailedColorRecommendation(
            description: "Eye makeup colors that make your eyes pop",
            colors: generateFallbackEyeColors(for: seasonDNA),
            priority: "medium",
            usageInstructions: "Use to enhance your natural eye color",
            categoryExplanation: "Shadows and liners that bring out your eyes"
        )
        
        return EnhancedColorRecommendations(
            bestNeutrals: bestNeutrals,
            bestAccents: bestAccents,
            bestBaseColors: bestBaseColors,
            lipColors: lipColors,
            eyeColors: eyeColors
        )
    }
    
    // MARK: - Season Detection Helper Methods
    
    func detectSoftSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "summer": return "Soft Autumn"
        case "autumn": return "Soft Summer"
        case "spring": return "Light Spring"
        case "winter": return "Dark Winter"
        default: return "True \(baseSeason)"
        }
    }
    
    func detectClearSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "spring": return "Clear Winter"
        case "winter": return "Clear Spring"
        case "summer": return "Light Summer"
        case "autumn": return "Dark Autumn"
        default: return "True \(baseSeason)"
        }
    }
    
    func detectLightSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "spring": return "Light Summer"
        case "summer": return "Light Spring"
        case "autumn": return "Warm Autumn"
        case "winter": return "Cool Winter"
        default: return "True \(baseSeason)"
        }
    }
    
    func detectDarkSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "autumn": return "Dark Winter"
        case "winter": return "Dark Autumn"
        case "summer": return "Deep Summer"
        case "spring": return "Warm Spring"
        default: return "True \(baseSeason)"
        }
    }
    
    func detectWarmSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "spring": return "Warm Autumn"
        case "autumn": return "Warm Spring"
        case "summer": return "True Summer"
        case "winter": return "True Winter"
        default: return "True \(baseSeason)"
        }
    }
    
    func detectCoolSecondary(_ baseSeason: String) -> String {
        switch baseSeason.lowercased() {
        case "summer": return "Cool Winter"
        case "winter": return "Cool Summer"
        case "spring": return "True Spring"
        case "autumn": return "True Autumn"
        default: return "True \(baseSeason)"
        }
    }
    
    // MARK: - Fallback Color Generation
    
    func generateFallbackLipColors(for seasonDNA: SeasonDNA) -> [ColorItem] {
        let seasonName = seasonDNA.primary.season.lowercased()
        var lipColors: [ColorItem] = []
        
        if seasonName.contains("spring") {
            lipColors.append(ColorItem(name: "Coral Pink", hexValue: "#FF7F7F", usageContext: "Perfect everyday lip color", harmonyReason: "Complements Spring warmth"))
            lipColors.append(ColorItem(name: "Peach", hexValue: "#FFCBA4", usageContext: "Natural, fresh look", harmonyReason: "Enhances your warm undertones"))
        } else if seasonName.contains("summer") {
            lipColors.append(ColorItem(name: "Rose Pink", hexValue: "#F8BBD9", usageContext: "Elegant everyday color", harmonyReason: "Matches Summer's cool elegance"))
            lipColors.append(ColorItem(name: "Berry", hexValue: "#B85450", usageContext: "Perfect for evening", harmonyReason: "Complements cool undertones"))
        } else if seasonName.contains("autumn") {
            lipColors.append(ColorItem(name: "Warm Red", hexValue: "#CC5500", usageContext: "Bold autumn statement", harmonyReason: "Matches your rich coloring"))
            lipColors.append(ColorItem(name: "Burnt Orange", hexValue: "#CC5500", usageContext: "Unique autumn choice", harmonyReason: "Harmonizes with warm undertones"))
        } else if seasonName.contains("winter") {
            lipColors.append(ColorItem(name: "True Red", hexValue: "#DC143C", usageContext: "Classic winter glamour", harmonyReason: "Perfect for dramatic Winter coloring"))
            lipColors.append(ColorItem(name: "Deep Berry", hexValue: "#8B0000", usageContext: "Sophisticated evening look", harmonyReason: "Complements cool undertones"))
        }
        
        return lipColors
    }
    
    func generateFallbackEyeColors(for seasonDNA: SeasonDNA) -> [ColorItem] {
        let seasonName = seasonDNA.primary.season.lowercased()
        var eyeColors: [ColorItem] = []
        
        if seasonName.contains("spring") {
            eyeColors.append(ColorItem(name: "Golden Brown", hexValue: "#B8860B", usageContext: "Natural everyday shadow", harmonyReason: "Brings out eye color warmth"))
            eyeColors.append(ColorItem(name: "Warm Taupe", hexValue: "#C8B99C", usageContext: "Soft definition", harmonyReason: "Complements Spring warmth"))
        } else if seasonName.contains("summer") {
            eyeColors.append(ColorItem(name: "Soft Gray", hexValue: "#A9A9A9", usageContext: "Elegant definition", harmonyReason: "Perfect for Summer's softness"))
            eyeColors.append(ColorItem(name: "Cool Brown", hexValue: "#8B4513", usageContext: "Natural enhancement", harmonyReason: "Complements cool undertones"))
        } else if seasonName.contains("autumn") {
            eyeColors.append(ColorItem(name: "Warm Brown", hexValue: "#A0522D", usageContext: "Rich everyday color", harmonyReason: "Matches Autumn richness"))
            eyeColors.append(ColorItem(name: "Golden Bronze", hexValue: "#CD7F32", usageContext: "Glamorous evening look", harmonyReason: "Enhances warm coloring"))
        } else if seasonName.contains("winter") {
            eyeColors.append(ColorItem(name: "Charcoal", hexValue: "#36454F", usageContext: "Dramatic definition", harmonyReason: "Perfect for Winter contrast"))
            eyeColors.append(ColorItem(name: "Cool Brown", hexValue: "#654321", usageContext: "Sophisticated look", harmonyReason: "Complements cool undertones"))
        }
        
        return eyeColors
    }

    // MARK: - DNA-Enhanced Prompt Creation Methods
    
    func createDNATaskDescription() -> String {
        return """
        You are an expert color analyst specializing in Season DNA analysis and the 12-season system. 
        I need you to create a comprehensive Season DNA analysis that goes beyond traditional seasonal color 
        analysis to identify primary, secondary, and potentially tertiary season influences in this individual's coloring.

        TASK: Create a detailed Season DNA profile that explains the genetic color blueprint of this person, 
        including season weight percentages, blend justification, and enhanced color recommendations with 
        database-backed context.

        Please respond with a JSON object containing:
        """
    }

    func createDNAJSONStructure() -> String {
        return """
        {
            "personalizedTagline": "A unique DNA-based tagline reflecting their season blend",
            "userCharacteristics": "Detailed analysis of their unique color DNA and genetic influences",
            "personalizedOverview": "Comprehensive Season DNA analysis explaining the blend",
            "seasonDNA": {
                "primary": {
                    "season": "Primary season name",
                    "weight": 0.75
                },
                "secondary": {
                    "season": "Secondary season name",
                    "weight": 0.20
                },
                "tertiary": {
                    "season": "Tertiary season name",
                    "weight": 0.05
                },
                "explanation": "Detailed explanation of the DNA blend",
                "classificationConfidence": 0.85,
                "blendJustification": "Why this specific blend occurs in their coloring"
            },
            "enhancedColorData": {
                "bestNeutrals": {
                    "description": "DNA-optimized neutral colors",
                    "colors": [
                        {
                            "name": "Color name",
                            "hexValue": "#RRGGBB",
                            "usageContext": "How to use this color",
                            "harmonyReason": "Why it works with their DNA"
                        }
                    ],
                    "priority": "high",
                    "usageInstructions": "Specific DNA-based usage guidance",
                    "categoryExplanation": "Why these neutrals work for their DNA blend"
                },
                "bestAccents": { /* similar structure */ },
                "bestBaseColors": { /* similar structure */ },
                "lipColors": { /* similar structure */ },
                "eyeColors": { /* similar structure */ }
            },
            "emphasizedColors": ["#hex1", "#hex2", "#hex3", "#hex4", "#hex5"],
            "colorsToAvoid": ["#hex1", "#hex2", "#hex3"],
            "colorRecommendations": {
                /* standard structure for backward compatibility */
            },
            "stylingAdvice": {
                /* standard structure */
            },
            "confidence": 0.90
        }
        """
    }

    func createDNAInstructions() -> String {
        return """
        Focus on creating a Season DNA analysis that:
        1. Identifies primary season (60-85% influence)
        2. Identifies secondary season (15-35% influence) if blend exists
        3. Optionally identifies tertiary season (5-15% influence) for complex colorings
        4. Provides enhanced color recommendations with specific usage context
        5. Explains the genetic/hereditary aspects of their coloring
        6. Uses database-style color information with detailed context

        Weight percentages should total to 1.0 (100%). Be specific about why certain colors work 
        better for their individual DNA blend rather than generic season advice.
        """
    }
    
    // MARK: - DNA Response Parsing Methods
    
    func parseDNAJSONToPersonalizedData(_ json: [String: Any], analysisResult: AnalysisResult, detailedSeasonName: String) throws -> PersonalizedSeasonData {
        #if DEBUG
        print("🔵 PersonalizationService: Parsing DNA JSON response")
        print("🔵 PersonalizationService: JSON keys: \(json.keys.sorted())")
        #endif
        
        // Parse basic data first
        guard let personalizedTagline = json["personalizedTagline"] as? String,
              let userCharacteristics = json["userCharacteristics"] as? String,
              let personalizedOverview = json["personalizedOverview"] as? String,
              let emphasizedColors = json["emphasizedColors"] as? [String],
              let colorsToAvoid = json["colorsToAvoid"] as? [String],
              let confidence = json["confidence"] as? Double else {
            #if DEBUG
            print("🔴 PersonalizationService: Failed to parse basic fields from JSON")
            print("🔴 PersonalizationService: personalizedTagline: \(json["personalizedTagline"] != nil)")
            print("🔴 PersonalizationService: userCharacteristics: \(json["userCharacteristics"] != nil)")
            print("🔴 PersonalizationService: personalizedOverview: \(json["personalizedOverview"] != nil)")
            print("🔴 PersonalizationService: emphasizedColors: \(json["emphasizedColors"] != nil)")
            print("🔴 PersonalizationService: colorsToAvoid: \(json["colorsToAvoid"] != nil)")
            print("🔴 PersonalizationService: confidence: \(json["confidence"] != nil)")
            #endif
            throw PersonalizationError.responseParsingFailed
        }
        
        #if DEBUG
        print("🟢 PersonalizationService: Basic fields parsed successfully")
        #endif
        
        // Parse legacy colorRecommendations and stylingAdvice with fallbacks
        var colorRecommendations: PersonalizedColorRecommendations
        var stylingAdvice: PersonalizedStylingAdvice
        
        do {
            if let colorRecommendationsJSON = json["colorRecommendations"] as? [String: Any] {
                colorRecommendations = try parseColorRecommendations(colorRecommendationsJSON)
                #if DEBUG
                print("🟢 PersonalizationService: Legacy color recommendations parsed")
                #endif
            } else {
                throw PersonalizationError.responseParsingFailed
            }
        } catch {
            #if DEBUG
            print("🟡 PersonalizationService: Using fallback for legacy color recommendations")
            #endif
            colorRecommendations = createFallbackColorRecommendations(detailedSeasonName)
        }
        
        do {
            if let stylingAdviceJSON = json["stylingAdvice"] as? [String: Any] {
                stylingAdvice = try parseStylingAdvice(stylingAdviceJSON)
                #if DEBUG
                print("🟢 PersonalizationService: Legacy styling advice parsed")
                #endif
            } else {
                throw PersonalizationError.responseParsingFailed
            }
        } catch {
            #if DEBUG
            print("🟡 PersonalizationService: Using fallback for legacy styling advice")
            #endif
            stylingAdvice = createFallbackStylingAdvice(detailedSeasonName)
        }
        
        // Parse optional DNA data
        var seasonDNAData: SeasonDNA? = nil
        if let seasonDNAJSON = json["seasonDNA"] as? [String: Any] {
            #if DEBUG
            print("🔵 PersonalizationService: Found seasonDNA data, parsing...")
            #endif
            do {
                seasonDNAData = try parseSeasonDNA(seasonDNAJSON)
                #if DEBUG
                print("🟢 PersonalizationService: SeasonDNA parsed successfully")
                #endif
            } catch {
                #if DEBUG
                print("🔴 PersonalizationService: Failed to parse seasonDNA: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("🟡 PersonalizationService: No seasonDNA data found in response")
            #endif
        }
        
        // Parse optional enhanced color data
        var enhancedColorData: EnhancedColorRecommendations? = nil
        if let enhancedColorJSON = json["enhancedColorData"] as? [String: Any] {
            #if DEBUG
            print("🔵 PersonalizationService: Found enhancedColorData, parsing...")
            #endif
            do {
                enhancedColorData = try parseEnhancedColorData(enhancedColorJSON)
                #if DEBUG
                print("🟢 PersonalizationService: Enhanced color data parsed successfully")
                #endif
            } catch {
                #if DEBUG
                print("🔴 PersonalizationService: Failed to parse enhancedColorData: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("🟡 PersonalizationService: No enhancedColorData found in response")
            #endif
        }
        
        #if DEBUG
        print("🟢 PersonalizationService: All parsing completed successfully")
        print("🟢 PersonalizationService: seasonDNAData: \(seasonDNAData != nil ? "✅" : "❌")")
        print("🟢 PersonalizationService: enhancedColorData: \(enhancedColorData != nil ? "✅" : "❌")")
        #endif
        
        return PersonalizedSeasonData(
            baseSeason: detailedSeasonName,
            personalizedTagline: personalizedTagline,
            userCharacteristics: userCharacteristics,
            personalizedOverview: personalizedOverview,
            colorRecommendations: colorRecommendations,
            stylingAdvice: stylingAdvice,
            emphasizedColors: emphasizedColors,
            colorsToAvoid: colorsToAvoid,
            confidence: Float(confidence),
            analysisResultId: UUID(),
            seasonDNAData: seasonDNAData,
            enhancedColorData: enhancedColorData
        )
    }
    
    func parseSeasonDNA(_ json: [String: Any]) throws -> SeasonDNA {
        guard let primaryJSON = json["primary"] as? [String: Any],
              let primarySeason = primaryJSON["season"] as? String,
              let primaryWeight = primaryJSON["weight"] as? Double,
              let explanation = json["explanation"] as? String,
              let confidence = json["classificationConfidence"] as? Double else {
            throw PersonalizationError.responseParsingFailed
        }
        
        let primary = SeasonWeight(season: primarySeason, weight: Float(primaryWeight))
        
        var secondary: SeasonWeight? = nil
        if let secondaryJSON = json["secondary"] as? [String: Any],
           let secondarySeason = secondaryJSON["season"] as? String,
           let secondaryWeight = secondaryJSON["weight"] as? Double {
            secondary = SeasonWeight(season: secondarySeason, weight: Float(secondaryWeight))
        }
        
        var tertiary: SeasonWeight? = nil
        if let tertiaryJSON = json["tertiary"] as? [String: Any],
           let tertiarySeason = tertiaryJSON["season"] as? String,
           let tertiaryWeight = tertiaryJSON["weight"] as? Double {
            tertiary = SeasonWeight(season: tertiarySeason, weight: Float(tertiaryWeight))
        }
        
        let blendJustification = json["blendJustification"] as? String
        
        return SeasonDNA(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            explanation: explanation,
            classificationConfidence: Float(confidence),
            blendJustification: blendJustification
        )
    }
    
    func parseEnhancedColorData(_ json: [String: Any]) throws -> EnhancedColorRecommendations {
        guard let bestNeutralsJSON = json["bestNeutrals"] as? [String: Any],
              let bestAccentsJSON = json["bestAccents"] as? [String: Any],
              let bestBaseColorsJSON = json["bestBaseColors"] as? [String: Any],
              let lipColorsJSON = json["lipColors"] as? [String: Any],
              let eyeColorsJSON = json["eyeColors"] as? [String: Any] else {
            #if DEBUG
            print("🔴 PersonalizationService: Missing required enhanced color sections")
            print("🔴 PersonalizationService: bestNeutrals: \(json["bestNeutrals"] != nil)")
            print("🔴 PersonalizationService: bestAccents: \(json["bestAccents"] != nil)")
            print("🔴 PersonalizationService: bestBaseColors: \(json["bestBaseColors"] != nil)")
            print("🔴 PersonalizationService: lipColors: \(json["lipColors"] != nil)")
            print("🔴 PersonalizationService: eyeColors: \(json["eyeColors"] != nil)")
            #endif
            throw PersonalizationError.responseParsingFailed
        }
        
        #if DEBUG
        print("🔵 PersonalizationService: All enhanced color sections found, parsing individual sections...")
        #endif
        
        do {
            let bestNeutrals = try parseDetailedColorRecommendation(bestNeutralsJSON)
            #if DEBUG
            print("🟢 PersonalizationService: bestNeutrals parsed successfully")
            #endif
            
            let bestAccents = try parseDetailedColorRecommendation(bestAccentsJSON)
            #if DEBUG
            print("🟢 PersonalizationService: bestAccents parsed successfully")
            #endif
            
            let bestBaseColors = try parseDetailedColorRecommendation(bestBaseColorsJSON)
            #if DEBUG
            print("🟢 PersonalizationService: bestBaseColors parsed successfully")
            #endif
            
            let lipColors = try parseDetailedColorRecommendation(lipColorsJSON)
            #if DEBUG
            print("🟢 PersonalizationService: lipColors parsed successfully")
            #endif
            
            let eyeColors = try parseDetailedColorRecommendation(eyeColorsJSON)
            #if DEBUG
            print("🟢 PersonalizationService: eyeColors parsed successfully")
            #endif
            
            return EnhancedColorRecommendations(
                bestNeutrals: bestNeutrals,
                bestAccents: bestAccents,
                bestBaseColors: bestBaseColors,
                lipColors: lipColors,
                eyeColors: eyeColors
            )
        } catch {
            #if DEBUG
            print("🔴 PersonalizationService: Failed to parse individual enhanced color section: \(error)")
            #endif
            throw error
        }
    }
    
    func parseDetailedColorRecommendation(_ json: [String: Any]) throws -> DetailedColorRecommendation {
        #if DEBUG
        print("🔵 PersonalizationService: parseDetailedColorRecommendation - JSON keys: \(json.keys.sorted())")
        #endif
        
        guard let description = json["description"] as? String,
              let colorsJSON = json["colors"] as? [[String: Any]] else {
            #if DEBUG
            print("🔴 PersonalizationService: Missing required fields in DetailedColorRecommendation")
            print("🔴 PersonalizationService: description exists: \(json["description"] != nil)")
            print("🔴 PersonalizationService: colors exists: \(json["colors"] != nil)")
            print("🔴 PersonalizationService: colors type: \(type(of: json["colors"]))")
            if let colors = json["colors"] {
                print("🔴 PersonalizationService: colors value: \(colors)")
            }
            #endif
            throw PersonalizationError.responseParsingFailed
        }
        
        // Handle optional fields with defaults
        let priority = json["priority"] as? String ?? "medium"
        let usageInstructions = json["usageInstructions"] as? String ?? "Use to enhance your natural coloring"
        let categoryExplanation = json["categoryExplanation"] as? String ?? "These colors work well with your season blend"
        
        #if DEBUG
        print("🔵 PersonalizationService: Parsing \(colorsJSON.count) color items...")
        #endif
        
        do {
            let colors = try colorsJSON.enumerated().map { index, colorJSON in
                #if DEBUG
                print("🔵 PersonalizationService: Parsing color item \(index + 1)/\(colorsJSON.count)")
                #endif
                return try parseColorItem(colorJSON)
            }
            
            #if DEBUG
            print("🟢 PersonalizationService: Successfully parsed \(colors.count) color items")
            #endif
            
            return DetailedColorRecommendation(
                description: description,
                colors: colors,
                priority: priority,
                usageInstructions: usageInstructions,
                categoryExplanation: categoryExplanation
            )
        } catch {
            #if DEBUG
            print("🔴 PersonalizationService: Failed to parse color items: \(error)")
            #endif
            throw error
        }
    }
    
    func parseColorItem(_ json: [String: Any]) throws -> ColorItem {
        #if DEBUG
        print("🔵 PersonalizationService: parseColorItem - JSON keys: \(json.keys.sorted())")
        print("🔵 PersonalizationService: parseColorItem - JSON content: \(json)")
        #endif
        
        guard let name = json["name"] as? String,
              let hexValue = json["hexValue"] as? String,
              let usageContext = json["usageContext"] as? String,
              let harmonyReason = json["harmonyReason"] as? String else {
            #if DEBUG
            print("🔴 PersonalizationService: Missing required fields in ColorItem")
            print("🔴 PersonalizationService: name exists: \(json["name"] != nil) - value: \(json["name"] ?? "nil")")
            print("🔴 PersonalizationService: hexValue exists: \(json["hexValue"] != nil) - value: \(json["hexValue"] ?? "nil")")
            print("🔴 PersonalizationService: usageContext exists: \(json["usageContext"] != nil) - value: \(json["usageContext"] ?? "nil")")
            print("🔴 PersonalizationService: harmonyReason exists: \(json["harmonyReason"] != nil) - value: \(json["harmonyReason"] ?? "nil")")
            #endif
            throw PersonalizationError.responseParsingFailed
        }
        
        #if DEBUG
        print("🟢 PersonalizationService: ColorItem parsed successfully - \(name)")
        #endif
        
        return ColorItem(
            name: name,
            hexValue: hexValue,
            usageContext: usageContext,
            harmonyReason: harmonyReason
        )
    }
    
    // MARK: - Fallback Creation Methods
    
    private func createFallbackColorRecommendations(_ seasonName: String) -> PersonalizedColorRecommendations {
        return PersonalizedColorRecommendations(
            bestNeutrals: ColorRecommendation(
                description: "Neutral colors that complement your \(seasonName) coloring",
                colors: ["#D3D3D3", "#B7C9C7", "#E5D8D1"],
                priority: "high",
                usageInstructions: "Use as foundation colors for your wardrobe"
            ),
            bestAccents: ColorRecommendation(
                description: "Accent colors that enhance your natural beauty",
                colors: ["#E6E6FA", "#D6C5E2", "#F2B2C8"],
                priority: "high",
                usageInstructions: "Perfect for adding personality to your outfits"
            ),
            bestBaseColors: ColorRecommendation(
                description: "Base colors for major wardrobe pieces",
                colors: ["#B2E4D7", "#2E8B57", "#87CEEB"],
                priority: "medium",
                usageInstructions: "Ideal for jackets, pants, and dresses"
            ),
            lipColors: ColorRecommendation(
                description: "Lip colors that enhance your features",
                colors: ["#FFB6C1", "#F1A7B4", "#BC8F8F"],
                priority: "medium",
                usageInstructions: "Choose intensity based on occasion"
            ),
            eyeColors: ColorRecommendation(
                description: "Eye makeup colors that make your eyes pop",
                colors: ["#008080", "#A89CA2", "#C4B6A6"],
                priority: "medium",
                usageInstructions: "Use to enhance your natural eye color"
            ),
            hairColorSuggestions: nil
        )
    }
    
    private func createFallbackStylingAdvice(_ seasonName: String) -> PersonalizedStylingAdvice {
        return PersonalizedStylingAdvice(
            clothingAdvice: StylingRecommendation(
                recommendation: "Focus on soft, flowing fabrics that complement your \(seasonName) coloring",
                tips: ["Layer different tones of your season", "Choose quality fabrics in your colors"],
                avoid: ["Harsh lines and overly structured silhouettes"],
                examples: ["Flowing blouses", "Soft cardigans"]
            ),
            accessoryAdvice: StylingRecommendation(
                recommendation: "Choose delicate accessories in your season's palette",
                tips: ["Silver-toned jewelry", "Soft scarves in your accent colors"],
                avoid: ["Heavy, chunky jewelry"],
                examples: ["Delicate silver necklaces", "Soft pastel scarves"]
            ),
            patternAdvice: StylingRecommendation(
                recommendation: "Patterns that work with your gentle aesthetic",
                tips: ["Subtle florals", "Soft geometrics"],
                avoid: ["Bold, harsh patterns"],
                examples: ["Watercolor prints", "Delicate lace patterns"]
            ),
            metalAdvice: StylingRecommendation(
                recommendation: "Metals that enhance your cool coloring",
                tips: ["Silver and platinum tones work best"],
                avoid: ["Warm gold tones"],
                examples: ["Sterling silver", "White gold", "Platinum"]
            ),
            specialConsiderations: "Your \(seasonName) coloring benefits from soft, light colors and avoiding harsh contrasts."
        )
    }
} 
