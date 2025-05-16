//
//  DefaultSeasonView.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/15/25.
//

import SwiftUI

struct DefaultSeasonView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: SeasonViewModel
    @State private var selectedModule: String? = nil
    
    // Customizable colors for UI elements
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
    
    init(seasonName: String,
         primaryColor: Color,
         paletteWhite: Color,
         accentColor: Color,
         accentColor2: Color,
         backgroundColor: Color,
         secondaryBackgroundColor: Color,
         textColor: Color,
         moduleColor: Color) {
        self._viewModel = StateObject(wrappedValue: SeasonViewModel(seasonName: seasonName))
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
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea() // Full screen background color
                
                VStack(spacing: 0) { // Main content stack
                    headerViewContent()
                        .padding(.top)
                        .frame(maxWidth: .infinity) // Ensure background takes full width
                        .background(
                            secondaryBackgroundColor // This is the color for the header area
                                .shadow(color: primaryColor.opacity(0.1), radius: 10, x: 0, y: 5) // Apply shadow here
                                .ignoresSafeArea(.container, edges: .top) // Make this background extend up
                        )

                    ScrollView {
                        if selectedModule == nil {
                            seasonPalletView
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
    }
    
    private func headerViewContent() -> some View {
        ZStack(alignment: .topLeading) {
            // Back button in top left
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(paletteWhite)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(primaryColor.opacity(0.6))
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    )
            }
            .padding(.leading, 10)
            .padding(.top, 0)
            .zIndex(1)
            
            // Existing header content
            VStack(spacing: 16) {
                Text(viewModel.seasonName)
                    .font(.system(size: textSizeHeader, weight: .bold, design: .serif))
                    .foregroundColor(primaryColor)
                
                if let season = viewModel.season {
                    Text(season.tagline)
                        .font(.system(size: textSizeSubheader, design: .serif))
                        .foregroundColor(paletteWhite)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal) // Padding for tagline within its own bounds
                        .padding(.top, 10)   // Specific top padding for tagline
                }
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                secondaryBackgroundColor,
                                secondaryBackgroundColor.opacity(0.7),
                                secondaryBackgroundColor
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 8)
                    .overlay(
                        HStack(spacing: 12) {
                            ForEach(0..<8) { _ in
                                Circle()
                                    .fill(accentColor.opacity(0.3))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    )
            }
            .padding(.horizontal) // Only horizontal padding for the content block itself
        }
    }
    
    private var seasonPalletView: some View {
        VStack(alignment: .leading){
            let categories = viewModel.colorsByCategory()
            ForEach(Array(categories.keys.sorted()), id: \.self) { category in
                categoryColorSection(category: category, colors: categories[category] ?? [])
            }
        }
    }
    
    private var modulesGridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            moduleCard("Season Overview", icon: "sun.haze", color: primaryColor)
            moduleCard("Characteristics", icon: "person.fill", color: primaryColor)
            moduleCard("Palette Breakdown", icon: "paintpalette.fill", color: primaryColor)
            moduleCard("Sister Palettes", icon: "square.on.square", color: primaryColor)
            moduleCard("Styling Guide", icon: "tshirt.fill", color: primaryColor)
            moduleCard("Colors to Avoid", icon: "xmark.circle.fill", color: primaryColor)
        }
    }
    
    private func moduleCard(_ title: String, icon: String, color: Color) -> some View {
        Button(action: {
            withAnimation {
                selectedModule = title
            }
        }) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(paletteWhite)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(width: 160, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(moduleColor).opacity(0.99)
                    .shadow(color: color.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.99), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
            case "Season Overview":
                seasonOverviewView
            case "Characteristics":
                characteristicsView
            case "Palette Breakdown":
                paletteBreakdownView
            case "Sister Palettes":
                sisterPalettesView
            case "Styling Guide":
                stylingGuideView
            case "Colors to Avoid":
                colorsToAvoidView
            default:
                EmptyView()
            }
        }
    }
    
    private var seasonOverviewView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let season = viewModel.season {
                
                Text(season.characteristics.overview)
                    .font(.body)
                
                VStack(spacing: 16) {
                    Text("\(viewModel.seasonName) Mood")
                        .font(.headline)
                        .foregroundColor(textColor)
                    
                    HStack(spacing: 12) {
                        moodImage("Landscape", color: primaryColor)
                        moodImage("Floral", color: accentColor2)
                    }
                    
                    HStack(spacing: 12) {
                        moodImage("Texture", color: accentColor)
                        moodImage("Nature", color: primaryColor)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(paletteWhite)
                        .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
                )
            }
        }
    }
    
    private func moodImage(_ title: String, color: Color) -> some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.99))
                .frame(height: 80)
                .overlay(
                    Text(title)
                        .font(.caption)
                        .foregroundColor(textColor)
                )
        }
    }
    
    private var characteristicsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let season = viewModel.season {
                Text(season.characteristics.note)
                    .font(.caption)
                    .italic()
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor)
                            .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                
                characteristicSection(
                    title: "Eyes",
                    description: season.characteristics.features.eyes.description,
                    color: textColor
                )
                
                characteristicSection(
                    title: "Skin",
                    description: season.characteristics.features.skin.description,
                    color: textColor
                )
                
                characteristicSection(
                    title: "Hair",
                    description: season.characteristics.features.hair.description,
                    color: textColor
                )
                
                characteristicSection(
                    title: "Contrast",
                    description: season.characteristics.features.contrast.description,
                    color: textColor.opacity(0.8)
                )
            }
        }
    }
    
    private func characteristicSection(title: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            Text(description)
                .font(.body)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: title == "Eyes" ? "eye.fill" :
                                title == "Skin" ? "hand.raised.fill" :
                                title == "Hair" ? "person.fill" : "circle.grid.cross.fill")
                            .font(.system(size: 24))
                            .foregroundColor(color)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Typical Colors")
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))
                    
                    HStack(spacing: 8) {
                        let categoryFilter = title == "Eyes" ? "Base Colors" :
                                            title == "Skin" ? "Neutrals" :
                                            title == "Hair" ? "Neutrals" : "Base Colors"
                        
                        let colors = viewModel.colors.filter { $0.category == categoryFilter }.prefix(5)
                        
                        ForEach(Array(colors.enumerated()), id: \.element.id) { _, color in
                            Circle()
                                .fill(color.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .shadow(color: color.opacity(0.1), radius: 5, x: 0, y: 2)
            )
        }
        .padding(.bottom, 8)
    }
    
    private var paletteBreakdownView: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            if let season = viewModel.season {
                Text(season.palette.description)
                    .font(.body)
                
                paletteAspectSection(
                    title: "Hue: \(season.palette.hue.value)",
                    description: season.palette.hue.explanation,
                    color: textColor
                )
                
                paletteAspectSection(
                    title: "Value: \(season.palette.value.value)",
                    description: season.palette.value.explanation,
                    color: textColor
                )
                
                paletteAspectSection(
                    title: "Chroma: \(season.palette.chroma.value)",
                    description: season.palette.chroma.explanation,
                    color: textColor
                )
            }
            
            VStack(alignment: .leading, spacing: 20) {
                let categories = viewModel.colorsByCategory()
                
                ForEach(Array(categories.keys.sorted()), id: \.self) { category in
                    Text(category)
                        .font(.headline)
                        .foregroundColor(textColor)
                    
                    colorGalleryGrid(colors: categories[category] ?? [])
                }
            }
        }
    }
    
    private func paletteAspectSection(title: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            Text(description)
                .font(.body)
            
            if title.contains("Hue") {
                let hueColors = getHueColors()
                colorGradient(colors: hueColors)
            } else if title.contains("Value") {
                let valueColors = getValueColors()
                colorGradient(colors: valueColors)
            } else if title.contains("Chroma") {
                let chromaColors = getChromaColors()
                colorGradient(colors: chromaColors)
            }
        }
        .padding(.bottom, 8)
    }
    
    private func getHueColors() -> [Color] {
        if let season = viewModel.season {
            if season.palette.hue.value.lowercased().contains("warm") {
                return [Color(hex: "#f5b31e"), Color(hex: "#d18f55")]  // Warm
            } else if season.palette.hue.value.lowercased().contains("neutral-warm") {
                return [Color(hex: "#c3b181"), Color(hex: "#a9b99f")]  // Neutral-warm
            } else if season.palette.hue.value.lowercased().contains("neutral-cool") {
                return [Color(hex: "#8c91ab"), Color(hex: "#a9b99f")]  // Neutral-cool
            } else {
                return [Color(hex: "#4682b4"), Color(hex: "#8c91ab")]  // Cool
            }
        }
        return [Color.gray, Color.gray.opacity(0.5)]
    }
    
    private func getValueColors() -> [Color] {
        if let season = viewModel.season {
            if season.palette.value.value.lowercased().contains("light") {
                return [Color(hex: "#f0eadc"), Color(hex: "#c8bba6")]  // Light
            } else if season.palette.value.value.lowercased().contains("medium") {
                return [Color(hex: "#c8bba6"), Color(hex: "#8c91ab"), Color(hex: "#4f525d")]  // Medium
            } else {
                return [Color(hex: "#8c91ab"), Color(hex: "#4f525d"), Color(hex: "#262f30")]  // Dark
            }
        }
        return [Color.white, Color.gray, Color.black]
    }
    
    private func getChromaColors() -> [Color] {
        if let season = viewModel.season {
            if season.palette.chroma.value.lowercased().contains("high") {
                return [Color(hex: "#ff66cc"), Color(hex: "#ff66cc").opacity(0.7)]  // High chroma
            } else if season.palette.chroma.value.lowercased().contains("medium") {
                return [Color(hex: "#c8a2c8").opacity(0.7), Color(hex: "#c8a2c8")]  // Medium chroma
            } else {
                return [Color(hex: "#c8a2c8").opacity(0.3), Color(hex: "#c8a2c8").opacity(0.6)]  // Low/muted chroma
            }
        }
        return [Color.gray.opacity(0.3), Color.gray]
    }
    
    private func colorGradient(colors: [Color]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<colors.count, id: \.self) { index in
                colors[index]
            }
        }
        .frame(height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
    
    private func categoryColorSection(category: String, colors: [ColorData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.subheadline)
                .foregroundColor(textColor)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(colors.prefix(10)) { color in
                    colorSwatch(color)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.bottom, 8)
    }
    
    private func colorSwatch(_ color: ColorData) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color.color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
            
            Text(color.name)
                .font(.system(size: 8))
                .lineLimit(1)
                .foregroundColor(textColor)
        }
    }
    
    private var sisterPalettesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let season = viewModel.season {
                Text(season.palette.sisterPalettes.description)
                    .font(.body)
                
                VStack(spacing: 0) {
                    comparisonTableRow("Season", "Hue", "Value", "Chroma", isHeader: true)
                    comparisonTableRow(viewModel.seasonName, season.palette.hue.value, season.palette.value.value, season.palette.chroma.value)
                    let sisters = season.palette.sisterPalettes.sisters
                    if !sisters.isEmpty {
                        ForEach(sisters, id: \.self) { sisterName in
                            comparisonTableRow(sisterName, "Varies", "Varies", "Varies")
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(paletteWhite)
                        .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                
                Text("Seasonal Flow")
                    .font(.headline)
                    .foregroundColor(textColor)
                    .padding(.top)
                let sisters = season.palette.sisterPalettes.sisters
                if sisters.count >= 2 {
                    HStack(spacing: 0) {
                        seasonFlowBox(sisters[0], color: accentColor2)
                        Image(systemName: "arrow.right")
                            .foregroundColor(textColor)
                            .padding(.horizontal, 8)
                        seasonFlowBox(viewModel.seasonName, color: primaryColor)
                        Image(systemName: "arrow.right")
                            .foregroundColor(textColor)
                            .padding(.horizontal, 8)
                        seasonFlowBox(sisters[1], color: accentColor)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(paletteWhite)
                            .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                }
            }
        }
    }
    
    private func comparisonTableRow(_ col1: String, _ col2: String, _ col3: String, _ col4: String, isHeader: Bool = false) -> some View {
        HStack {
            Text(col1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(isHeader ? .headline : .body)
            Text(col2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(isHeader ? .headline : .body)
            Text(col3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(isHeader ? .headline : .body)
            Text(col4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(isHeader ? .headline : .body)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHeader ? primaryColor.opacity(0.1) : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(primaryColor.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    private func seasonFlowBox(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption)
            .padding(8)
            .background(color.opacity(0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.99), lineWidth: 1)
            )
    }
    
    private var stylingGuideView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let season = viewModel.season {
                stylingSection(
                    title: "Neutrals",
                    description: season.styling.neutrals.description,
                    color: textColor
                )
                
                Text("Color Combinations")
                    .font(.headline)
                    .foregroundColor(textColor)
                
                let baseColors = viewModel.colors.filter { $0.category == "Base Colors" }
                let accentColors = viewModel.colors.filter { $0.category == "Accent Colors" }
                let neutralColors = viewModel.colors.filter { $0.category == "Neutrals" }
                
                if let color1 = baseColors.first?.color, let color2 = baseColors.dropFirst().first?.color {
                    colorCombinationExample(
                        title: "Monochromatic",
                        colors: [color1, color2]
                    )
                }
                
                if let color1 = baseColors.first?.color, let color2 = accentColors.first?.color {
                    colorCombinationExample(
                        title: "Neighboring Hues",
                        colors: [color1, color2]
                    )
                }
                
                if let color1 = neutralColors.first?.color, let color2 = accentColors.first?.color {
                    colorCombinationExample(
                        title: "Neutral with Accent",
                        colors: [color1, color2]
                    )
                }
                
                Text("Patterns & Prints")
                    .font(.headline)
                    .foregroundColor(textColor)
                    .padding(.top)
                
                patternExample(
                    title: "Great: \(viewModel.seasonName) Pattern",
                    description: "Appropriate pattern for this season",
                    color: accentColor
                )
                
                patternExample(
                    title: "Good: Low Contrast Pattern",
                    description: "Seasonal colors with minimal contrast",
                    color: accentColor2
                )
                
                patternExample(
                    title: "Avoid: High Contrast Pattern",
                    description: "Too bold for this season",
                    color: Color(hex: "#bc4a4e").opacity(0.7)
                )
                
                Text("Metals & Accessories")
                    .font(.headline)
                    .foregroundColor(textColor)
                    .padding(.top)
                
                HStack(spacing: 16) {
                    metalExample(name: "Silver", isGood: true)
                    metalExample(name: "Rose Gold", isGood: true)
                    metalExample(name: "Brushed", isGood: true)
                    metalExample(name: "Shiny", isGood: false)
                }
            }
        }
    }
    
    private func stylingSection(title: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            Text(description)
                .font(.body)
        }
        .padding(.bottom, 8)
    }
    
    private func colorCombinationExample(title: String, colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(textColor)
            
            HStack(spacing: 12) {
                ForEach(0..<colors.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colors[index])
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
            }
            
            HStack {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 24))
                    .foregroundColor(colors[0])
                
                Image(systemName: "bag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(colors[1])
                
                Spacer()
                
                Text("Example outfit")
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.bottom, 8)
    }
    
    private func patternExample(title: String, description: String, color: Color) -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(
                    ZStack {
                        if title.contains("Great") {
                            ForEach(0..<10) { i in
                                Circle()
                                    .fill(color.opacity(Double.random(in: 0.1...0.3)))
                                    .frame(width: Double.random(in: 10...30))
                                    .offset(
                                        x: Double.random(in: -30...30),
                                        y: Double.random(in: -30...30)
                                    )
                            }
                        } else if title.contains("Good") {
                            ForEach(0..<5) { i in
                                Circle()
                                    .fill(color.opacity(0.4))
                                    .frame(width: 12)
                                    .offset(
                                        x: Double(i % 3) * 20 - 20,
                                        y: Double(i / 3) * 20 - 20
                                    )
                            }
                        } else {
                            VStack(spacing: 4) {
                                ForEach(0..<3) { row in
                                    HStack(spacing: 4) {
                                        ForEach(0..<3) { col in
                                            Rectangle()
                                                .fill((row + col) % 2 == 0 ? color : Color.white)
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                }
                            }
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(title.contains("Avoid") ? color : textColor)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.bottom, 8)
    }
    
    private func metalExample(name: String, isGood: Bool) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(
                    getMetalGradient(name: name, isGood: isGood)
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
            
            Text(name)
                .font(.caption)
                .foregroundColor(textColor)
            
            Image(systemName: isGood ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGood ? accentColor : Color(hex: "#bc4a4e").opacity(0.7))
        }
    }
    
    private func getMetalGradient(name: String, isGood: Bool) -> LinearGradient {
        switch name.lowercased() {
        case "silver":
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.9),
                    Color(hex: "#C0C0C0"),
                    Color(hex: "#A8A8A8"),
                    Color(hex: "#C0C0C0"),
                    Color.white.opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "gold":
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#FFD700").opacity(0.9),
                    Color(hex: "#FDB931"),
                    Color(hex: "#D4AF37"),
                    Color(hex: "#FDB931"),
                    Color(hex: "#FFD700").opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "rose gold":
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#F7CDCD").opacity(0.9),
                    Color(hex: "#E8A9A9"),
                    Color(hex: "#B76E79"),
                    Color(hex: "#E8A9A9"),
                    Color(hex: "#F7CDCD").opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "brushed":
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#D8D8D8"),
                    Color(hex: "#B0B0B0"),
                    Color(hex: "#C8C8C8"),
                    Color(hex: "#A8A8A8"),
                    Color(hex: "#D0D0D0")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "shiny":
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.95),
                    Color(hex: "#EFEFEF"),
                    Color(hex: "#D0D0D0"),
                    Color(hex: "#EFEFEF"),
                    Color.white.opacity(0.95)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                gradient: Gradient(colors: [Color.gray.opacity(0.8), Color.gray]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var colorsToAvoidView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let season = viewModel.season {
                Text(season.styling.colorsToAvoid.description)
                    .font(.body)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    if let colorsToAvoid = season.styling.colorsToAvoid.colors {
                        ForEach(colorsToAvoid, id: \.self) { colorName in
                            colorToAvoidCard(colorName)
                        }
                    }
                }
                
                Text("Comparison Examples")
                    .font(.headline)
                    .foregroundColor(textColor)
                    .padding(.top)
                
                if let goodColor = viewModel.colors.first?.color {
                    comparisonExample(
                        title: "\(viewModel.seasonName) Blue vs. Intense Blue",
                        goodColor: goodColor,
                        badColor: Color(hex: "#0180ff")
                    )
                    
                    comparisonExample(
                        title: "\(viewModel.seasonName) Pink vs. Orangey Red",
                        goodColor: accentColor2,
                        badColor: Color(hex: "#ff6449")
                    )
                    
                    comparisonExample(
                        title: "\(viewModel.seasonName) Neutral vs. Black",
                        goodColor: Color(hex: "#4f525d"),
                        badColor: Color.black
                    )
                }
            }
        }
    }
    
    private func colorToAvoidCard(_ colorName: String) -> some View {
        VStack(spacing: 16) {
            Circle()
                .fill(getColorToAvoid(colorName))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
            
            VStack(alignment: .center, spacing: 4) {
                Text(colorName)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    
                
                Text("Avoid this color")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#bc4a4e").opacity(0.7))
            }
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(Color(hex: "#bc4a4e").opacity(0.7))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: primaryColor.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.bottom, 8)
    }
    
    private func getColorToAvoid(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case let name where name.contains("intense pink"):
            return Color(hex: "#ff66cc")
        case let name where name.contains("intense blue"):
            return Color(hex: "#0180ff")
        case let name where name.contains("orange"):
            return Color(hex: "#ff6449")
        case let name where name.contains("earth"):
            return Color(hex: "#865e44")
        case "white":
            return Color.white
        case "black":
            return Color.black
        default:
            return Color.gray
        }
    }
    
    private func comparisonExample(title: String, goodColor: Color, badColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(textColor)
            
            HStack {
                VStack {
                    Circle()
                        .fill(goodColor)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                    
                    Text("Flattering")
                        .font(.caption)
                        .foregroundColor(accentColor)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundColor)
                
                VStack {
                    Circle()
                        .fill(badColor)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                    
                    Text("Unflattering")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#bc4a4e").opacity(0.7))
                    
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "#bc4a4e").opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundColor.opacity(0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(primaryColor.opacity(0.2), lineWidth: 1)
            )
            
            Text("The unflattering color will make your complexion appear dull or yellowish and emphasize imperfections.")
                .font(.caption)
                .foregroundColor(textColor.opacity(0.7))
                .padding(.horizontal, 4)
        }
        .padding(.bottom, 8)
    }
    
    private func colorGalleryGrid(colors: [ColorData]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            ForEach(colors) { color in
                colorGalleryItem(color)
            }
        }
        .padding(.bottom, 16)
    }
    
    private func colorGalleryItem(_ color: ColorData) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.color)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 1)
                )
            
            Text(color.name)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(textColor)
            
            Text(color.hexValue)
                .font(.system(size: 10))
                .foregroundColor(textColor.opacity(0.7))
        }
    }
}

