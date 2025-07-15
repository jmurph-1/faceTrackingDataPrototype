//
//  DebugPersonalizedSeasonHelper.swift
//  ImageSegmenter
//
//  Created by John Murphy on 12/27/24.
//

import SwiftUI
import UIKit

/// Debug helper for testing PersonalizedSeasonView with mock data
struct DebugPersonalizedSeasonHelper {
    
    /// Present PersonalizedSeasonView with mock data
    /// - Parameters:
    ///   - mockData: Optional specific mock data (uses random if nil)
    ///   - from: The presenting view controller
    static func presentMockPersonalizedView(
        mockData: PersonalizedSeasonData? = nil,
        from viewController: UIViewController
    ) {
        let data = mockData ?? MockPersonalizedSeasonDataFactory.random()
        let colors = getSeasonColors(for: data.baseSeason)
        
        let personalizedView = PersonalizedSeasonView(
            personalizedData: data,
            primaryColor: colors.primary,
            paletteWhite: colors.paletteWhite,
            accentColor: colors.accent,
            accentColor2: colors.accent2,
            backgroundColor: colors.background,
            secondaryBackgroundColor: colors.secondaryBackground,
            textColor: colors.text,
            moduleColor: colors.module
        )
        
        let hostingController = UIHostingController(rootView: personalizedView)
        hostingController.modalPresentationStyle = .fullScreen
        viewController.present(hostingController, animated: true)
    }
    
    /// Create a debug menu for testing different mock scenarios
    static func presentDebugMenu(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Debug Personalized Season View",
            message: "Choose a mock scenario to test",
            preferredStyle: .actionSheet
        )
        
        // Add options for different mock scenarios
        alert.addAction(UIAlertAction(title: "Bright Spring (DNA Blend)", style: .default) { _ in
            presentMockPersonalizedView(
                mockData: MockPersonalizedSeasonDataFactory.brightSpringWithBlend(),
                from: viewController
            )
        })
        
        alert.addAction(UIAlertAction(title: "Soft Autumn (Pure)", style: .default) { _ in
            presentMockPersonalizedView(
                mockData: MockPersonalizedSeasonDataFactory.softAutumn(),
                from: viewController
            )
        })
        
        alert.addAction(UIAlertAction(title: "Dark Winter (Complex)", style: .default) { _ in
            presentMockPersonalizedView(
                mockData: MockPersonalizedSeasonDataFactory.deepWinterComplex(),
                from: viewController
            )
        })
        
        alert.addAction(UIAlertAction(title: "Random", style: .default) { _ in
            presentMockPersonalizedView(from: viewController)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Handle iPad presentation
        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(alert, animated: true)
    }
    
    /// Color configuration for PersonalizedSeasonView
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
    
    /// Get appropriate colors for a season
    static func getSeasonColors(for season: String) -> SeasonColors {
        let seasonLower = season.lowercased()
        
        if seasonLower.contains("spring") {
            return SeasonColors(
                primary: Color(hex: "#FFB347"),
                paletteWhite: Color.white,
                accent: Color(hex: "#FF6B35"),
                accent2: Color(hex: "#06FFA5"),
                background: Color(.systemBackground),
                secondaryBackground: Color(.secondarySystemBackground),
                text: Color(.label),
                module: Color(.systemGray6)
            )
        } else if seasonLower.contains("summer") {
            return SeasonColors(
                primary: Color(hex: "#87CEEB"),
                paletteWhite: Color.white,
                accent: Color(hex: "#DDA0DD"),
                accent2: Color(hex: "#FFB6C1"),
                background: Color(.systemBackground),
                secondaryBackground: Color(.secondarySystemBackground),
                text: Color(.label),
                module: Color(.systemGray6)
            )
        } else if seasonLower.contains("autumn") {
            return SeasonColors(
                primary: Color(hex: "#CD853F"),
                paletteWhite: Color.white,
                accent: Color(hex: "#D2691E"),
                accent2: Color(hex: "#DAA520"),
                background: Color(.systemBackground),
                secondaryBackground: Color(.secondarySystemBackground),
                text: Color(.label),
                module: Color(.systemGray6)
            )
        } else { // Winter
            return SeasonColors(
                primary: Color(hex: "#4682B4"),
                paletteWhite: Color.white,
                accent: Color(hex: "#DC143C"),
                accent2: Color(hex: "#800080"),
                background: Color(.systemBackground),
                secondaryBackground: Color(.secondarySystemBackground),
                text: Color(.label),
                module: Color(.systemGray6)
            )
        }
    }
}

// MARK: - SwiftUI Preview Helper

#if DEBUG
struct DebugPersonalizedSeasonView_Previews: PreviewProvider {
    static var previews: some View {
        let mockData = MockPersonalizedSeasonDataFactory.brightSpringWithBlend()
        let colors = DebugPersonalizedSeasonHelper.getSeasonColors(for: mockData.baseSeason)
        
        PersonalizedSeasonView(
            personalizedData: mockData,
            primaryColor: colors.primary,
            paletteWhite: colors.paletteWhite,
            accentColor: colors.accent,
            accentColor2: colors.accent2,
            backgroundColor: colors.background,
            secondaryBackgroundColor: colors.secondaryBackground,
            textColor: colors.text,
            moduleColor: colors.module
        )
    }
}
#endif 
