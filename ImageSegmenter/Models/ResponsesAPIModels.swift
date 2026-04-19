//
//  ResponsesAPIModels.swift
//  ImageSegmenter
//
//  Created by Claude Code on 12/30/24.
//

import Foundation

// MARK: - Responses API Request Models

struct ResponsesAPIRequest: Codable {
    let model: String
    let input: [ResponsesAPIMessage]
    let tools: [ResponsesAPITool]?
    let toolChoice: String?
    let temperature: Double
    let maxOutputTokens: Int
    let text: ResponsesAPITextFormat?

    enum CodingKeys: String, CodingKey {
        case model, input, tools, text
        case toolChoice = "tool_choice"
        case temperature
        case maxOutputTokens = "max_output_tokens"
    }
}

struct ResponsesAPIMessage: Codable {
    let role: String
    let content: [ResponsesAPIContent]
}

struct ResponsesAPIContent: Codable {
    let type: String
    let text: String
}

struct ResponsesAPITool: Codable {
    let type: String
    let vectorStoreIds: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case vectorStoreIds = "vector_store_ids"
    }
}

// Removed old tool resources - now configured directly in tools

struct ResponsesAPITextFormat: Codable {
    let format: ResponsesAPIResponseFormat
}

struct ResponsesAPIResponseFormat: Codable {
    let type: String
    let name: String
    let strict: Bool
    let schema: ResponsesAPISchema
}

// MARK: - JSON Schema Definition

struct ResponsesAPISchema: Codable {
    let type: String
    let additionalProperties: Bool
    let properties: ResponsesAPISchemaProperties
    let required: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }
}

struct ResponsesAPISchemaProperties: Codable {
    let personalizedTagline: ResponsesAPIStringProperty
    let userCharacteristics: ResponsesAPIStringProperty
    let personalizedOverview: ResponsesAPIStringProperty
    let emphasizedColors: ResponsesAPIArrayProperty
    let colorsToAvoid: ResponsesAPIArrayProperty
    let colorRecommendations: ResponsesAPIColorRecommendationsProperty
    let confidence: ResponsesAPINumberProperty
    let seasonDNA: ResponsesAPISeasonDNAProperty
    let enhancedColorData: ResponsesAPIEnhancedColorDataProperty

    enum CodingKeys: String, CodingKey {
        case personalizedTagline, userCharacteristics, personalizedOverview
        case emphasizedColors, colorsToAvoid, colorRecommendations, confidence
        case seasonDNA, enhancedColorData
    }
    
    init(personalizedTagline: ResponsesAPIStringProperty,
         userCharacteristics: ResponsesAPIStringProperty,
         personalizedOverview: ResponsesAPIStringProperty,
         emphasizedColors: ResponsesAPIArrayProperty,
         colorsToAvoid: ResponsesAPIArrayProperty,
         colorRecommendations: ResponsesAPIColorRecommendationsProperty,
         confidence: ResponsesAPINumberProperty,
         seasonDNA: ResponsesAPISeasonDNAProperty,
         enhancedColorData: ResponsesAPIEnhancedColorDataProperty) {
        self.personalizedTagline = personalizedTagline
        self.userCharacteristics = userCharacteristics
        self.personalizedOverview = personalizedOverview
        self.emphasizedColors = emphasizedColors
        self.colorsToAvoid = colorsToAvoid
        self.colorRecommendations = colorRecommendations
        self.confidence = confidence
        self.seasonDNA = seasonDNA
        self.enhancedColorData = enhancedColorData
    }
}

struct ResponsesAPIStringProperty: Codable {
    let type: String

    init() {
        self.type = "string"
    }
}

struct ResponsesAPIArrayProperty: Codable {
    let type: String
    let minItems: Int
    let items: ResponsesAPIHexColorProperty

    init(minItems: Int = 3) {
        self.type = "array"
        self.minItems = minItems
        self.items = ResponsesAPIHexColorProperty()
    }
}

struct ResponsesAPIHexColorProperty: Codable {
    let type: String
    let pattern: String

