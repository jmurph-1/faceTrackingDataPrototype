//
//  PersonalizationService.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import UIKit

// MARK: - PersonalizationServiceDelegate

protocol PersonalizationServiceDelegate: AnyObject {
    func personalizationService(_ service: PersonalizationService, didGeneratePersonalization: PersonalizedSeasonData)
    func personalizationService(_ service: PersonalizationService, didFailWithError error: Error)
}

// MARK: - PersonalizationService

class PersonalizationService {

    // MARK: - Properties

    weak var delegate: PersonalizationServiceDelegate?
    private let openAIBaseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o" // Updated model for better color analysis performance
    private let maxTokens = 5000 // Increased for system instructions + response
    private let temperature = 0.7 // Balanced creativity and consistency

    // MARK: - Timeout and Retry Configuration
    internal let requestTimeout: TimeInterval = 45.0 // Increased from 30 to 45 seconds
    private let maxRetryAttempts = 2
    private let retryDelay: TimeInterval = 2.0

    // MARK: - Custom GPT System Instructions

    private func createSystemInstructions() -> String {
        return """
        You are an expert color analyst specializing in Season DNA analysis using the 12-season color system. Your role is to analyze facial coloring data and create comprehensive Season DNA profiles that go beyond traditional seasonal color analysis.

        ## Core Task
        Analyze facial coloring data and create Season DNA profiles identifying primary/secondary/tertiary season influences with weight percentages and enhanced color recommendations.

        ## Critical Requirements:
        - **Exactly 3 colors per category**: bestNeutrals, bestAccents, bestBaseColors must each contain exactly 3 colors
        - **Valid hex format**: All colors must use 6-character hex (#RRGGBB)
        - **Season weights**: Must total exactly 1.0, primary 60-85%, secondary 15-35%, tertiary 5-15%
        - **Season accuracy**: Use authentic 12-season system knowledge (True Spring, Light Spring, Bright Spring, True Summer, Light Summer, Soft Summer, True Autumn, Soft Autumn, Dark Autumn, True Winter, Bright Winter, Dark Winter)
        - **Evidence-based recommendations**: Ground color suggestions in established color theory and seasonal analysis principles

        ## Enhanced Analysis Focus:
        - Apply knowledge of seasonal color characteristics from the 12-season system
        - Consider undertones, contrast levels, and color temperature relationships
        - Explain genetic/hereditary color aspects with specific reasoning
        - Provide individual DNA blend analysis vs generic seasonal advice
        - Include detailed usage context and harmony explanations
        - Use perceptually accurate color relationships
        - Confidence scores: 0.70-0.95 range based on evidence strength

        ## Color Selection Guidelines:
        - Select colors that harmonize with measured Lab values
        - Consider skin undertone compatibility
        - Balance warm/cool relationships appropriately
        - Ensure sufficient contrast for the individual's natural coloring
        - Reference established seasonal color palettes when appropriate

        **Output**: Valid JSON only, no additional text. Follow the exact structure provided in the user prompt.
        """
    }

    // MARK: - Public Methods

