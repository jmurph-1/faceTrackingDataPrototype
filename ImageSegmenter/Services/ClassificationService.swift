// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import UIKit
import CoreVideo

// MARK: - ClassificationServiceDelegate
protocol ClassificationServiceDelegate: AnyObject {
    func classificationService(_ service: ClassificationService, didCompleteAnalysis result: AnalysisResult)
    func classificationService(_ service: ClassificationService, didFailWithError error: Error)
    func classificationService(_ service: ClassificationService, didCompletePersonalization personalizedData: PersonalizedSeasonData)
    func classificationService(_ service: ClassificationService, didFailPersonalization error: Error, fallbackResult: AnalysisResult)
}

// MARK: - ClassificationService
class ClassificationService {
    // MARK: - Properties
    weak var delegate: ClassificationServiceDelegate?
    private let personalizationService = PersonalizationService()

    // Cache decoded season JSON — reading + decoding from disk on every analysis
    // causes unnecessary I/O and memory churn.
    private var seasonDataCache: [String: Season] = [:]

    // MARK: - Initialization
    init() {
        personalizationService.delegate = self
    }

    // MARK: - Public Methods

    /// Analyze the current frame with the provided color info
    /// - Parameters:
    ///   - pixelBuffer: The current video pixel buffer for thumbnail creation
    ///   - colorInfo: Color information from segmentation
    func analyzeFrame(pixelBuffer: CVPixelBuffer, colorInfo: ColorExtractor.ColorInfo) {
        if colorInfo.skinColor == .clear || colorInfo.hairColor == .clear {
            delegate?.classificationService(self, didFailWithError: ClassificationError.insufficientColorData)
            return
        }

        // Get colors for analysis
        let skinColor = colorInfo.skinColor
        let hairColor = colorInfo.hairColor
        let leftEyeColor = colorInfo.leftEyeColor != .clear ? colorInfo.leftEyeColor : nil
        let rightEyeColor = colorInfo.rightEyeColor != .clear ? colorInfo.rightEyeColor : nil
        let averageEyeColor = colorInfo.averageEyeColor != .clear ? colorInfo.averageEyeColor : nil

        // Convert colors to Lab space
        let skinLab = ColorUtils.convertRGBToLab(color: skinColor)
        let hairLab = ColorUtils.convertRGBToLab(color: hairColor)

        // Convert eye colors to Lab space if available
        let leftEyeLab = leftEyeColor != nil ? ColorUtils.convertRGBToLab(color: leftEyeColor!) : nil
        let rightEyeLab = rightEyeColor != nil ? ColorUtils.convertRGBToLab(color: rightEyeColor!) : nil
        let averageEyeLab = averageEyeColor != nil ? ColorUtils.convertRGBToLab(color: averageEyeColor!) : nil

        // Calculate contrast
        let eyeColorForContrast = averageEyeColor ?? leftEyeColor ?? rightEyeColor ?? skinColor
        let contrastResult = ContrastCalculator.analyzeContrast(
            skinColor: skinColor,
            hairColor: hairColor,
            eyeColor: eyeColorForContrast
        )

        // Perform classification with the season classifier
        let classificationResult = SeasonClassifier.classifySeason(
            skinLab: (skinLab.L, skinLab.a, skinLab.b),
            hairLab: (hairLab.L, hairLab.a, hairLab.b)
        )

        // Create thumbnail from current frame
        let thumbnail = createThumbnailFromPixelBuffer(pixelBuffer)

        // Create analysis result - use macroSeason for backward compatibility with existing UI
        let result = AnalysisResult(
            season: classificationResult.macroSeason,
            detailedSeasonName: classificationResult.detailedSeason.rawValue,
            confidence: classificationResult.confidence,
            deltaEToNextClosest: classificationResult.deltaEToNextClosest,
            nextClosestSeason: classificationResult.nextClosestSeason,
            skinColor: skinColor,
            skinColorLab: skinLab,
            hairColor: hairColor,
            hairColorLab: hairLab,
            leftEyeColor: leftEyeColor,
            leftEyeColorLab: leftEyeLab != nil ? (L: CGFloat(leftEyeLab!.L), a: CGFloat(leftEyeLab!.a), b: CGFloat(leftEyeLab!.b)) : nil,
            rightEyeColor: rightEyeColor,
            rightEyeColorLab: rightEyeLab != nil ? (L: CGFloat(rightEyeLab!.L), a: CGFloat(rightEyeLab!.a), b: CGFloat(rightEyeLab!.b)) : nil,
            averageEyeColor: averageEyeColor,
            averageEyeColorLab: averageEyeLab != nil ? (L: CGFloat(averageEyeLab!.L), a: CGFloat(averageEyeLab!.a), b: CGFloat(averageEyeLab!.b)) : nil,
            leftEyeConfidence: colorInfo.leftEyeConfidence,
            rightEyeConfidence: colorInfo.rightEyeConfidence,
            contrastValue: contrastResult.value,
            contrastLevel: contrastResult.level.rawValue,
            contrastDescription: contrastResult.description,
            thumbnail: thumbnail
        )

        // Add detailed season information for debugging
        #if DEBUG
        print("🔵 ClassificationService: Detailed Season = \(classificationResult.detailedSeason.rawValue)")
        print("🔵 ClassificationService: Macro Season = \(classificationResult.macroSeason.rawValue)")
        #endif

        // First notify delegate with basic analysis result
        delegate?.classificationService(self, didCompleteAnalysis: result)

        // Then attempt personalization if API is available
        // Use the detailed season name for personalization to get the specific 12-season data
        attemptPersonalization(for: result, detailedSeason: classificationResult.detailedSeason.rawValue)
    }