    init() {
        self.type = "string"
        self.pattern = "^#([A-Fa-f0-9]{6})$"
    }
}

struct ResponsesAPINumberProperty: Codable {
    let type: String
    let minimum: Double
    let maximum: Double

    init(minimum: Double = 0.70, maximum: Double = 0.95) {
        self.type = "number"
        self.minimum = minimum
        self.maximum = maximum
    }
}

struct ResponsesAPIColorRecommendationsProperty: Codable {
    let type: String
    let additionalProperties: Bool
    let properties: ResponsesAPIColorRecommendationsSubProperties
    let required: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }

    init() {
        self.type = "object"
        self.additionalProperties = false
        self.properties = ResponsesAPIColorRecommendationsSubProperties()
        self.required = ["bestNeutrals", "bestAccents", "bestBaseColors"]
    }
}

struct ResponsesAPIColorRecommendationsSubProperties: Codable {
    let bestNeutrals: ResponsesAPIColorRecommendationProperty
    let bestAccents: ResponsesAPIColorRecommendationProperty
    let bestBaseColors: ResponsesAPIColorRecommendationProperty

    enum CodingKeys: String, CodingKey {
        case bestNeutrals, bestAccents, bestBaseColors
    }

    init() {
        self.bestNeutrals = ResponsesAPIColorRecommendationProperty()
        self.bestAccents = ResponsesAPIColorRecommendationProperty()
        self.bestBaseColors = ResponsesAPIColorRecommendationProperty()
    }
}

struct ResponsesAPIColorRecommendationProperty: Codable {
    let type: String
    let additionalProperties: Bool
    let properties: ResponsesAPIColorRecommendationSubProperties
    let required: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }

    init() {
        self.type = "object"
        self.additionalProperties = false
        self.properties = ResponsesAPIColorRecommendationSubProperties()
        self.required = ["description", "colors", "priority", "usageInstructions"]
    }
}

struct ResponsesAPIColorRecommendationSubProperties: Codable {
    let description: ResponsesAPIStringProperty
    let colors: ResponsesAPIColorArrayProperty
    let priority: ResponsesAPIPriorityProperty
    let usageInstructions: ResponsesAPIStringProperty

    init() {
        self.description = ResponsesAPIStringProperty()
        self.colors = ResponsesAPIColorArrayProperty()
        self.priority = ResponsesAPIPriorityProperty()
        self.usageInstructions = ResponsesAPIStringProperty()
    }
}

struct ResponsesAPIColorArrayProperty: Codable {
    let type: String
    let minItems: Int
    let maxItems: Int
    let items: ResponsesAPIHexColorProperty

    init() {
        self.type = "array"
        self.minItems = 3
        self.maxItems = 3
        self.items = ResponsesAPIHexColorProperty()
    }
}

struct ResponsesAPIPriorityProperty: Codable {
    let type: String
    let enumValues: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case enumValues = "enum"
    }

    init() {
        self.type = "string"
        self.enumValues = ["low", "medium", "high"]
    }
}

// MARK: - Response Models

struct ResponsesAPIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let output: [ResponsesAPIOutputEvent]
    let usage: ResponsesAPIUsage?

    enum CodingKeys: String, CodingKey {
        case id, object, model, output, usage
        case created = "created_at"
    }
}

struct ResponsesAPIOutputEvent: Codable {
    let id: String?
    let type: String
    let status: String?
    let content: [ResponsesAPIOutputContent]?
    let queries: [String]?
    let results: String?
    let role: String?
}

struct ResponsesAPIOutputContent: Codable {
    let type: String
    let text: String?
    let annotations: [String]?
    let logprobs: [String]?
}

struct ResponsesAPIUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Season DNA Schema Properties

struct ResponsesAPISeasonDNAProperty: Codable {
    let type: String
    let additionalProperties: Bool
    let properties: ResponsesAPISeasonDNASubProperties
    let required: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }

    init() {
        self.type = "object"
        self.additionalProperties = false
        self.properties = ResponsesAPISeasonDNASubProperties()
        self.required = ["primary", "secondary", "tertiary", "explanation", "classificationConfidence", "blendJustification"]
    }
}

