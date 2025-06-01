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
    private let model = "gpt-4o-mini" // Using cost-effective model for color analysis
    private let maxTokens = 2000
    private let temperature = 0.7 // Balanced creativity and consistency
    
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
        
        // Make API request
        makeOpenAIRequest(apiKey: apiKey, prompt: prompt) { [weak self] result in
            switch result {
            case .success(let response):
                self?.parsePersonalizationResponse(response, analysisResult: analysisResult, detailedSeasonName: detailedSeasonName) { parseResult in
                    DispatchQueue.main.async {
                        completion(parseResult)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
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
    
    private func createUserColorsSection(_ analysisResult: AnalysisResult) -> String {
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
    
    private func createSeasonInfoSection(_ seasonData: Season) -> String {
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
                },
                "lipColors": {
                    "description": "Lip colors that enhance their natural lip tone",
                    "colors": ["#hex1", "#hex2"],
                    "priority": "medium",
                    "usageInstructions": "Makeup application tips"
                },
                "eyeColors": {
                    "description": "Eye makeup that brings out their eye color",
                    "colors": ["#hex1", "#hex2"],
                    "priority": "medium",
                    "usageInstructions": "Eye makeup guidance"
                }
            },
            "stylingAdvice": {
                "clothingAdvice": {
                    "recommendation": "Clothing style suggestions based on their contrast level and coloring",
                    "tips": ["Specific tip 1", "Specific tip 2"],
                    "avoid": ["What to avoid"],
                    "examples": ["Example outfit ideas"]
                },
                "accessoryAdvice": {
                    "recommendation": "Accessory guidance for their coloring",
                    "tips": ["Accessory tips"],
                    "avoid": ["Accessories to avoid"],
                    "examples": ["Accessory examples"]
                },
                "patternAdvice": {
                    "recommendation": "Pattern recommendations based on contrast level",
                    "tips": ["Pattern tips"],
                    "avoid": ["Patterns to avoid"],
                    "examples": ["Pattern examples"]
                },
                "metalAdvice": {
                    "recommendation": "Metal recommendations (gold/silver/rose gold)",
                    "tips": ["Metal tips"],
                    "avoid": ["Metals to avoid"],
                    "examples": ["Metal examples"]
                },
                "specialConsiderations": "Any special considerations based on their unique color combination"
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
    
    private func makeOpenAIRequest(
        apiKey: String, 
        prompt: String, 
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
        request.timeoutInterval = 30.0
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": maxTokens,
            "temperature": temperature,
            "response_format": ["type": "json_object"]
        ]
        
        // Log the JSON being sent to OpenAI API
        #if DEBUG
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🔵 OpenAI API Request JSON:")
                print(String(repeating: "=", count: 50))
                print(jsonString)
                print(String(repeating: "=", count: 50))
            }
        } catch {
            print("🔴 Failed to serialize request JSON for logging: \(error)")
        }
        #endif
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(PersonalizationError.requestCreationFailed))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            #if DEBUG
            print("🔵 PersonalizationService: URLSession dataTask completed")
            #endif
            
            if let error = error {
                #if DEBUG
                print("🔴 PersonalizationService: Network error: \(error)")
                #endif
                completion(.failure(error))
                return
            }
            
            #if DEBUG
            print("🔵 PersonalizationService: Got response from server")
            #endif
            
            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                print("🔴 PersonalizationService: Invalid HTTP response")
                #endif
                completion(.failure(PersonalizationError.invalidResponse))
                return
            }
            
            #if DEBUG
            print("🔵 PersonalizationService: HTTP Status Code: \(httpResponse.statusCode)")
            #endif
            
            guard httpResponse.statusCode == 200 else {
                #if DEBUG
                print("🔴 PersonalizationService: API error with status code: \(httpResponse.statusCode)")
                if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                    print("🔴 PersonalizationService: Error response body: \(errorBody)")
                }
                #endif
                completion(.failure(PersonalizationError.apiError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                #if DEBUG
                print("🔴 PersonalizationService: No data received")
                #endif
                completion(.failure(PersonalizationError.noData))
                return
            }
            
            #if DEBUG
            print("🔵 PersonalizationService: Received data, size: \(data.count) bytes")
            #endif
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                #if DEBUG
                print("🔵 PersonalizationService: Successfully parsed JSON response")
                if let jsonData = try? JSONSerialization.data(withJSONObject: json ?? [:], options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("🔵 PersonalizationService: OpenAI Response:")
                    print(String(repeating: "=", count: 50))
                    print(jsonString)
                    print(String(repeating: "=", count: 50))
                }
                #endif
                
                let choices = json?["choices"] as? [[String: Any]]
                let message = choices?.first?["message"] as? [String: Any]
                let content = message?["content"] as? String
                
                guard let responseContent = content else {
                    #if DEBUG
                    print("🔴 PersonalizationService: Could not extract content from response")
                    print("🔴 PersonalizationService: choices: \(choices ?? [])")
                    #endif
                    completion(.failure(PersonalizationError.invalidResponseFormat))
                    return
                }
                
                #if DEBUG
                print("🟢 PersonalizationService: Successfully extracted content from response")
                print("🔵 PersonalizationService: Content length: \(responseContent.count) characters")
                #endif
                
                completion(.success(responseContent))
                
            } catch {
                #if DEBUG
                print("🔴 PersonalizationService: JSON parsing failed: \(error)")
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("🔴 PersonalizationService: Raw response: \(rawResponse)")
                }
                #endif
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
        #if DEBUG
        print("🔵 PersonalizationService: Starting to parse personalization response")
        print("🔵 PersonalizationService: Response length: \(response.count) characters")
        #endif
        
        guard let data = response.data(using: .utf8) else {
            #if DEBUG
            print("🔴 PersonalizationService: Failed to convert response string to Data")
            #endif
            completion(.failure(PersonalizationError.invalidResponseFormat))
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = json else {
                #if DEBUG
                print("🔴 PersonalizationService: Failed to parse JSON from response data")
                #endif
                completion(.failure(PersonalizationError.invalidResponseFormat))
                return
            }
            
            #if DEBUG
            print("🔵 PersonalizationService: Successfully parsed response JSON")
            print("🔵 PersonalizationService: JSON keys: \(Array(json.keys))")
            #endif
            
            // Parse the response into PersonalizedSeasonData
            let personalizedData = try parseJSONToPersonalizedData(json, analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            
            #if DEBUG
            print("🟢 PersonalizationService: Successfully created PersonalizedSeasonData")
            #endif
            
            completion(.success(personalizedData))
            
        } catch {
            #if DEBUG
            print("🔴 PersonalizationService: Error parsing response: \(error)")
            print("🔴 PersonalizationService: Raw response: \(response)")
            #endif
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
    
    private func parseColorRecommendations(_ json: [String: Any]) throws -> PersonalizedColorRecommendations {
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
    
    private func parseStylingAdvice(_ json: [String: Any]) throws -> PersonalizedStylingAdvice {
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
    
    private func parseStylingRecommendation(_ json: [String: Any]) throws -> StylingRecommendation {
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
    
    private func isNetworkAvailable() -> Bool {
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

