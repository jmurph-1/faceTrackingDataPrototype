//
//  PersonalizationService+ResponsesAPI.swift
//  ImageSegmenter
//
//  Created by Claude Code on 12/30/24.
//

import Foundation

// MARK: - PersonalizationService Responses API Extension

extension PersonalizationService {

    // MARK: - Constants

    private var responsesAPIBaseURL: String {
        return "https://api.openai.com/v1/responses"
    }

    private var responsesAPIModel: String {
        return "gpt-4o"
    }

    private var responsesAPIMaxOutputTokens: Int {
        return 8000  // Increased from 4000 to accommodate seasonDNA and enhancedColorData
    }

    private var responsesAPITemperature: Double {
        return 0.2 // Lower temperature for more consistent structured outputs
    }

    // MARK: - Public Methods

    /// Generate personalized recommendations using Responses API with file search
    /// - Parameters:
    ///   - analysisResult: The user's color analysis results
    ///   - seasonData: The default season data for reference
    ///   - detailedSeasonName: The specific 12-season name
    ///   - completion: Completion handler with PersonalizedSeasonData or error
    func generateResponsesAPIPersonalization(
        for analysisResult: AnalysisResult,
        seasonData: Season,
        detailedSeasonName: String,
        completion: @escaping (Result<PersonalizedSeasonData, Error>) -> Void
    ) {
        #if DEBUG
        print("🔵 PersonalizationService: Starting Responses API personalization generation")
        print("🔵 PersonalizationService: detailedSeasonName = \(detailedSeasonName)")
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

        // Check if vector store is configured
        guard let vectorStoreId = AppConfiguration.shared.getVectorStoreId(),
              AppConfiguration.shared.hasVectorStore else {
            #if DEBUG
            print("🔴 PersonalizationService: Vector store not configured - fallback to enhanced fallback")
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
        print("🟢 PersonalizationService: Making Responses API request with vector store: \(vectorStoreId)")
        #endif

        // Create request
        let request = createResponsesAPIRequest(
            analysisResult: analysisResult,
            seasonData: seasonData,
            detailedSeasonName: detailedSeasonName,
            vectorStoreId: vectorStoreId
        )

        // Make API call
        makeResponsesAPIRequest(
            request: request,
            apiKey: apiKey
        ) { [weak self] result in
            switch result {
            case .success(let response):
                self?.parseResponsesAPIResponse(
                    response,
                    analysisResult: analysisResult,
                    detailedSeasonName: detailedSeasonName
                ) { parseResult in
                    DispatchQueue.main.async {
                        completion(parseResult)
                    }
                }
            case .failure(let error):
                #if DEBUG
                print("🔴 PersonalizationService: Responses API request failed, creating enhanced fallback")
                print("🔴 Error: \(error)")
                #endif
                // Provide enhanced fallback on API failure
                let enhancedFallback = self?.createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
                DispatchQueue.main.async {
                    if let fallback = enhancedFallback {
                        completion(.success(fallback))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func createResponsesAPIRequest(
        analysisResult: AnalysisResult,
        seasonData: Season,
        detailedSeasonName: String,
        vectorStoreId: String
    ) -> ResponsesAPIRequest {

        // Create system message with file search instructions
        let systemMessage = ResponsesAPIMessage(
            role: "system",
            content: [ResponsesAPIContent(
                type: "input_text",
                text: createResponsesAPISystemInstructions()
            )]
        )

        // Create user message with analysis data
        let userPrompt = createResponsesAPIUserPrompt(
            analysisResult: analysisResult,
            seasonData: seasonData,
            detailedSeasonName: detailedSeasonName
        )

        let userMessage = ResponsesAPIMessage(
            role: "user",
            content: [ResponsesAPIContent(
                type: "input_text",
                text: userPrompt
            )]
        )

        // Create request with file search tool configured with vector store
        let fileSearchTool = ResponsesAPITool(
            type: "file_search",
            vectorStoreIds: [vectorStoreId]
        )

        let textFormat = ResponsesAPISchemaFactory.createPersonalizationTextFormat()
        
        #if DEBUG
        let requiredFields = textFormat.format.schema.required
        print("🔍 PersonalizationService: Schema being sent to API:")
        print("   • Max Output Tokens: \(responsesAPIMaxOutputTokens)")
        print("   • Schema Name: \(textFormat.format.name)")
        print("   • Required Fields: \(requiredFields.sorted())")
        print("   • Has seasonDNA: \(requiredFields.contains("seasonDNA"))")
        print("   • Has enhancedColorData: \(requiredFields.contains("enhancedColorData"))")
        #endif
        
        return ResponsesAPIRequest(
            model: responsesAPIModel,
            input: [systemMessage, userMessage],
            tools: [fileSearchTool],
            toolChoice: "auto",
            temperature: responsesAPITemperature,
            maxOutputTokens: responsesAPIMaxOutputTokens,
            text: textFormat
        )
    }

    private func createResponsesAPISystemInstructions() -> String {
        return """
        You are an expert color analyst specializing in Season DNA analysis using the 12-season color system. Your role is to analyze facial coloring data and create comprehensive Season DNA profiles that go beyond traditional seasonal color analysis.

        ## CRITICAL: Use File Search Tool
        - Use the **file_search** tool to consult uploaded season documentation and colors.json
        - Reference specific seasonal characteristics from the uploaded documents
        - Use colors from the colors.json database when recommending specific hex codes
        - If no relevant information is found in the documents, say so explicitly
        - Cite document sources for descriptive claims about seasons

        ## Core Task
        Analyze facial coloring data and create Season DNA profiles with enhanced color recommendations grounded in the uploaded knowledge base.

        ## Critical Requirements:
        - **Complete Response**: MUST include both seasonDNA and enhancedColorData sections with ALL required fields
        - **Season DNA**: MUST provide ALL fields:
          • primary: Always required (season name and weight)
          • secondary: Required field (provide season and weight, or null if no secondary influence)
          • tertiary: Required field (provide season and weight, or null if no tertiary influence)  
          • explanation: Required detailed explanation of the season DNA blend
          • classificationConfidence: Required confidence score (0.0-1.0)
          • blendJustification: Required justification for why this blend occurs
        - **Enhanced Colors**: Include detailed color recommendations with ColorItem objects containing name, hexValue, usageContext, and harmonyReason
        - **Hair Color Suggestions**: Required field (provide suggestions or null if not applicable)
        - **Exactly 3-4 colors per category**: bestNeutrals, bestAccents, bestBaseColors must each contain 3-4 colors
        - **Valid hex format**: All colors must use 6-character hex (#RRGGBB)
        - **Season accuracy**: Use authentic 12-season system knowledge from uploaded documents
        - **Color database grounding**: Select colors from the uploaded colors.json when possible
        - **Confidence scores**: 0.70-0.95 range based on evidence quality

        ## Analysis Focus:
        - Explain genetic/hereditary color aspects using document evidence
        - Provide specific reasoning for individual DNA blend vs generic advice
        - Include detailed usage context and harmony explanations
        - Ground recommendations in uploaded seasonal documentation

        **Output**: Return only valid JSON that conforms exactly to the provided schema. No additional text or explanations outside the JSON structure.
        """
    }

    private func createResponsesAPIUserPrompt(
        analysisResult: AnalysisResult,
        seasonData: Season,
        detailedSeasonName: String
    ) -> String {
        let userColorsSection = createUserColorsSection(analysisResult)
        let seasonInfoSection = createSeasonInfoSection(seasonData)

        return """
        Create a comprehensive Season DNA analysis for this individual based on their measured colors and the detailed season classification.

        \(userColorsSection)

        \(seasonInfoSection)

        DETAILED SEASON: \(detailedSeasonName)

        **INSTRUCTIONS:**
        1. Use file_search to find relevant information about \(detailedSeasonName) characteristics
        2. Use file_search to find appropriate colors from the color database
        3. Create personalized recommendations that combine base season traits with this individual's unique coloring
        4. Ensure all color recommendations are grounded in the uploaded color database
        5. Provide confidence score based on the quality of evidence found in the documents

        Return a JSON response that matches the required schema exactly.
        """
    }

    private func makeResponsesAPIRequest(
        request: ResponsesAPIRequest,
        apiKey: String,
        completion: @escaping (Result<ResponsesAPIResponse, Error>) -> Void
    ) {
        guard let url = URL(string: responsesAPIBaseURL) else {
            completion(.failure(PersonalizationError.invalidURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = requestTimeout

        do {
            let requestData = try JSONEncoder().encode(request)
            urlRequest.httpBody = requestData

            #if DEBUG
            // Log request for debugging (without API key)
            if let requestString = String(data: requestData, encoding: .utf8) {
                print("🟡 PersonalizationService: Responses API Request:")
                print(String(repeating: "=", count: 60))
                print(requestString)
                print(String(repeating: "=", count: 60))
            }
            #endif

        } catch {
            completion(.failure(PersonalizationError.requestCreationFailed))
            return
        }

        #if DEBUG
        print("🔵 PersonalizationService: Making Responses API request...")
        #endif

        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(PersonalizationError.invalidResponse))
                return
            }

            guard httpResponse.statusCode == 200 else {
                #if DEBUG
                print("🔴 PersonalizationService: HTTP error \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("🔴 Error response: \(errorString)")
                }
                #endif
                completion(.failure(PersonalizationError.apiError(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(PersonalizationError.noData))
                return
            }

            do {
                let response = try JSONDecoder().decode(ResponsesAPIResponse.self, from: data)

                #if DEBUG
                print("🟢 PersonalizationService: Responses API request succeeded")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🟡 PersonalizationService: Raw Response:")
                    print(String(repeating: "=", count: 60))
                    print(responseString)
                    print(String(repeating: "=", count: 60))
                }
                #endif

                completion(.success(response))

            } catch {
                #if DEBUG
                print("🔴 PersonalizationService: Failed to decode Responses API response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔴 Raw response: \(responseString)")
                }
                #endif
                completion(.failure(PersonalizationError.jsonParsingFailed))
            }
        }.resume()
    }

    private func parseResponsesAPIResponse(
        _ response: ResponsesAPIResponse,
        analysisResult: AnalysisResult,
        detailedSeasonName: String,
        completion: @escaping (Result<PersonalizedSeasonData, Error>) -> Void
    ) {
        #if DEBUG
        print("🔵 PersonalizationService: Parsing Responses API response")
        #endif

        // Extract text content from output events
        var fullContent = ""
        for event in response.output {
            if event.type == "message", let content = event.content {
                for contentItem in content {
                    if contentItem.type == "output_text", let text = contentItem.text {
                        fullContent += text
                    }
                }
            }
        }

        guard !fullContent.isEmpty else {
            #if DEBUG
            print("🔴 PersonalizationService: No content found in response")
            #endif
            let fallback = createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(fallback))
            return
        }

        #if DEBUG
        print("🔵 PersonalizationService: Extracted content:")
        print(String(repeating: "=", count: 60))
        print(fullContent)
        print(String(repeating: "=", count: 60))
        #endif

        guard let data = fullContent.data(using: .utf8) else {
            let fallback = createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(fallback))
            return
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = json else {
                #if DEBUG
                print("🔴 PersonalizationService: JSON parsing returned nil")
                #endif
                let fallback = createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
                completion(.success(fallback))
                return
            }

            // Parse using existing parsing logic
            let personalizedData = try parseDNAJSONToPersonalizedData(json, analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(personalizedData))

        } catch {
            #if DEBUG
            print("🔴 PersonalizationService: Responses API parsing failed: \(error)")
            #endif
            let fallback = createEnhancedFallback(analysisResult: analysisResult, detailedSeasonName: detailedSeasonName)
            completion(.success(fallback))
        }
    }
}