struct ResponsesAPISeasonDNASubProperties: Codable {
    let primary: ResponsesAPISeasonWeightProperty
    let secondary: ResponsesAPINullableSeasonWeightProperty
    let tertiary: ResponsesAPINullableSeasonWeightProperty
    let explanation: ResponsesAPIStringProperty
    let classificationConfidence: ResponsesAPINumberProperty
    let blendJustification: ResponsesAPIStringProperty

    init() {
        self.primary = ResponsesAPISeasonWeightProperty()
        self.secondary = ResponsesAPINullableSeasonWeightProperty()
        self.tertiary = ResponsesAPINullableSeasonWeightProperty()
        self.explanation = ResponsesAPIStringProperty()
        self.classificationConfidence = ResponsesAPINumberProperty(minimum: 0.0, maximum: 1.0)
        self.blendJustification = ResponsesAPIStringProperty()
    }
}

struct ResponsesAPISeasonWeightProperty: Codable {
    let type: String
    let additionalProperties: Bool
    let properties: ResponsesAPISeasonWeightSubProperties
    let required: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }

    init() {
        self.type = "object"
        self.additionalProperties = false
        self.properties = ResponsesAPISeasonWeightSubProperties()
        self.required = ["season", "weight"]
    }
}

struct ResponsesAPISeasonWeightSubProperties: Codable {
    let season: ResponsesAPIStringProperty
    let weight: ResponsesAPINumberProperty

    init() {
        self.season = ResponsesAPIStringProperty()
        self.weight = ResponsesAPINumberProperty(minimum: 0.0, maximum: 1.0)
    }
}

struct ResponsesAPINullableSeasonWeightProperty: Codable {
    let type: [String]
    let additionalProperties: Bool
    let properties: ResponsesAPISeasonWeightSubProperties?
    let required: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }

    init() {
        self.type = ["object", "null"]
        self.additionalProperties = false
        self.properties = ResponsesAPISeasonWeightSubProperties()
        self.required = ["season", "weight"]
    }
}

// MARK: - Enhanced Color Data Schema Properties

struct ResponsesAPIEnhancedColorDataProperty: Codable {
    let type: String
    let additionalProperties: Bool
    let properties: ResponsesAPIEnhancedColorDataSubProperties
    let required: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }

    init() {
        self.type = "object"
        self.additionalProperties = false
        self.properties = ResponsesAPIEnhancedColorDataSubProperties()
        self.required = ["bestNeutrals", "bestAccents", "bestBaseColors", "hairColorSuggestions"]
    }
}

struct ResponsesAPIEnhancedColorDataSubProperties: Codable {
    let bestNeutrals: ResponsesAPIDetailedColorRecommendationProperty
    let bestAccents: ResponsesAPIDetailedColorRecommendationProperty
    let bestBaseColors: ResponsesAPIDetailedColorRecommendationProperty
    let hairColorSuggestions: ResponsesAPINullableDetailedColorRecommendationProperty

    init() {
        self.bestNeutrals = ResponsesAPIDetailedColorRecommendationProperty()
        self.bestAccents = ResponsesAPIDetailedColorRecommendationProperty()
        self.bestBaseColors = ResponsesAPIDetailedColorRecommendationProperty()
        self.hairColorSuggestions = ResponsesAPINullableDetailedColorRecommendationProperty()
    }
}

struct ResponsesAPIDetailedColorRecommendationProperty: Codable {
    let type: String
    let additionalProperties: Bool
    let properties: ResponsesAPIDetailedColorRecommendationSubProperties
    let required: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }

    init() {
        self.type = "object"
        self.additionalProperties = false
        self.properties = ResponsesAPIDetailedColorRecommendationSubProperties()
        self.required = ["description", "colors", "priority", "usageInstructions", "categoryExplanation"]
    }
}

