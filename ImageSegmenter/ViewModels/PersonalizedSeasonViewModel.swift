//
//  PersonalizedSeasonViewModel.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import UIKit
import SwiftUI
import Combine

class PersonalizedSeasonViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var personalizedData: PersonalizedSeasonData
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    // MARK: - Properties
    
    private let personalizationService = PersonalizationService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(personalizedData: PersonalizedSeasonData) {
        self.personalizedData = personalizedData
    }
    
    // MARK: - Computed Properties
    
    var seasonName: String {
        return personalizedData.displaySeasonName
    }
    
    var personalizedTagline: String {
        return personalizedData.personalizedTagline
    }
    
    var userCharacteristics: String {
        return personalizedData.userCharacteristics
    }
    
    var personalizedOverview: String {
        return personalizedData.personalizedOverview
    }
    
    var emphasizedColors: [Color] {
        return personalizedData.emphasizedUIColors.map { Color($0) }
    }
    
    var colorsToAvoid: [Color] {
        return personalizedData.colorsToAvoidUIColors.map { Color($0) }
    }
    
    var confidence: String {
        return personalizedData.confidencePercentage
    }
    
    var formattedDate: String {
        return personalizedData.formattedDate
    }
    
    // MARK: - Color Recommendations
    
    var bestNeutrals: ColorRecommendation {
        return personalizedData.colorRecommendations.bestNeutrals
    }
    
    var bestAccents: ColorRecommendation {
        return personalizedData.colorRecommendations.bestAccents
    }
    
    var bestBaseColors: ColorRecommendation {
        return personalizedData.colorRecommendations.bestBaseColors
    }
    
    var lipColors: ColorRecommendation {
        return personalizedData.colorRecommendations.lipColors
    }
    
    var eyeColors: ColorRecommendation {
        return personalizedData.colorRecommendations.eyeColors
    }
    
    var hairColorSuggestions: ColorRecommendation? {
        return personalizedData.colorRecommendations.hairColorSuggestions
    }
    
    // MARK: - Styling Advice
    
    var clothingAdvice: StylingRecommendation {
        return personalizedData.stylingAdvice.clothingAdvice
    }
    
    var accessoryAdvice: StylingRecommendation {
        return personalizedData.stylingAdvice.accessoryAdvice
    }
    
    var patternAdvice: StylingRecommendation {
        return personalizedData.stylingAdvice.patternAdvice
    }
    
    var metalAdvice: StylingRecommendation {
        return personalizedData.stylingAdvice.metalAdvice
    }
    
    var specialConsiderations: String {
        return personalizedData.stylingAdvice.specialConsiderations
    }
    
    // MARK: - Helper Methods
    
    /// Get colors for a specific recommendation as SwiftUI Color objects
    /// - Parameter recommendation: The color recommendation
    /// - Returns: Array of SwiftUI Color objects
    func getColorsForRecommendation(_ recommendation: ColorRecommendation) -> [Color] {
        return recommendation.colors.compactMap { hexString in
            if let uiColor = UIColor(hex: hexString) {
                return Color(uiColor)
            }
            return nil
        }
    }
    
    /// Get all color recommendations grouped by category
    /// - Returns: Dictionary with category names as keys and recommendations as values
    func getAllColorRecommendations() -> [String: ColorRecommendation] {
        return [
            "Best Neutrals": bestNeutrals,
            "Best Accents": bestAccents,
            "Best Base Colors": bestBaseColors,
            "Lip Colors": lipColors,
            "Eye Colors": eyeColors
        ]
    }
    
    /// Get all styling recommendations grouped by category
    /// - Returns: Dictionary with category names as keys and recommendations as values
    func getAllStylingRecommendations() -> [String: StylingRecommendation] {
        return [
            "Clothing": clothingAdvice,
            "Accessories": accessoryAdvice,
            "Patterns": patternAdvice,
            "Metals": metalAdvice
        ]
    }
    
    /// Check if personalization data is high confidence
    /// - Returns: True if confidence is above 75%
    var isHighConfidence: Bool {
        return personalizedData.confidence > 0.75
    }
    
    /// Get color priority level as an integer for sorting
    /// - Parameter recommendation: The color recommendation
    /// - Returns: Priority as integer (1 = high, 2 = medium, 3 = low)
    func getPriorityLevel(for recommendation: ColorRecommendation) -> Int {
        switch recommendation.priority.lowercased() {
        case "high":
            return 1
        case "medium":
            return 2
        case "low":
            return 3
        default:
            return 2 // Default to medium
        }
    }
    
    /// Get sorted color recommendations by priority
    /// - Returns: Array of tuples with category name and recommendation, sorted by priority
    func getSortedColorRecommendations() -> [(String, ColorRecommendation)] {
        let recommendations = getAllColorRecommendations()
        return recommendations.sorted { first, second in
            let firstPriority = getPriorityLevel(for: first.value)
            let secondPriority = getPriorityLevel(for: second.value)
            return firstPriority < secondPriority
        }
    }
    
    /// Update personalized data (useful for refreshing from Core Data)
    /// - Parameter newData: Updated personalized season data
    func updatePersonalizedData(_ newData: PersonalizedSeasonData) {
        DispatchQueue.main.async {
            self.personalizedData = newData
        }
    }
    
    /// Clear any error state
    func clearError() {
        DispatchQueue.main.async {
            self.error = nil
        }
    }
}

// MARK: - Data Validation Extensions

extension PersonalizedSeasonViewModel {
    
    /// Validate that the personalized data contains sufficient information
    /// - Returns: True if data appears complete and valid
    var isDataValid: Bool {
        return !personalizedData.personalizedTagline.isEmpty &&
               !personalizedData.userCharacteristics.isEmpty &&
               !personalizedData.personalizedOverview.isEmpty &&
               !personalizedData.emphasizedColors.isEmpty
    }
    
    /// Get a summary of what's included in this personalization
    /// - Returns: Array of strings describing available content
    var contentSummary: [String] {
        var summary: [String] = []
        
        if !personalizedData.personalizedTagline.isEmpty {
            summary.append("Personalized tagline")
        }
        
        if !personalizedData.userCharacteristics.isEmpty {
            summary.append("Unique characteristics analysis")
        }
        
        if !personalizedData.emphasizedColors.isEmpty {
            summary.append("\(personalizedData.emphasizedColors.count) emphasized colors")
        }
        
        if !personalizedData.colorsToAvoid.isEmpty {
            summary.append("\(personalizedData.colorsToAvoid.count) colors to avoid")
        }
        
        let colorRecommendations = getAllColorRecommendations()
        summary.append("\(colorRecommendations.count) color recommendation categories")
        
        let stylingRecommendations = getAllStylingRecommendations()
        summary.append("\(stylingRecommendations.count) styling advice categories")
        
        return summary
    }
}

