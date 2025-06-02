//
//  SeasonViewNavigationManager.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import UIKit
import SwiftUI

/// Manages navigation between different season views based on personalization availability
class SeasonViewNavigationManager {
    
    // MARK: - Static Methods
    
    /// Present the appropriate season view based on available data
    /// - Parameters:
    ///   - from: The presenting view controller
    ///   - analysisResult: The basic analysis result
    ///   - personalizedData: Optional personalized data
    ///   - animated: Whether to animate the presentation
    static func presentSeasonView(
        from presentingViewController: UIViewController,
        analysisResult: AnalysisResult,
        personalizedData: PersonalizedSeasonData? = nil,
        animated: Bool = true
    ) {
        // Determine which view to show
        if let personalizedData = personalizedData {
            presentPersonalizedSeasonView(
                from: presentingViewController,
                personalizedData: personalizedData,
                animated: animated
            )
        } else {
            presentDefaultSeasonView(
                from: presentingViewController,
                analysisResult: analysisResult,
                animated: animated
            )
        }
    }
    
    /// Present the personalized season view
    /// - Parameters:
    ///   - from: The presenting view controller
    ///   - personalizedData: The personalized season data
    ///   - animated: Whether to animate the presentation
    static func presentPersonalizedSeasonView(
        from presentingViewController: UIViewController,
        personalizedData: PersonalizedSeasonData,
        animated: Bool = true
    ) {
        // Get season colors for theming
        let seasonColors = getSeasonColors(for: personalizedData.baseSeason)
        
        // Create personalized view
        let personalizedView = PersonalizedSeasonView(
            personalizedData: personalizedData,
            primaryColor: seasonColors.primary,
            paletteWhite: seasonColors.paletteWhite,
            accentColor: seasonColors.accent,
            accentColor2: seasonColors.accent2,
            backgroundColor: seasonColors.background,
            secondaryBackgroundColor: seasonColors.secondaryBackground,
            textColor: seasonColors.text,
            moduleColor: seasonColors.module
        )
        
        // Wrap in hosting controller
        let hostingController = UIHostingController(rootView: personalizedView)
        hostingController.modalPresentationStyle = .fullScreen
        
        // Present
        presentingViewController.present(hostingController, animated: animated)
    }
    
    /// Present the default season view
    /// - Parameters:
    ///   - from: The presenting view controller
    ///   - analysisResult: The analysis result
    ///   - animated: Whether to animate the presentation
    static func presentDefaultSeasonView(
        from presentingViewController: UIViewController,
        analysisResult: AnalysisResult,
        animated: Bool = true
    ) {
        // Get season colors for theming
        let seasonColors = getSeasonColors(for: analysisResult.season.rawValue)
        
        // Create default view
        let defaultView = DefaultSeasonView(
            seasonName: analysisResult.detailedSeasonName,
            primaryColor: seasonColors.primary,
            paletteWhite: seasonColors.paletteWhite,
            accentColor: seasonColors.accent,
            accentColor2: seasonColors.accent2,
            backgroundColor: seasonColors.background,
            secondaryBackgroundColor: seasonColors.secondaryBackground,
            textColor: seasonColors.text,
            moduleColor: seasonColors.module
        )
        
        // Wrap in hosting controller
        let hostingController = UIHostingController(rootView: defaultView)
        hostingController.modalPresentationStyle = .fullScreen
        
        // Present
        presentingViewController.present(hostingController, animated: animated)
    }
    
    // MARK: - Private Helpers
    
    private static func getSeasonColors(for seasonName: String) -> SeasonColors {
        // This should match the existing color scheme logic from your app
        // For now, using a basic color scheme - you can enhance this based on your existing season color logic
        
        // Map detailed season names to basic season names for color selection
        let basicSeasonName = mapToBasicSeason(seasonName)
        
        switch basicSeasonName.lowercased() {
        case "spring":
            return SeasonColors(
                primary: Color(hex: "#E8B17A"),
                paletteWhite: Color(hex: "#F5F5DC"),
                accent: Color(hex: "#90EE90"),
                accent2: Color(hex: "#FFA07A"),
                background: Color(hex: "#FFFACD"),
                secondaryBackground: Color(hex: "#F0E68C"),
                text: Color(hex: "#2F4F2F"),
                module: Color(hex: "#DDA0DD")
            )
        case "summer":
            return SeasonColors(
                primary: Color(hex: "#87CEEB"),
                paletteWhite: Color(hex: "#F0F8FF"),
                accent: Color(hex: "#DDA0DD"),
                accent2: Color(hex: "#FFB6C1"),
                background: Color(hex: "#E6E6FA"),
                secondaryBackground: Color(hex: "#B0C4DE"),
                text: Color(hex: "#2F4F4F"),
                module: Color(hex: "#AFEEEE")
            )
        case "autumn":
            return SeasonColors(
                primary: Color(hex: "#CD853F"),
                paletteWhite: Color(hex: "#FFF8DC"),
                accent: Color(hex: "#D2691E"),
                accent2: Color(hex: "#B22222"),
                background: Color(hex: "#FFEFD5"),
                secondaryBackground: Color(hex: "#DEB887"),
                text: Color(hex: "#8B4513"),
                module: Color(hex: "#F4A460")
            )
        case "winter":
            return SeasonColors(
                primary: Color(hex: "#4682B4"),
                paletteWhite: Color(hex: "#F8F8FF"),
                accent: Color(hex: "#DC143C"),
                accent2: Color(hex: "#9932CC"),
                background: Color(hex: "#F0F8FF"),
                secondaryBackground: Color(hex: "#B0C4DE"),
                text: Color(hex: "#191970"),
                module: Color(hex: "#6495ED")
            )
        default:
            // Default neutral colors
            return SeasonColors(
                primary: Color.blue,
                paletteWhite: Color.white,
                accent: Color.purple,
                accent2: Color.pink,
                background: Color.gray.opacity(0.1),
                secondaryBackground: Color.gray.opacity(0.2),
                text: Color.black,
                module: Color.gray.opacity(0.3)
            )
        }
    }
    
    /// Maps detailed season names to basic season names for color theming
    private static func mapToBasicSeason(_ seasonName: String) -> String {
        let lowercased = seasonName.lowercased()
        
        if lowercased.contains("spring") {
            return "spring"
        } else if lowercased.contains("summer") {
            return "summer"
        } else if lowercased.contains("autumn") {
            return "autumn"
        } else if lowercased.contains("winter") {
            return "winter"
        }
        
        // Fallback to the original name if no mapping found
        return seasonName
    }
}

// MARK: - Supporting Types

struct SeasonColors {
    let primary: Color
    let paletteWhite: Color
    let accent: Color
    let accent2: Color
    let background: Color
    let secondaryBackground: Color
    let text: Color
    let module: Color
} 