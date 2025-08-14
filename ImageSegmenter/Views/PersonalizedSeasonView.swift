//
//  PersonalizedSeasonView.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import SwiftUI

struct PersonalizedSeasonView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: PersonalizedSeasonViewModel
    @State private var selectedModule: String?
    @State private var showingDefaultView = false

    // Customizable colors for UI elements (similar to DefaultSeasonView)
    private let primaryColor: Color
    private let paletteWhite: Color
    private let accentColor: Color
    private let accentColor2: Color
    private let backgroundColor: Color
    private let secondaryBackgroundColor: Color
    private let textColor: Color
    private let moduleColor: Color

    private let textSizeHeader = 45.0
    private let textSizeSubheader = 28.0

    init(personalizedData: PersonalizedSeasonData,
         primaryColor: Color,
         paletteWhite: Color,
         accentColor: Color,
         accentColor2: Color,
         backgroundColor: Color,
         secondaryBackgroundColor: Color,
         textColor: Color,
         moduleColor: Color) {
        self._viewModel = StateObject(wrappedValue: PersonalizedSeasonViewModel(personalizedData: personalizedData))
        self.primaryColor = primaryColor
        self.paletteWhite = paletteWhite
        self.accentColor = accentColor
        self.accentColor2 = accentColor2
        self.backgroundColor = backgroundColor
        self.secondaryBackgroundColor = secondaryBackgroundColor
        self.textColor = textColor
        self.moduleColor = moduleColor
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        headerViewContent()

                        if selectedModule == nil {
                            enhancedColorPalette
                                .padding(.horizontal)

                            modulesGridView
                                .padding()
                        } else {
                            detailView
                                .padding()
                        }
                    }
                }
            }
            .foregroundColor(textColor)
        }
        .sheet(isPresented: $showingDefaultView) {
            DefaultSeasonView(
                seasonName: viewModel.seasonName,
                primaryColor: primaryColor,
                paletteWhite: paletteWhite,
                accentColor: accentColor,
                accentColor2: accentColor2,
                backgroundColor: backgroundColor,
                secondaryBackgroundColor: secondaryBackgroundColor,
                textColor: textColor,
                moduleColor: moduleColor
            )
        }
    }

    private func headerViewContent() -> some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    showingDefaultView = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(paletteWhite)
                        .frame(width: 44, height: 44)
                        .background(primaryColor.opacity(0.2))
                        .clipShape(Circle())
                }

                Spacer()

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(paletteWhite)
                        .frame(width: 44, height: 44)
                        .background(primaryColor.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)

            // Your Color DNA Section
            if viewModel.isDNABlended || viewModel.personalizedData.seasonDNAData != nil {
                VStack(spacing: 16) {
                    HStack {
                        Text("Your Color DNA")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(primaryColor)

                        Spacer()

                        // Confidence indicator with colored dot
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.dnaConfidenceColor)
                                .frame(width: 8, height: 8)

                            Text(viewModel.dnaConfidenceLevel)
                                .font(.caption)
                                .foregroundColor(paletteWhite.opacity(0.8))
                        }
                    }

                    // Integrate SeasonDNARingChart
                    SeasonDNARingChart(
                        seasonDNA: viewModel.seasonDNA,
                        primaryColor: primaryColor,
                        secondaryColor: getDNASecondaryColor(),
                        tertiaryColor: getDNATertiaryColor(),
                        size: 160
                    )

                    // DNA explanation text
                    Text(viewModel.seasonDNA.explanation)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(paletteWhite.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .lineLimit(3)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(moduleColor.opacity(0.3))
                        .shadow(color: primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal)
            }

            Divider()
                .frame(height: 1)
                .overlay(primaryColor.opacity(0.2))
                .padding(.horizontal, 32)
        }
        .padding(.top)
        .frame(maxWidth: .infinity)
        .background(
            secondaryBackgroundColor
                .shadow(color: primaryColor.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private var enhancedColorPalette: some View {
        VStack(spacing: 20) {
            // Main EnhancedColorGrid for best colors
            if viewModel.personalizedData.hasEnhancedColorData,
               let enhancedData = viewModel.personalizedData.enhancedColorData {
                // Use enhanced color data if available
                VStack(spacing: 16) {

                    EnhancedColorGrid(
                        title: "Best Neutrals",
                        description: enhancedData.bestNeutrals.description,
                        colorItems: enhancedData.bestNeutrals.colors,
                        columns: 4
                    )

                    // Optional collapsible category sections
                    EnhancedColorGrid(
                        title: "Best Accents",
                        description: enhancedData.bestAccents.description,
                        colorItems: enhancedData.bestAccents.colors,
                        columns: 4
                    )
                    .padding(.top)
              
                    EnhancedColorGrid(
                        title: "Best Base Colors",
                        description: enhancedData.bestBaseColors.description,
                        colorItems: enhancedData.bestBaseColors.colors,
                        columns: 4
                    )
                    .padding(.top)
                        
                }
            } else {
                // Fallback to basic color display
                EnhancedColorGrid(
                    title: "Your Best Colors",
                    description: "Colors that complement your \(viewModel.seasonName) coloring",
                    colorItems: createBasicColorItems(from: viewModel.personalizedData.emphasizedColors),
                    columns: 4
                )
            }

            // Secondary EnhancedColorGrid for colors to avoid (if any)
            if !viewModel.personalizedData.colorsToAvoid.isEmpty {
                EnhancedColorGrid(
                    title: "Colors to Avoid",
                    description: "These colors may not complement your natural coloring",
                    colorItems: createBasicColorItems(from: viewModel.personalizedData.colorsToAvoid, isAvoidance: true),
                    isAvoidanceMode: true,
                    columns: 3
                )
            }

            // Add metals section after colors to avoid
            if viewModel.hasMetalRecommendations {
                PersonalizedMetalsGrid(
                    metals: viewModel.personalizedMetals,
                    primaryColor: primaryColor,
                    columns: 3
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private var modulesGridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
            moduleCard("Your Characteristics", icon: "person.crop.rectangle.fill", color: primaryColor)
            moduleCard("Color Recommendations", icon: "paintpalette.fill", color: primaryColor)
            moduleCard("Styling Guide", icon: "tshirt.fill", color: primaryColor)
            moduleCard("Makeup & Beauty", icon: "heart.circle.fill", color: primaryColor)
        }
        .padding(.horizontal, 16)
    }

    private func moduleCard(_ title: String, icon: String, color: Color) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedModule = title
            }
        }) {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(paletteWhite)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(moduleColor.opacity(0.95))
                    .shadow(color: color.opacity(0.15), radius: 15, x: 0, y: 8)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var detailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Button(action: {
                    withAnimation {
                        selectedModule = nil
                    }
                }) {
                    HStack(alignment: .center) {
                        Image(systemName: "chevron.left")
                    }
                    .foregroundColor(secondaryBackgroundColor)
                }

                Text(selectedModule ?? "")
                    .font(.system(size: textSizeSubheader, weight: .bold, design: .serif))
                    .foregroundColor(textColor)
            }
            .padding(.bottom)

            switch selectedModule {
            case "Your Characteristics":
                characteristicsView
            case "Color Recommendations":
                colorRecommendationsView
            case "Styling Guide":
                stylingGuideView
            case "Makeup & Beauty":
                makeupAndBeautyView
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Detail Views Extension

extension PersonalizedSeasonView {

    var characteristicsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(viewModel.userCharacteristics)
                .font(.body)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                        .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
                )

            Text("Personalized Overview")
                .font(.headline)
                .foregroundColor(textColor)

            Text(viewModel.personalizedOverview)
                .font(.body)

            Text("Special Considerations")
                .font(.headline)
                .foregroundColor(textColor)
                .padding(.top)

            Text(viewModel.specialConsiderations)
                .font(.body)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.1))
                        .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
                )
        }
    }

    var colorRecommendationsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            let sortedRecommendations = viewModel.getSortedColorRecommendations()

            ForEach(Array(sortedRecommendations.enumerated()), id: \.offset) { _, recommendationPair in
                let (categoryName, recommendation) = recommendationPair
                colorRecommendationSection(
                    title: categoryName,
                    recommendation: recommendation
                )
            }
        }
    }

    func colorRecommendationSection(title: String, recommendation: ColorRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(textColor)

                Spacer()

                Text(recommendation.priority.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(getPriorityColor(recommendation.priority))
                    )
                    .foregroundColor(.white)
            }

            Text(recommendation.description)
                .font(.body)

            HStack(spacing: 8) {
                ForEach(Array(viewModel.getColorsForRecommendation(recommendation).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }

            Text("Usage: \(recommendation.usageInstructions)")
                .font(.caption)
                .foregroundColor(textColor.opacity(0.7))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    var stylingGuideView: some View {
        VStack(alignment: .leading, spacing: 20) {
            stylingSection("Clothing", recommendation: viewModel.clothingAdvice)
            stylingSection("Accessories", recommendation: viewModel.accessoryAdvice)
            stylingSection("Patterns", recommendation: viewModel.patternAdvice)
            stylingSection("Metals", recommendation: viewModel.metalAdvice)
        }
    }

    func stylingSection(_ title: String, recommendation: StylingRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(textColor)

            Text(recommendation.recommendation)
                .font(.body)

            if !recommendation.tips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tips:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(accentColor)

                    ForEach(recommendation.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(accentColor)
                            Text(tip)
                                .font(.caption)
                        }
                    }
                }
            }

            if !recommendation.avoid.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avoid:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.red.opacity(0.7))

                    ForEach(recommendation.avoid, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(Color.red.opacity(0.7))
                            Text(item)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    var makeupAndBeautyView: some View {
        VStack(alignment: .leading, spacing: 20) {
            colorRecommendationSection(
                title: "Lip Colors",
                recommendation: viewModel.lipColors
            )

            colorRecommendationSection(
                title: "Eye Makeup",
                recommendation: viewModel.eyeColors
            )

            if let hairRecommendation = viewModel.hairColorSuggestions {
                colorRecommendationSection(
                    title: "Hair Color Suggestions",
                    recommendation: hairRecommendation
                )
            }
        }
    }

    private func getPriorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high":
            return Color.red.opacity(0.8)
        case "medium":
            return Color.orange.opacity(0.8)
        case "low":
            return Color.gray.opacity(0.8)
        default:
            return Color.orange.opacity(0.8)
        }
    }

    private struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }

    // MARK: - Helper Methods

    /// Map secondary season to accent color
    private func getDNASecondaryColor() -> Color {
        guard let secondarySeason = viewModel.seasonDNA.secondary?.season else {
            return accentColor
        }
        return getSeasonAccentColor(for: secondarySeason)
    }

    /// Map tertiary season to accent color
    private func getDNATertiaryColor() -> Color {
        guard let tertiarySeason = viewModel.seasonDNA.tertiary?.season else {
            return accentColor2
        }
        return getSeasonAccentColor(for: tertiarySeason)
    }

    /// Season-to-color mapping
    private func getSeasonAccentColor(for seasonName: String) -> Color {
        let season = seasonName.lowercased()

        // Spring seasons - warm, bright colors
        if season.contains("spring") {
            if season.contains("light") {
                return Color(red: 1.0, green: 0.8, blue: 0.4) // Light warm yellow
            } else if season.contains("clear") || season.contains("bright") {
                return Color(red: 1.0, green: 0.6, blue: 0.0) // Bright orange
            } else if season.contains("warm") {
                return Color(red: 0.9, green: 0.5, blue: 0.1) // Warm amber
            } else {
                return Color(red: 1.0, green: 0.7, blue: 0.2) // True spring yellow-orange
            }
        }

        // Summer seasons - cool, soft colors
        else if season.contains("summer") {
            if season.contains("light") {
                return Color(red: 0.7, green: 0.8, blue: 1.0) // Light cool blue
            } else if season.contains("soft") {
                return Color(red: 0.8, green: 0.7, blue: 0.9) // Soft lavender
            } else if season.contains("cool") {
                return Color(red: 0.5, green: 0.7, blue: 0.9) // Cool blue
            } else {
                return Color(red: 0.6, green: 0.8, blue: 0.9) // True summer blue
            }
        }

        // Autumn seasons - warm, rich colors
        else if season.contains("autumn") {
            if season.contains("soft") {
                return Color(red: 0.8, green: 0.6, blue: 0.4) // Soft warm brown
            } else if season.contains("warm") {
                return Color(red: 0.9, green: 0.4, blue: 0.1) // Warm rust
            } else if season.contains("dark") {
                return Color(red: 0.6, green: 0.3, blue: 0.1) // Deep burnt orange
            } else {
                return Color(red: 0.8, green: 0.5, blue: 0.2) // True autumn orange
            }
        }

        // Winter seasons - cool, clear colors
        else if season.contains("winter") {
            if season.contains("clear") || season.contains("bright") {
                return Color(red: 0.2, green: 0.4, blue: 1.0) // Clear royal blue
            } else if season.contains("cool") {
                return Color(red: 0.4, green: 0.2, blue: 0.8) // Cool purple
            } else if season.contains("dark") {
                return Color(red: 0.1, green: 0.1, blue: 0.5) // Deep navy
            } else {
                return Color(red: 0.2, green: 0.2, blue: 0.8) // True winter blue
            }
        }

        // Default fallback
        else {
            return accentColor
        }
    }

    /// Create basic ColorItems from hex strings
    private func createBasicColorItems(from hexColors: [String], isAvoidance: Bool = false) -> [ColorItem] {
        return hexColors.enumerated().map { _, hex in
            let colorName = getColorName(from: hex, isAvoidance: isAvoidance)
            let usageContext = isAvoidance ? "Avoid this color" : "Great for your season"
            let harmonyReason = isAvoidance ?
                "May clash with your natural coloring" :
                "Complements your \(viewModel.seasonName) characteristics"

            return ColorItem(
                name: colorName,
                hexValue: hex,
                usageContext: usageContext,
                harmonyReason: harmonyReason
            )
        }
    }

    /// Generate basic color names from hex values
    private func getColorName(from hex: String, isAvoidance: Bool = false) -> String {
        // Convert hex to Color for analysis
        let color = Color(hex: hex)
        let uiColor = UIColor(color)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        // Generate name based on hue, saturation, and brightness
        let hueAngle = hue * 360

        var colorName = ""

        // Determine base color from hue
        switch hueAngle {
        case 0..<30, 330..<360:
            colorName = "Red"
        case 30..<60:
            colorName = "Orange"
        case 60..<90:
            colorName = "Yellow"
        case 90..<150:
            colorName = "Green"
        case 150..<210:
            colorName = "Cyan"
        case 210..<270:
            colorName = "Blue"
        case 270..<330:
            colorName = "Purple"
        default:
            colorName = "Gray"
        }

        // Add modifiers based on saturation and brightness
        if saturation < 0.2 {
            if brightness > 0.8 {
                colorName = "Light Gray"
            } else if brightness < 0.3 {
                colorName = "Dark Gray"
            } else {
                colorName = "Gray"
            }
        } else {
            if brightness > 0.8 {
                colorName = "Light \(colorName)"
            } else if brightness < 0.3 {
                colorName = "Dark \(colorName)"
            } else if saturation < 0.5 {
                colorName = "Soft \(colorName)"
            }
        }

        return colorName
    }
}