    // MARK: - Private Methods

    private func attemptPersonalization(for analysisResult: AnalysisResult, detailedSeason: String) {
        #if DEBUG
        print("🔵 ClassificationService: attemptPersonalization called")
        print("🔵 ClassificationService: analysisResult.season = \(analysisResult.season)")
        print("🔵 ClassificationService: detailedSeason = \(detailedSeason)")
        #endif

        // Load season data for personalization using the detailed season name
        guard let seasonData = loadSeasonData(for: detailedSeason) else {
            #if DEBUG
            print("🔴 ClassificationService: Failed to load season data, skipping personalization")
            #endif
            // Couldn't load season data - fall back to default
            return
        }

        #if DEBUG
        print("🟢 ClassificationService: Season data loaded successfully, calling DNA PersonalizationService")
        #endif

        // Use DNA-enhanced personalization for better results
        personalizationService.generateDNAPersonalization(
            for: analysisResult,
            seasonData: seasonData,
            detailedSeasonName: detailedSeason
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let personalizedData):
                self.delegate?.classificationService(self, didCompletePersonalization: personalizedData)
            case .failure(let error):
                self.delegate?.classificationService(self, didFailPersonalization: error, fallbackResult: analysisResult)
            }
        }
    }

    private func loadSeasonData(for seasonName: String) -> Season? {
        // Return cached value — avoids re-reading and re-decoding JSON on every analysis
        if let cached = seasonDataCache[seasonName] {
            return cached
        }

        let result = loadSeasonDataFromDisk(for: seasonName)
        // Cache whatever we found (including mock fallbacks) so subsequent analyses are free
        if let result {
            seasonDataCache[seasonName] = result
        }
        return result
    }

    private func loadSeasonDataFromDisk(for mappedSeasonName: String) -> Season? {
        #if DEBUG
        print("🔵 ClassificationService: loadSeasonData called with seasonName: '\(mappedSeasonName)'")
        #endif

        // Helper: attempt to decode season from a bundle URL
        func decode(from url: URL) -> Season? {
            do {
                let data = try Data(contentsOf: url)
                let seasonData = try JSONDecoder().decode([String: Season].self, from: data)
                #if DEBUG
                print("🟢 ClassificationService: Successfully loaded and parsed season data for \(mappedSeasonName)")
                #endif
                return seasonData[mappedSeasonName]
            } catch {
                #if DEBUG
                print("🔴 ClassificationService: Error parsing season data for \(mappedSeasonName): \(error)")
                #endif
                return nil
            }
        }

        // Try bundle root first (where they seem to be working)
        if let url = Bundle.main.url(forResource: mappedSeasonName, withExtension: "json") {
            #if DEBUG
            print("🟢 ClassificationService: Found season file in bundle root at \(url)")
            #endif
            if let season = decode(from: url) { return season }
        }

        // Fallback: Try Resources/Seasons subdirectory
        #if DEBUG
        print("🔵 ClassificationService: Trying Resources/Seasons subdirectory")
        #endif
        if let url = Bundle.main.url(forResource: mappedSeasonName, withExtension: "json", subdirectory: "Resources/Seasons") {
            #if DEBUG
            print("🟢 ClassificationService: Found season file in Resources/Seasons at \(url)")
            #endif
            if let season = decode(from: url) { return season }
        }

        // Fallback: Try just "Seasons" subdirectory
        #if DEBUG
        print("🔵 ClassificationService: Trying Seasons subdirectory")
        #endif
        if let url = Bundle.main.url(forResource: mappedSeasonName, withExtension: "json", subdirectory: "Seasons") {
            #if DEBUG
            print("🟢 ClassificationService: Found season file in Seasons at \(url)")
            #endif
            if let season = decode(from: url) { return season }
        }

        // If all attempts fail
        #if DEBUG
        print("🔴 ClassificationService: Could not find season file in any location")
        print("🟡 ClassificationService: Creating mock season data to allow PersonalizationService to run for debugging")
        #endif
        print("Could not find \(mappedSeasonName).json in app bundle")

        // Create a mock Season object so PersonalizationService can still run for debugging
        return createMockSeason(for: mappedSeasonName)
    }

    /// Create a mock Season object for debugging PersonalizationService when JSON parsing fails
    private func createMockSeason(for seasonName: String) -> Season {
        #if DEBUG
        print("🟡 ClassificationService: createMockSeason called for: '\(seasonName)'")
        #endif

        // First, try to load "True Autumn" as a fallback if we're not already trying that
        if seasonName != "True Autumn" {
            if let fallbackSeason = loadTrueAutumnFallback() {
                return fallbackSeason
            }
        }

        #if DEBUG
        print("🔴 ClassificationService: All fallback attempts failed, creating completely mock season")
        #endif

        return createCompleteMockSeason(for: seasonName)
    }

    /// Try to load True Autumn as a fallback season
    private func loadTrueAutumnFallback() -> Season? {
        #if DEBUG
        print("🟡 ClassificationService: Attempting to load 'True Autumn' as fallback")
        #endif

        // Try bundle root first
        if let url = Bundle.main.url(forResource: "True Autumn", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let seasonData = try JSONDecoder().decode([String: Season].self, from: data)
                if let trueAutumn = seasonData["True Autumn"] {
                    #if DEBUG
                    print("🟢 ClassificationService: Successfully loaded True Autumn as fallback from bundle root")
                    #endif
                    return trueAutumn
                }
            } catch {
                #if DEBUG
                print("🔴 ClassificationService: Failed to parse True Autumn fallback: \(error)")
                #endif
            }
        }

        // Try subdirectories
        if let url = Bundle.main.url(forResource: "True Autumn", withExtension: "json", subdirectory: "Resources/Seasons") {
            do {
                let data = try Data(contentsOf: url)
                let seasonData = try JSONDecoder().decode([String: Season].self, from: data)
                if let trueAutumn = seasonData["True Autumn"] {
                    #if DEBUG
                    print("🟢 ClassificationService: Successfully loaded True Autumn as fallback from Resources/Seasons")
                    #endif
                    return trueAutumn
                }
            } catch {
                #if DEBUG
                print("🔴 ClassificationService: Failed to parse True Autumn fallback from subdirectory: \(error)")
                #endif
            }
        }

        if let url = Bundle.main.url(forResource: "True Autumn", withExtension: "json", subdirectory: "Seasons") {
            do {
                let data = try Data(contentsOf: url)
                let seasonData = try JSONDecoder().decode([String: Season].self, from: data)
                if let trueAutumn = seasonData["True Autumn"] {
                    #if DEBUG
                    print("🟢 ClassificationService: Successfully loaded True Autumn as fallback from Seasons")
                    #endif
                    return trueAutumn
                }
            } catch {
                #if DEBUG
                print("🔴 ClassificationService: Failed to parse True Autumn fallback from Seasons: \(error)")
                #endif
            }
        }

        return nil
    }

    /// Create a completely mock season for debugging when no real data is available
    private func createCompleteMockSeason(for seasonName: String) -> Season {
        // Create mock characteristics
        let mockEyes = Season.Characteristics.Features.EyeFeatureDescription(
            description: "Mock eye description for debugging",
            eyeColors: ["brown", "green"],
            image: nil
        )

        let mockSkin = Season.Characteristics.Features.SkinFeatureDescription(
            description: "Mock skin description for debugging",
            skinTones: ["1": ["warm"], "2": ["warm"]],
            image: nil
        )

        let mockHair = Season.Characteristics.Features.HairFeatureDescription(
            description: "Mock hair description for debugging",
            hairColors: ["brown": ["medium"]],
            image: nil
        )

        let mockContrast = Season.Characteristics.Features.Contrast(
            value: "medium",
            description: "Mock contrast for debugging"
        )

        let mockFeatures = Season.Characteristics.Features(
            eyes: mockEyes,
            skin: mockSkin,
            hair: mockHair,
            contrast: mockContrast
        )

        let mockCharacteristics = Season.Characteristics(
            note: "Mock note for debugging",
            overview: "Mock overview for debugging PersonalizationService",
            features: mockFeatures
        )

        // Create mock palette
        let mockColorAspect = Season.Palette.ColorAspect(
            value: "warm",
            explanation: "Mock explanation for debugging"
        )

        let mockSisterPalettes = Season.Palette.SisterPalettes(
            description: "Mock sister palettes for debugging",
            sisters: ["Mock Season 1", "Mock Season 2"],
            image: nil
        )

        let mockPalette = Season.Palette(
            description: "Mock palette description for debugging",
            hue: mockColorAspect,
            value: mockColorAspect,
            chroma: mockColorAspect,
            sisterPalettes: mockSisterPalettes,
            paletteImgUrl: nil
        )

        // Create mock styling
        let mockStyleDescription = Season.Styling.StyleDescription(
            description: "Mock neutrals description",
            image: nil
        )

        let mockColorsToAvoid = Season.Styling.ColorsToAvoid(
            description: "Mock colors to avoid",
            colors: ["Mock color 1", "Mock color 2"],
            image: nil
        )

        let mockStyling = Season.Styling(
            neutrals: mockStyleDescription,
            colorsToAvoid: mockColorsToAvoid,
            colorCombinations: nil,
            patternsAndPrints: nil,
            metalsAndAccessories: nil
        )

        return Season(
            name: seasonName,
            tagline: "Mock tagline for debugging",
            introduction: "Mock introduction for debugging PersonalizationService",
            characteristics: mockCharacteristics,
            palette: mockPalette,
            styling: mockStyling
        )
    }

    /// Create a thumbnail from a pixel buffer
    /// - Parameter pixelBuffer: CVPixelBuffer to convert
    /// - Returns: UIImage thumbnail
    // Shared CIContext — creating one per analysis call allocates GPU memory every time.
    // CIContext is thread-safe and designed to be reused across calls.
    private static let sharedCIContext = CIContext(options: [.useSoftwareRenderer: false])

    // Target thumbnail size — full-resolution frames (~8 MB each) are too large to store.
    private static let thumbnailSize = CGSize(width: 300, height: 300)

    private func createThumbnailFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        return autoreleasepool {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

            // Scale down to thumbnail size before rasterising to CGImage
            let scaleX = Self.thumbnailSize.width / ciImage.extent.width
            let scaleY = Self.thumbnailSize.height / ciImage.extent.height
            let scale = min(scaleX, scaleY)
            let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

            guard let cgImage = Self.sharedCIContext.createCGImage(scaledImage, from: scaledImage.extent) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }
    }
}

