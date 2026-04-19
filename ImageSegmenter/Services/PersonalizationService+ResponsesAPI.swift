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

        ## Core Task
        Analyze facial coloring data and create Season DNA profiles with enhanced color recommendations grounded in the season data provided.

        ## Critical Requirements:
        - **Complete Response**: MUST include both seasonDNA and enhancedColorData sections with ALL required fields
        - **Season DNA**: MUST provide ALL fields:
          • primary: Always required (season name and weight)
          • secondary: Required field (provide season and weight, or null if no secondary influence)
          • tertiary: Required field (provide season and weight, or null if no tertiary influence)
          • explanation: Required detailed explanation of the season DNA blend
          • classificationConfidence: Required confidence score (0.0-1.0)
          • blendJustification: Required justification for why this blend occurs
        - **Exactly 3-4 colors per category**: bestNeutrals, bestAccents, bestBaseColors must each contain 3-4 colors
        - **Valid hex format**: All colors must use 6-character hex (#RRGGBB)
        - **Confidence scores**: 0.70-0.95 range based on evidence quality

        ## COLOR SELECTION RULES — READ CAREFULLY:

        ### Use the provided database — never invent hex codes:
        The user prompt contains a CURATED COLOR DATABASE pre-categorized for the detected season.
        - NEUTRALS → only valid source for bestNeutrals
        - BASE COLORS → only valid source for bestBaseColors
        - ACCENT COLORS → only valid source for bestAccents
        - emphasizedColors → draw from any of the three lists above
        Using hex values outside these lists is not permitted for those four fields.

        ### Category meanings — these serve different styling roles:
        - NEUTRALS: Foundation wearables — soft taupes, beiges, warm/cool greys, soft browns. Worn as outfit base.
        - BASE COLORS: All-day main garment colors — more interesting than neutrals but not loud. Mid-intensity blues, greens, muted wines, etc.
        - ACCENT COLORS: The season's most vibrant hues — for accessories, statement pieces, highlights. Noticeably more saturated than base colors.
        bestAccents must look clearly different from bestBaseColors — if they could be swapped without anyone noticing, your selection is wrong.

        ### Spread rule — apply to every category independently:
        Each list in the database is tagged [light], [medium], [dark]. When selecting 3-4 colors from a list:
        - You MUST include at least one [light], one [medium], and one [dark] entry
        - You MUST NOT pick colors that are all the same lightness band (e.g. four [medium] entries)
        - You MUST pick colors from at least 2 different hue families within the list (e.g. not four shades of blue)
        The goal is that when someone looks at the 3-4 swatches side by side, they look visually distinct and cover a useful range.

        ### colorsToAvoid — variety across hue families:
        - Convert each named avoid color to an accurate hex
        - The set must include avoid examples from at least 3 different hue families
        - Must not be all neutrals/greys — show wrong warm tones, wrong cool tones, and wrong muted/dusty tones

        ### Descriptions must be specific:
        - Reference the season name and its palette traits in every description
        - harmonyReason must explain why this color fits its category role (neutral vs base vs accent) for this season

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
        let colorDatabaseSection = createColorDatabaseSection(for: detailedSeasonName)
        let avoidColorNames = seasonData.styling.colorsToAvoid.colors?.joined(separator: ", ") ?? ""
        let paletteHue = seasonData.palette.hue.value
        let paletteChroma = seasonData.palette.chroma.value
        let paletteValue = seasonData.palette.value.value

        return """
        Create a comprehensive Season DNA analysis for this individual.

        \(userColorsSection)

        \(seasonInfoSection)

        DETAILED SEASON: \(detailedSeasonName)

        \(colorDatabaseSection)

        **INSTRUCTIONS — follow in order:**

        1. bestNeutrals: Select 3-4 colors from the NEUTRALS list above.
           - Pick a dark anchor, a mid-tone, and a light — spanning different hue families (e.g. warm brown, greyed beige, soft ivory — not three shades of grey)
           - Use the exact name and hex from the database

        2. bestBaseColors: Select 3-4 colors from the BASE COLORS list above.
           - These are the versatile day-wear colors for main garment pieces
           - Pick across different hue families — not all blues, not all greens
           - Use the exact name and hex from the database

        3. bestAccents: Select 3-4 colors from the ACCENT COLORS list above.
           - These are vibrant statement colors for accessories and highlights
           - Pick across different hue families — not all corals, not all pinks
           - Use the exact name and hex from the database

        4. emphasizedColors: Select 4-6 of the absolute best colors for \(detailedSeasonName), drawn from any of the three lists above, spanning the full palette breadth.

        5. colorsToAvoid: The season data names these colors to avoid: [\(avoidColorNames)]
           - Convert each named color to its accurate hex representation
           - Add extras if needed to reach 4-6 total, showing the full range of what clashes with a \(paletteHue)-hue, \(paletteChroma)-chroma, \(paletteValue)-value palette
           - Span multiple hue families (at least one warm clash, one cool clash, one muted clash)

        6. Write specific harmonyReason and usageContext for each color explaining its role as a neutral/base/accent for \(detailedSeasonName).

        Return a JSON response that matches the required schema exactly.
        """
    }

    private func createColorDatabaseSection(for seasonName: String) -> String {
        let db = ColorDatabaseManager.shared

        let neutrals   = db.getColors(for: seasonName, category: "Neutrals")
        let baseColors = db.getColors(for: seasonName, category: "Base Colors")
        let accents    = db.getColors(for: seasonName, category: "Accent Colors")

        func lightnessLabel(_ hex: String) -> String {
            guard hex.count >= 7 else { return "medium" }
            let start = hex.hasPrefix("#") ? hex.index(hex.startIndex, offsetBy: 1) : hex.startIndex
            guard let r = UInt8(hex[start...hex.index(start, offsetBy: 1)], radix: 16),
                  let g = UInt8(hex[hex.index(start, offsetBy: 2)...hex.index(start, offsetBy: 3)], radix: 16),
                  let b = UInt8(hex[hex.index(start, offsetBy: 4)...hex.index(start, offsetBy: 5)], radix: 16) else {
                return "medium"
            }
            let luminance = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255.0
            if luminance > 0.65 { return "light" }
            if luminance < 0.35 { return "dark" }
            return "medium"
        }

        func format(_ colors: [ColorData]) -> String {
            guard !colors.isEmpty else { return "  (none on record)" }
            let sorted = colors.sorted {
                let l1 = (0.299 * Double(UInt8($0.hexValue.dropFirst().prefix(2), radix: 16) ?? 128)
                        + 0.587 * Double(UInt8($0.hexValue.dropFirst().dropFirst(2).prefix(2), radix: 16) ?? 128)
                        + 0.114 * Double(UInt8($0.hexValue.dropFirst().dropFirst(4).prefix(2), radix: 16) ?? 128)) / 255.0
                let l2 = (0.299 * Double(UInt8($1.hexValue.dropFirst().prefix(2), radix: 16) ?? 128)
                        + 0.587 * Double(UInt8($1.hexValue.dropFirst().dropFirst(2).prefix(2), radix: 16) ?? 128)
                        + 0.114 * Double(UInt8($1.hexValue.dropFirst().dropFirst(4).prefix(2), radix: 16) ?? 128)) / 255.0
                return l1 > l2
            }
            return sorted.map { "  [\(lightnessLabel($0.hexValue))] \($0.name) \($0.hexValue)" }.joined(separator: "\n")
        }

        return """
        CURATED \(seasonName.uppercased()) COLOR DATABASE:
        Colors are sorted light → dark within each category and tagged [light], [medium], or [dark].
        You MUST use the exact hex values from these lists — do not invent or modify hex codes.

        NEUTRALS (\(neutrals.count) colors) — select 3-4 for bestNeutrals:
        \(format(neutrals))

        BASE COLORS (\(baseColors.count) colors) — select 3-4 for bestBaseColors:
        \(format(baseColors))

        ACCENT COLORS (\(accents.count) colors) — select 3-4 for bestAccents:
        \(format(accents))
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
