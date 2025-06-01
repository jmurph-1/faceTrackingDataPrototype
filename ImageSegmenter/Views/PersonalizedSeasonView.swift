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
                            personalizedColorPalette
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

            VStack(spacing: 8) {
                Text("Your Personalized")
                    .font(.system(size: 16, weight: .light, design: .serif))
                    .foregroundColor(paletteWhite)

                Text(viewModel.seasonName)
                    .font(.system(size: textSizeHeader, weight: .bold, design: .serif))
                    .foregroundColor(primaryColor)

                Text(viewModel.personalizedTagline)
                    .font(.system(size: textSizeSubheader, weight: .light, design: .serif))
                    .foregroundColor(paletteWhite)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(accentColor)
                    
                    Text("Confidence: \(viewModel.confidence)")
                        .font(.caption)
                        .foregroundColor(paletteWhite.opacity(0.8))
                    
                    Text("• \(viewModel.formattedDate)")
                        .font(.caption)
                        .foregroundColor(paletteWhite.opacity(0.6))
                }
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

    private var personalizedColorPalette: some View {
        VStack(spacing: 16) {
            Text("Your Best Colors")
                .font(.headline)
                .foregroundColor(textColor)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(Array(viewModel.emphasizedColors.enumerated()), id: \.offset) { index, color in
                    Circle()
                        .fill(color)
                        .aspectRatio(1, contentMode: .fit)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }

            if !viewModel.colorsToAvoid.isEmpty {
                Text("Colors to Avoid")
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    .padding(.top)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Array(viewModel.colorsToAvoid.enumerated()), id: \.offset) { index, color in
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.7), lineWidth: 2)
                            )
                    }
                }
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

            ForEach(Array(sortedRecommendations.enumerated()), id: \.offset) { index, recommendationPair in
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
                ForEach(Array(viewModel.getColorsForRecommendation(recommendation).enumerated()), id: \.offset) { index, color in
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
}

