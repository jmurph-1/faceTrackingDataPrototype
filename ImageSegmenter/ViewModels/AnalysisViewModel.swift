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
import Combine

// MARK: - AnalysisViewModel
class AnalysisViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var season: SeasonClassifier.Season?
    @Published var confidence: Double = 0.0
    @Published var deltaEToNextClosest: Double = 0.0
    @Published var nextClosestSeason: SeasonClassifier.Season?
    @Published var skinColor: UIColor?
    @Published var hairColor: UIColor?
    @Published var thumbnail: UIImage?
    @Published var skinColorLab: ColorConverters.LabColor?
    @Published var hairColorLab: ColorConverters.LabColor?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    /// Formatted confidence level string
    var confidenceText: String {
        return String(format: "%.1f%%", confidence * 100)
    }
    
    /// Season display name
    var seasonDisplayName: String {
        guard let season = season else { return "Unknown" }
        return season.displayName
    }
    
    /// Season description
    var seasonDescription: String {
        guard let season = season else { return "" }
        return season.seasonDescription
    }
    
    /// Color palette for the determined season
    var seasonColorPalette: [UIColor] {
        guard let season = season else { return [] }
        return season.colorPalette
    }
    
    /// Determine if the confidence is high enough to be reliable
    var isConfidenceHigh: Bool {
        return confidence >= 0.7
    }
    
    // MARK: - Initialization
    init() {
        // Empty initialization
    }
    
    // MARK: - Public Methods
    
    /// Update the view model with analysis result
    /// - Parameter result: The analysis result from classification
    func updateWithResult(_ result: AnalysisResult) {
        self.season = result.season
        self.confidence = Double(result.confidence)
        self.deltaEToNextClosest = Double(result.deltaEToNextClosest)
        self.nextClosestSeason = result.nextClosestSeason
        self.skinColor = result.skinColor
        self.hairColor = result.hairColor
        self.thumbnail = result.thumbnail
        
        // Manually convert Lab tuples to ColorConverters.LabColor structs
        if let skinLabTuple = result.skinColorLab {
            self.skinColorLab = ColorConverters.LabColor(
                L: skinLabTuple.L,
                a: skinLabTuple.a,
                b: skinLabTuple.b
            )
        } else {
            self.skinColorLab = nil
        }
        
        if let hairLabTuple = result.hairColorLab {
            self.hairColorLab = ColorConverters.LabColor(
                L: hairLabTuple.L,
                a: hairLabTuple.a,
                b: hairLabTuple.b
            )
        } else {
            self.hairColorLab = nil
        }
        
        self.errorMessage = nil
        self.isLoading = false
    }
    
    /// Clear any current analysis result
    func clearResult() {
        self.season = nil
        self.confidence = 0.0
        self.deltaEToNextClosest = 0.0
        self.nextClosestSeason = nil
        self.skinColor = nil
        self.hairColor = nil
        self.thumbnail = nil
        self.skinColorLab = nil
        self.hairColorLab = nil
        self.errorMessage = nil
    }
    
    /// Set the loading state
    /// - Parameter isLoading: Whether the view model is loading data
    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }
    
    /// Set error message
    /// - Parameter message: Error message to display
    func setError(_ message: String) {
        self.errorMessage = message
        self.isLoading = false
    }
    
    /// Get human-readable and localized description for the analysis result
    func getAnalysisDescription() -> String {
        guard let season = season else {
            return "No analysis available."
        }
        
        var description = "You are a \(seasonDisplayName)."
        
        if let nextClosestSeason = nextClosestSeason {
            description += " Your next closest season is \(nextClosestSeason.displayName)."
        }
        
        if confidence > 0.9 {
            description += " This classification has very high confidence."
        } else if confidence > 0.7 {
            description += " This classification has good confidence."
        } else if confidence > 0.5 {
            description += " This classification has moderate confidence."
        } else {
            description += " This classification has low confidence. You might want to try again with better lighting."
        }
        
        return description
    }
    
    /// Get color recommendations based on the determined season
    func getColorRecommendations() -> [String] {
        guard let season = season else { return [] }
        
        switch season {
        case .spring:
            return [
                "Warm, bright colors like coral and peach",
                "Clear yellows and warm greens",
                "Golden browns and ivory",
                "Avoid black and dark colors"
            ]
        case .summer:
            return [
                "Soft, cool colors like lavender and powder blue",
                "Rose pinks and soft grays",
                "Mauve and dusty blue",
                "Avoid orange and very bright colors"
            ]
        case .autumn:
            return [
                "Rich, warm colors like rust and olive",
                "Terracotta and amber",
                "Warm browns and deep gold",
                "Avoid bright cool colors"
            ]
        case .winter:
            return [
                "High contrast colors like true white and black",
                "Jewel tones like royal blue and emerald",
                "Clear, bright colors",
                "Avoid muted or dusty colors"
            ]
        }
    }
}

// MARK: - Season Extension
extension SeasonClassifier.Season {
    /// Display name for the season
    var displayName: String {
        switch self {
        case .spring:
            return "Spring"
        case .summer:
            return "Summer"
        case .autumn:
            return "Autumn"
        case .winter:
            return "Winter"
        }
    }
    
    /// Description for the season
    var seasonDescription: String {
        switch self {
        case .spring:
            return "Springs have warm, clear coloring with golden undertones. They typically have golden blonde, auburn, or warm brown hair, and bright, clear eyes."
        case .summer:
            return "Summers have cool, soft coloring with blue undertones. They typically have ash blonde, cool brown, or silver hair, and soft blue, gray, or cool green eyes."
        case .autumn:
            return "Autumns have warm, muted coloring with golden-orange undertones. They typically have auburn, copper, or warm brown hair, and amber, hazel, or warm green eyes."
        case .winter:
            return "Winters have cool, clear coloring with blue undertones. They typically have dark brown, black, or platinum hair, and clear blue, deep brown, or dark green eyes."
        }
    }
    
    /// Color palette for the season
    var colorPalette: [UIColor] {
        switch self {
        case .spring:
            return [
                UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1.0), // Warm Yellow
                UIColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0), // Peach
                UIColor(red: 0.4, green: 0.8, blue: 0.6, alpha: 1.0), // Warm Green
                UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0), // Clear Blue
                UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)  // Warm Pink
            ]
        case .summer:
            return [
                UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0), // Powder Blue
                UIColor(red: 0.9, green: 0.8, blue: 0.9, alpha: 1.0), // Lavender
                UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0), // Soft Gray
                UIColor(red: 0.7, green: 0.9, blue: 0.7, alpha: 1.0), // Soft Green
                UIColor(red: 1.0, green: 0.8, blue: 0.9, alpha: 1.0)  // Rose Pink
            ]
        case .autumn:
            return [
                UIColor(red: 0.8, green: 0.5, blue: 0.3, alpha: 1.0), // Terracotta
                UIColor(red: 0.6, green: 0.5, blue: 0.1, alpha: 1.0), // Olive
                UIColor(red: 0.6, green: 0.3, blue: 0.1, alpha: 1.0), // Rust
                UIColor(red: 0.5, green: 0.3, blue: 0.2, alpha: 1.0), // Brown
                UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1.0)  // Gold
            ]
        case .winter:
            return [
                UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), // Black
                UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), // White
                UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0), // Royal Blue
                UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0), // True Red
                UIColor(red: 0.0, green: 0.6, blue: 0.4, alpha: 1.0)  // Emerald
            ]
        }
    }
} 