// MARK: - PersonalizationServiceDelegate

extension ClassificationService: PersonalizationServiceDelegate {
    func personalizationService(_ service: PersonalizationService, didGeneratePersonalization personalizedData: PersonalizedSeasonData) {
        delegate?.classificationService(self, didCompletePersonalization: personalizedData)
    }

    func personalizationService(_ service: PersonalizationService, didFailWithError error: Error) {
        // This will be handled in the completion block of generatePersonalization
    }
}

// MARK: - ClassificationError
enum ClassificationError: Error {
    case insufficientColorData
    case analysisFailure
}

// MARK: - Debug LLM Testing

#if DEBUG
extension ClassificationService {

    /// Feed a pre-built AnalysisResult through the real LLM personalization pipeline.
    /// Loads the season JSON, calls generateDNAPersonalization, and returns the result.
    /// Use this to test LLM responses without performing a live camera analysis.
    func testPersonalization(
        with mockResult: AnalysisResult,
        completion: @escaping (Result<PersonalizedSeasonData, Error>) -> Void
    ) {
        let detailedSeason = mockResult.detailedSeasonName

        print("🧪 ClassificationService [LLM Test]: starting with season '\(detailedSeason)'")

        guard let seasonData = loadSeasonData(for: detailedSeason) else {
            print("🔴 ClassificationService [LLM Test]: could not load season data for '\(detailedSeason)'")
            completion(.failure(ClassificationError.analysisFailure))
            return
        }

        print("🟢 ClassificationService [LLM Test]: season data loaded, calling PersonalizationService")

        personalizationService.generateDNAPersonalization(
            for: mockResult,
            seasonData: seasonData,
            detailedSeasonName: detailedSeason,
            completion: completion
        )
    }
}
#endif