    /// Generate personalized recommendations for a user based on their analysis results
    /// - Parameters:
    ///   - analysisResult: The user's color analysis results
    ///   - seasonData: The default season data for reference
    ///   - detailedSeasonName: The specific 12-season name (e.g. "True Summer", "Soft Autumn")
    ///   - completion: Completion handler with PersonalizedSeasonData or error
    func generatePersonalization(
        for analysisResult: AnalysisResult,
        seasonData: Season,
        detailedSeasonName: String,
        completion: @escaping (Result<PersonalizedSeasonData, Error>) -> Void
    ) {
        #if DEBUG
        print("🔵 PersonalizationService: Starting personalization generation")
        print("🔵 PersonalizationService: Checking API key configuration...")
        print("🔵 PersonalizationService: isPersonalizationActive = \(AppConfiguration.shared.isPersonalizationActive)")
        print("🔵 PersonalizationService: API key exists = \(AppConfiguration.shared.getOpenAIKey() != nil)")
        print("🔵 PersonalizationService: detailedSeasonName = \(detailedSeasonName)")
        #endif

        // Generate prompt for OpenAI (always generate for debugging purposes)
        let prompt = createPersonalizationPrompt(analysisResult: analysisResult, seasonData: seasonData)

        #if DEBUG
        // Always log the prompt and request JSON that would be sent, even without API key
        print("🟡 PersonalizationService: Generated OpenAI Prompt:")
        print(String(repeating: "=", count: 60))
        print(prompt)
        print(String(repeating: "=", count: 60))

        // Create and log the full request JSON that would be sent
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": createSystemInstructions()
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": maxTokens,
            "temperature": temperature,
            "response_format": ["type": "json_object"]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🟡 PersonalizationService: Full API Request JSON that would be sent:")
                print(String(repeating: "=", count: 60))
                print(jsonString)
                print(String(repeating: "=", count: 60))
            }
        } catch {
            print("🔴 Failed to serialize request JSON for logging: \(error)")
        }
        #endif

        guard AppConfiguration.shared.isPersonalizationActive,
              let apiKey = AppConfiguration.shared.getOpenAIKey() else {
            #if DEBUG
            print("🔴 PersonalizationService: API key not configured or personalization not active - returning noAPIKey error")
            print("🔴 PersonalizationService: (But you can see above what would have been sent to OpenAI)")
            #endif
            completion(.failure(PersonalizationError.noAPIKey))
            return
        }

        // Check network connectivity
        guard isNetworkAvailable() else {
            #if DEBUG
            print("🔴 PersonalizationService: Network not available - returning networkUnavailable error")
            #endif
            completion(.failure(PersonalizationError.networkUnavailable))
            return
        }

        #if DEBUG
        print("🟢 PersonalizationService: API key configured and network available - proceeding with API request")
        #endif

        // Use Responses API with file search capabilities
        generateResponsesAPIPersonalization(
            for: analysisResult,
            seasonData: seasonData,
            detailedSeasonName: detailedSeasonName,
            completion: completion
        )
    }

    /// Generate DNA-enhanced personalized recommendations using Responses API
    /// - Parameters:
    ///   - analysisResult: The user's color analysis results
    ///   - seasonData: The default season data for reference
    ///   - detailedSeasonName: The specific 12-season name
    ///   - completion: Completion handler with enhanced PersonalizedSeasonData or error
    func generateDNAPersonalization(
        for analysisResult: AnalysisResult,
        seasonData: Season,
        detailedSeasonName: String,
        completion: @escaping (Result<PersonalizedSeasonData, Error>) -> Void
    ) {
        #if DEBUG
        print("🔵 PersonalizationService: Starting DNA-enhanced personalization generation")
        print("🔵 PersonalizationService: detailedSeasonName = \(detailedSeasonName)")
        #endif

        // Generate DNA-enhanced prompt
        let prompt = createDNAPersonalizationPrompt(analysisResult: analysisResult, seasonData: seasonData, detailedSeasonName: detailedSeasonName)

        #if DEBUG
        print("🟡 PersonalizationService: Generated DNA-Enhanced OpenAI Prompt:")
        print(String(repeating: "=", count: 60))
        print(prompt)
        print(String(repeating: "=", count: 60))
        #endif

        guard AppConfiguration.shared.isPersonalizationActive,
              let apiKey = AppConfiguration.shared.getOpenAIKey() else {
            #if DEBUG
            print("🔴 PersonalizationService: API key not configured - creating enhanced fallback")
            #endif
            let enhancedFallback = createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(enhancedFallback))
            return
        }

        guard isNetworkAvailable() else {
            #if DEBUG
            print("🔴 PersonalizationService: Network not available - creating enhanced fallback")
            #endif
            let enhancedFallback = createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(enhancedFallback))
            return
        }

        #if DEBUG
        print("🟢 PersonalizationService: Making DNA-enhanced API request")
        #endif

        // Use Responses API with file search capabilities
        generateResponsesAPIPersonalization(
            for: analysisResult,
            seasonData: seasonData,
            detailedSeasonName: detailedSeasonName,
            completion: completion
        )
    }

    // MARK: - Private Methods

    private func createPersonalizationPrompt(analysisResult: AnalysisResult, seasonData: Season) -> String {
        let userColorsSection = createUserColorsSection(analysisResult)
        let seasonInfoSection = createSeasonInfoSection(seasonData)
        let taskDescription = createTaskDescription()
        let jsonStructure = createJSONStructure()
        let instructions = createInstructions()

        return """
        \(taskDescription)

        \(userColorsSection)

        \(seasonInfoSection)

        \(jsonStructure)

        \(instructions)
        """
    }

    private func createDNAPersonalizationPrompt(analysisResult: AnalysisResult, seasonData: Season, detailedSeasonName: String) -> String {
        let userColorsSection = createUserColorsSection(analysisResult)
        let seasonInfoSection = createSeasonInfoSection(seasonData)
        let dnaTaskDescription = createDNATaskDescription()
        let dnaJsonStructure = createDNAJSONStructure()
        let dnaInstructions = createDNAInstructions()

        return """
        \(dnaTaskDescription)

        \(userColorsSection)

        \(seasonInfoSection)

        DETAILED SEASON: \(detailedSeasonName)

        \(dnaJsonStructure)

        \(dnaInstructions)
        """
    }

    internal func createEnhancedFallback(analysisResult: AnalysisResult, detailedSeasonName: String) -> PersonalizedSeasonData {
        #if DEBUG
        print("🟡 PersonalizationService: Creating enhanced fallback with DNA and database lookup")
        #endif

        // Create Season DNA from analysis result
        let seasonDNA = createFallbackSeasonDNA(from: analysisResult, detailedSeasonName: detailedSeasonName)

        // Create enhanced color recommendations using database
        let enhancedColorData = createFallbackEnhancedColors(seasonDNA: seasonDNA)

        // Create basic PersonalizedSeasonData structure
        let basicData = createBasicFallbackData(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)

        // Return enhanced version
        return PersonalizedSeasonData(
            id: basicData.id,
            createdDate: basicData.createdDate,
            baseSeason: basicData.baseSeason,
            personalizedTagline: basicData.personalizedTagline,
            userCharacteristics: basicData.userCharacteristics,
            personalizedOverview: basicData.personalizedOverview,
            colorRecommendations: basicData.colorRecommendations,
            emphasizedColors: basicData.emphasizedColors,
            colorsToAvoid: basicData.colorsToAvoid,
            confidence: basicData.confidence,
            analysisResultId: basicData.analysisResultId,
            seasonDNAData: seasonDNA,
            enhancedColorData: enhancedColorData
        )
    }

    private func parseDNAPersonalizationResponse(
        _ response: String,
        analysisResult: AnalysisResult,
        detailedSeasonName: String,
        completion: @escaping (Result<PersonalizedSeasonData, Error>) -> Void
    ) {
        #if DEBUG
        print("🔵 PersonalizationService: Parsing DNA-enhanced response")
        print("🔵 PersonalizationService: Raw API response:")
        print(String(repeating: "=", count: 60))
        print(response)
        print(String(repeating: "=", count: 60))
        #endif

        guard let data = response.data(using: .utf8) else {
            let fallback = createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(fallback))
            return
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = json else {
                #if DEBUG
                print("🔴 PersonalizationService: JSON parsing returned nil - likely truncated response")
                #endif
                let fallback = createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
                completion(.success(fallback))
                return
            }

            // Parse DNA-enhanced response
            let personalizedData = try parseDNAJSONToPersonalizedData(json, analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(personalizedData))

        } catch {
            #if DEBUG
            if let nsError = error as NSError?, nsError.domain == "NSCocoaErrorDomain" && nsError.code == 3840 {
                print("🔴 PersonalizationService: JSON truncated - increasing token limit recommended")
                print("🔴 PersonalizationService: Error: \(nsError.localizedDescription)")
            } else {
                print("🔴 PersonalizationService: DNA parsing failed: \(error)")
            }
            #endif
            let fallback = createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(fallback))
        }
    }

    // MARK: - Basic Helper Methods

    internal func createUserColorsSection(_ analysisResult: AnalysisResult) -> String {
        let skinLabString = analysisResult.skinColorLab.map {
            "L: \($0.L), a: \($0.a), b: \($0.b)"
        } ?? "Not available"
        let hairLabString = analysisResult.hairColorLab.map {
            "L: \($0.L), a: \($0.a), b: \($0.b)"
        } ?? "Not available"
        let eyeLabString = analysisResult.averageEyeColorLab.map {
            "L: \($0.L), a: \($0.a), b: \($0.b)"
        } ?? "Not available"

        return """
        USER'S MEASURED COLORS:
        - Season Classification: \(analysisResult.season.rawValue)
        - Classification Confidence: \(analysisResult.confidencePercentage)
        - Skin Color (Lab): \(skinLabString)
        - Hair Color (Lab): \(hairLabString)
        - Eye Color (Lab): \(eyeLabString)
        - Contrast Level: \(analysisResult.contrastLevel) (\(analysisResult.contrastDescription))
        """
    }

    internal func createSeasonInfoSection(_ seasonData: Season) -> String {
        return """
        BASE SEASON INFORMATION:
        - Season: \(seasonData.name)
        - Tagline: \(seasonData.tagline)
        - Overview: \(seasonData.characteristics.overview)
        - Palette Description: \(seasonData.palette.description)
        """
    }

    private func createTaskDescription() -> String {
        return """
        You are an expert color analyst specializing in personal color theory and the 12-season system.
        I need you to create highly personalized color recommendations for a specific individual based on
        their measured colors and assigned season.

        TASK: Create a personalized "13th season" analysis that combines the base season characteristics
        with this individual's specific color measurements. Focus on how their unique skin, hair, and eye
        colors interact with the season's palette.

        Please respond with a JSON object containing:
        """
    }

    private func createJSONStructure() -> String {
        return """
        {
            "personalizedTagline": "A unique tagline that reflects their specific color combination",
            "userCharacteristics": "Description of their unique color characteristics and how they differ from the average person in this season",
            "personalizedOverview": "Detailed analysis of how the season's colors work specifically with their measured colors",
            "emphasizedColors": ["#hex1", "#hex2", "#hex3", "#hex4", "#hex5"],
            "colorsToAvoid": ["#hex1", "#hex2", "#hex3"],
            "colorRecommendations": {
                "bestNeutrals": {
                    "description": "Why these neutrals work with their specific skin tone",
                    "colors": ["#hex1", "#hex2", "#hex3"],
                    "priority": "high",
                    "usageInstructions": "Specific guidance for using these colors"
                },
                "bestAccents": {
                    "description": "How these accent colors complement their eye/hair colors",
                    "colors": ["#hex1", "#hex2", "#hex3"],
                    "priority": "high",
                    "usageInstructions": "Specific guidance for accent colors"
                },
                "bestBaseColors": {
                    "description": "Base colors that harmonize with their overall coloring",
                    "colors": ["#hex1", "#hex2", "#hex3"],
                    "priority": "medium",
                    "usageInstructions": "How to incorporate these base colors"
                }
            },
            "confidence": 0.85
        }
        """
    }

    private func createInstructions() -> String {
        return """
        Focus on practical, actionable advice that takes into account their specific measured Lab color values.
        Be specific about why certain colors work better for their individual coloring rather than generic season advice.
        """
    }

    private func createBasicFallbackData(analysisResult: AnalysisResult, detailedSeasonName: String) -> PersonalizedSeasonData {
        let basicColorRecommendations = PersonalizedColorRecommendations(
            bestNeutrals: ColorRecommendation(
                description: "Neutral colors that complement your \(detailedSeasonName) coloring",
                colors: ["#8B7355", "#A0956C", "#6B5D47", "#D4C4A8"],
                priority: "high",
                usageInstructions: "Use as foundation colors for your wardrobe"
            ),
            bestAccents: ColorRecommendation(
                description: "Accent colors that enhance your natural beauty",
                colors: ["#B8860B", "#CD853F", "#DEB887", "#F4A460"],
                priority: "high",
                usageInstructions: "Perfect for adding personality to your outfits"
            ),
            bestBaseColors: ColorRecommendation(
                description: "Base colors for major wardrobe pieces",
                colors: ["#2F4F4F", "#556B2F", "#8B4513", "#A0522D"],
                priority: "medium",
                usageInstructions: "Ideal for jackets, pants, and dresses"
            ),
            hairColorSuggestions: nil
        )

        return PersonalizedSeasonData(
            baseSeason: detailedSeasonName,
            personalizedTagline: "Beautifully \(detailedSeasonName)",
            userCharacteristics: "Your coloring shows the classic characteristics of a \(detailedSeasonName) type.",
            personalizedOverview: "Your \(detailedSeasonName) coloring is enhanced by warm, rich colors that complement your natural beauty.",
            colorRecommendations: basicColorRecommendations,
            emphasizedColors: ["#8B7355", "#B8860B", "#2F4F4F"],
            colorsToAvoid: ["#FF69B4", "#00FFFF", "#FF00FF"],
            confidence: analysisResult.confidence
        )
    }

    // MARK: - Network and API Methods

    private func makeOpenAIRequest(
        apiKey: String,
        prompt: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        makeOpenAIRequestWithRetry(apiKey: apiKey, prompt: prompt, attempt: 1, completion: completion)
    }

    private func makeOpenAIRequestWithRetry(
        apiKey: String,
        prompt: String,
        attempt: Int,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: openAIBaseURL) else {
            completion(.failure(PersonalizationError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = requestTimeout

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": createSystemInstructions()
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": maxTokens,
            "temperature": temperature,
            "response_format": ["type": "json_object"]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(PersonalizationError.requestCreationFailed))
            return
        }

        #if DEBUG
        print("🔵 PersonalizationService: Attempt \(attempt)/\(maxRetryAttempts) - Making API request...")
        #endif

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                let nsError = error as NSError

                // Check if it's a timeout error
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                    #if DEBUG
                    print("🔴 PersonalizationService: Request timed out on attempt \(attempt)")
                    #endif

                    // Retry if we haven't exceeded max attempts
                    if attempt < self?.maxRetryAttempts ?? 1 {
                        #if DEBUG
                        print("🟡 PersonalizationService: Retrying in \(self?.retryDelay ?? 2.0) seconds...")
                        #endif

                        DispatchQueue.global().asyncAfter(deadline: .now() + (self?.retryDelay ?? 2.0)) {
                            self?.makeOpenAIRequestWithRetry(
                                apiKey: apiKey,
                                prompt: prompt,
                                attempt: attempt + 1,
                                completion: completion
                            )
                        }
                        return
                    }
                }

                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(PersonalizationError.invalidResponse))
                return
            }

            guard httpResponse.statusCode == 200 else {
                #if DEBUG
                print("🔴 PersonalizationService: HTTP error \(httpResponse.statusCode) on attempt \(attempt)")
                #endif
                completion(.failure(PersonalizationError.apiError(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(PersonalizationError.noData))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let choices = json?["choices"] as? [[String: Any]]
                let message = choices?.first?["message"] as? [String: Any]
                let content = message?["content"] as? String

                guard let responseContent = content else {
                    completion(.failure(PersonalizationError.invalidResponseFormat))
                    return
                }

                #if DEBUG
                print("🟢 PersonalizationService: Request succeeded on attempt \(attempt)")
                #endif

                completion(.success(responseContent))

            } catch {
                completion(.failure(PersonalizationError.jsonParsingFailed))
            }
        }.resume()
    }

    private func parsePersonalizationResponse(
        _ response: String,
        analysisResult: AnalysisResult,
        detailedSeasonName: String,
        completion: @escaping (Result<PersonalizedSeasonData, Error>) -> Void
    ) {
        guard let data = response.data(using: .utf8) else {
            completion(.failure(PersonalizationError.invalidResponseFormat))
            return
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = json else {
                completion(.failure(PersonalizationError.invalidResponseFormat))
                return
            }

            // Parse the response into PersonalizedSeasonData
            let personalizedData = try parseJSONToPersonalizedData(json, analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(personalizedData))

        } catch {
            completion(.failure(PersonalizationError.responseParsingFailed))
        }
    }

    private func parseJSONToPersonalizedData(_ json: [String: Any], analysisResult: AnalysisResult, detailedSeasonName: String) throws -> PersonalizedSeasonData {
        guard let personalizedTagline = json["personalizedTagline"] as? String,
              let userCharacteristics = json["userCharacteristics"] as? String,
              let personalizedOverview = json["personalizedOverview"] as? String,
              let emphasizedColors = json["emphasizedColors"] as? [String],
              let colorsToAvoid = json["colorsToAvoid"] as? [String],
              let colorRecommendationsJSON = json["colorRecommendations"] as? [String: Any],
              let confidence = json["confidence"] as? Double else {
            throw PersonalizationError.responseParsingFailed
        }

        let colorRecommendations = try parseColorRecommendations(colorRecommendationsJSON)

        return PersonalizedSeasonData(
            baseSeason: detailedSeasonName,
            personalizedTagline: personalizedTagline,
            userCharacteristics: userCharacteristics,
            personalizedOverview: personalizedOverview,
            colorRecommendations: colorRecommendations,
            emphasizedColors: emphasizedColors,
            colorsToAvoid: colorsToAvoid,
            confidence: Float(confidence),
            analysisResultId: UUID()
        )
    }

    func parseColorRecommendations(_ json: [String: Any]) throws -> PersonalizedColorRecommendations {
        guard let bestNeutralsJSON = json["bestNeutrals"] as? [String: Any],
              let bestAccentsJSON = json["bestAccents"] as? [String: Any],
              let bestBaseColorsJSON = json["bestBaseColors"] as? [String: Any] else {
            throw PersonalizationError.responseParsingFailed
        }

        return PersonalizedColorRecommendations(
            bestNeutrals: try parseColorRecommendation(bestNeutralsJSON),
            bestAccents: try parseColorRecommendation(bestAccentsJSON),
            bestBaseColors: try parseColorRecommendation(bestBaseColorsJSON),
            hairColorSuggestions: nil // Optional field
        )
    }

    private func parseColorRecommendation(_ json: [String: Any]) throws -> ColorRecommendation {
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

    internal func isNetworkAvailable() -> Bool {
        // Simple network check - in production you might want to use a more robust solution
        var addresses: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&addresses) == 0 {
            defer { freeifaddrs(addresses) }
            return true
        }
        return false
    }
}

// MARK: - PersonalizationError

enum PersonalizationError: Error, LocalizedError {
    case noAPIKey
    case networkUnavailable
    case invalidURL
    case requestCreationFailed
    case invalidResponse
    case apiError(Int)
    case noData
    case invalidResponseFormat
    case jsonParsingFailed
    case responseParsingFailed

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your OpenAI API key in settings."
        case .networkUnavailable:
            return "Network connection unavailable. Using default season information."
        case .invalidURL:
            return "Invalid API URL"
        case .requestCreationFailed:
            return "Failed to create API request"
        case .invalidResponse:
            return "Invalid API response"
        case .apiError(let code):
            return "API error with status code: \(code)"
        case .noData:
            return "No data received from API"
        case .invalidResponseFormat:
            return "Invalid response format from API"
        case .jsonParsingFailed:
            return "Failed to parse JSON response"
        case .responseParsingFailed:
            return "Failed to parse personalization data"
        }
    }
}