struct ResponsesAPIDetailedColorRecommendationSubProperties: Codable {
    let description: ResponsesAPIStringProperty
    let colors: ResponsesAPIColorItemArrayProperty
    let priority: ResponsesAPIPriorityProperty
    let usageInstructions: ResponsesAPIStringProperty
    let categoryExplanation: ResponsesAPIStringProperty

    init() {
        self.description = ResponsesAPIStringProperty()
        self.colors = ResponsesAPIColorItemArrayProperty()
        self.priority = ResponsesAPIPriorityProperty()
        self.usageInstructions = ResponsesAPIStringProperty()
        self.categoryExplanation = ResponsesAPIStringProperty()
    }
}

struct ResponsesAPIColorItemArrayProperty: Codable {
    let type: String
    let minItems: Int
    let maxItems: Int
    let items: ResponsesAPIColorItemProperty

    init() {
        self.type = "array"
        self.minItems = 3
        self.maxItems = 4
        self.items = ResponsesAPIColorItemProperty()
    }
}

struct ResponsesAPIColorItemProperty: Codable {
    let type: String
    let additionalProperties: Bool
    let properties: ResponsesAPIColorItemSubProperties
    let required: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }

    init() {
        self.type = "object"
        self.additionalProperties = false
        self.properties = ResponsesAPIColorItemSubProperties()
        self.required = ["name", "hexValue", "usageContext", "harmonyReason"]
    }
}

struct ResponsesAPIColorItemSubProperties: Codable {
    let name: ResponsesAPIStringProperty
    let hexValue: ResponsesAPIHexColorProperty
    let usageContext: ResponsesAPIStringProperty
    let harmonyReason: ResponsesAPIStringProperty

    init() {
        self.name = ResponsesAPIStringProperty()
        self.hexValue = ResponsesAPIHexColorProperty()
        self.usageContext = ResponsesAPIStringProperty()
        self.harmonyReason = ResponsesAPIStringProperty()
    }
}

struct ResponsesAPINullableDetailedColorRecommendationProperty: Codable {
    let type: [String]
    let additionalProperties: Bool?
    let properties: ResponsesAPIDetailedColorRecommendationSubProperties?
    let required: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case additionalProperties = "additionalProperties"
        case properties, required
    }

    init() {
        self.type = ["object", "null"]
        self.additionalProperties = false
        self.properties = ResponsesAPIDetailedColorRecommendationSubProperties()
        self.required = ["description", "colors", "priority", "usageInstructions", "categoryExplanation"]
    }
}

// MARK: - Schema Factory

struct ResponsesAPISchemaFactory {

    static func createPersonalizationTextFormat() -> ResponsesAPITextFormat {
        let schema = ResponsesAPISchema(
            type: "object",
            additionalProperties: false,
            properties: ResponsesAPISchemaProperties(
                personalizedTagline: ResponsesAPIStringProperty(),
                userCharacteristics: ResponsesAPIStringProperty(),
                personalizedOverview: ResponsesAPIStringProperty(),
                emphasizedColors: ResponsesAPIArrayProperty(minItems: 3),
                colorsToAvoid: ResponsesAPIArrayProperty(minItems: 3),
                colorRecommendations: ResponsesAPIColorRecommendationsProperty(),
                confidence: ResponsesAPINumberProperty(minimum: 0.70, maximum: 0.95),
                seasonDNA: ResponsesAPISeasonDNAProperty(),
                enhancedColorData: ResponsesAPIEnhancedColorDataProperty()
            ),
            required: [
                "personalizedTagline",
                "userCharacteristics",
                "personalizedOverview",
                "colorRecommendations",
                "emphasizedColors",
                "colorsToAvoid",
                "confidence",
                "seasonDNA",
                "enhancedColorData"
            ]
        )

        let responseFormat = ResponsesAPIResponseFormat(
            type: "json_schema",
            name: "Season13Personalization",
            strict: true,
            schema: schema
        )

        return ResponsesAPITextFormat(format: responseFormat)
    }
}
