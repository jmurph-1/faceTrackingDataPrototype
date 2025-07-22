//
//  PersonalizationService+Parsing.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation

// MARK: - PersonalizationService Parsing Extensions

extension PersonalizationService {

    // MARK: - Standard Parsing Methods

    func parseJSONToPersonalizedData(_ json: [String: Any], analysisResult: AnalysisResult, detailedSeasonName: String) throws -> PersonalizedSeasonData {
        guard let personalizedTagline = json["personalizedTagline"] as? String,
              let userCharacteristics = json["userCharacteristics"] as? String,
              let personalizedOverview = json["personalizedOverview"] as? String,
              let emphasizedColors = json["emphasizedColors"] as? [String],
              let colorsToAvoid = json["colorsToAvoid"] as? [String],
              let colorRecommendationsJSON = json["colorRecommendations"] as? [String: Any],
              let stylingAdviceJSON = json["stylingAdvice"] as? [String: Any],
              let confidence = json["confidence"] as? Double else {
            throw PersonalizationError.responseParsingFailed
        }

        let colorRecommendations = try parseColorRecommendations(colorRecommendationsJSON)
        let stylingAdvice = try parseStylingAdvice(stylingAdviceJSON)

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
            analysisResultId: UUID()
        )
    }

    func parseColorRecommendations(_ json: [String: Any]) throws -> PersonalizedColorRecommendations {
        guard let bestNeutralsJSON = json["bestNeutrals"] as? [String: Any],
              let bestAccentsJSON = json["bestAccents"] as? [String: Any],
              let bestBaseColorsJSON = json["bestBaseColors"] as? [String: Any],
              let lipColorsJSON = json["lipColors"] as? [String: Any],
              let eyeColorsJSON = json["eyeColors"] as? [String: Any] else {
            throw PersonalizationError.responseParsingFailed
        }

        return PersonalizedColorRecommendations(
            bestNeutrals: try parseColorRecommendation(bestNeutralsJSON),
            bestAccents: try parseColorRecommendation(bestAccentsJSON),
            bestBaseColors: try parseColorRecommendation(bestBaseColorsJSON),
            lipColors: try parseColorRecommendation(lipColorsJSON),
            eyeColors: try parseColorRecommendation(eyeColorsJSON),
            hairColorSuggestions: nil // Optional field
        )
    }

    func parseColorRecommendation(_ json: [String: Any]) throws -> ColorRecommendation {
        guard let description = json["description"] as? String,
              let colors = json["colors"] as? [String],
              let priority = json["priority"] as? String,
              let usageInstructions = json["usageInstructions"] as? String else {
            throw PersonalizationError.responseParsingFailed
        }

        return ColorRecommendation(
            description: description,
            colors: colors,
            priority: priority,
            usageInstructions: usageInstructions
        )
    }

    func parseStylingAdvice(_ json: [String: Any]) throws -> PersonalizedStylingAdvice {
        guard let clothingAdviceJSON = json["clothingAdvice"] as? [String: Any],
              let accessoryAdviceJSON = json["accessoryAdvice"] as? [String: Any],
              let patternAdviceJSON = json["patternAdvice"] as? [String: Any],
              let metalAdviceJSON = json["metalAdvice"] as? [String: Any],
              let specialConsiderations = json["specialConsiderations"] as? String else {
            throw PersonalizationError.responseParsingFailed
        }

        return PersonalizedStylingAdvice(
            clothingAdvice: try parseStylingRecommendation(clothingAdviceJSON),
            accessoryAdvice: try parseStylingRecommendation(accessoryAdviceJSON),
            patternAdvice: try parseStylingRecommendation(patternAdviceJSON),
            metalAdvice: try parseStylingRecommendation(metalAdviceJSON),
            specialConsiderations: specialConsiderations
        )
    }

    func parseStylingRecommendation(_ json: [String: Any]) throws -> StylingRecommendation {
        guard let recommendation = json["recommendation"] as? String,
              let tips = json["tips"] as? [String],
              let avoid = json["avoid"] as? [String],
              let examples = json["examples"] as? [String] else {
            throw PersonalizationError.responseParsingFailed
        }

        return StylingRecommendation(
            recommendation: recommendation,
            tips: tips,
            avoid: avoid,
            examples: examples
        )
    }
}
