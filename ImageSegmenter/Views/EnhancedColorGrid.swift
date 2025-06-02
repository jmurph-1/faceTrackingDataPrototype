//
//  EnhancedColorGrid.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import SwiftUI

struct EnhancedColorGrid: View {
    
    // MARK: - Properties
    
    let title: String
    let description: String
    let colorItems: [ColorItem]
    let isAvoidanceMode: Bool
    let columns: Int
    
    @State private var selectedColorId: UUID?
    @State private var showingDetailCard = false
    
    // Grid configuration
    private let spacing: CGFloat = 12
    private let circleSize: CGFloat = 60
    private let selectedCircleSize: CGFloat = 70
    
    init(title: String, 
         description: String, 
         colorItems: [ColorItem], 
         isAvoidanceMode: Bool = false, 
         columns: Int = 4) {
        self.title = title
        self.description = description
        self.colorItems = colorItems
        self.isAvoidanceMode = isAvoidanceMode
        self.columns = columns
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerSection
            
            // Color grid
            colorGrid
            
            // Detail card (if shown)
            if showingDetailCard, let selectedColor = selectedColor {
                ColorDetailCard(
                    colorItem: selectedColor,
                    isAvoidanceMode: isAvoidanceMode,
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingDetailCard = false
                            selectedColorId = nil
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Color count badge
                Text("\(colorItems.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isAvoidanceMode ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    )
                    .foregroundColor(isAvoidanceMode ? .red : .blue)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(colorItems) { colorItem in
                EnhancedColorCircle(
                    colorItem: colorItem,
                    isSelected: selectedColorId == colorItem.id,
                    isAvoidanceMode: isAvoidanceMode,
                    size: selectedColorId == colorItem.id ? selectedCircleSize : circleSize
                ) {
                    handleColorTap(colorItem)
                }
            }
        }
    }
    
    private var selectedColor: ColorItem? {
        return colorItems.first { $0.id == selectedColorId }
    }
    
    // MARK: - Actions
    
    private func handleColorTap(_ colorItem: ColorItem) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if selectedColorId == colorItem.id && showingDetailCard {
                // Tapping the same color while detail is shown - dismiss
                showingDetailCard = false
                selectedColorId = nil
            } else {
                // Select new color and show detail card
                selectedColorId = colorItem.id
                showingDetailCard = true
            }
        }
    }
}

// MARK: - EnhancedColorCircle

struct EnhancedColorCircle: View {
    
    let colorItem: ColorItem
    let isSelected: Bool
    let isAvoidanceMode: Bool
    let size: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    // Color circle
                    Circle()
                        .fill(Color(hex: colorItem.hexValue))
                        .frame(width: size, height: size)
                        .shadow(
                            color: Color(hex: colorItem.hexValue).opacity(0.3),
                            radius: isSelected ? 4 : 2,
                            x: 0,
                            y: isSelected ? 3 : 1
                        )
                    
                    // White border for selection
                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: size, height: size)
                    }
                    
                    // Red X overlay for avoidance colors
                    if isAvoidanceMode {
                        Image(systemName: "xmark")
                            .font(.system(size: size * 0.3, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                    
                    // Selection border
                    if isSelected {
                        Circle()
                            .stroke(isAvoidanceMode ? Color.red : Color.blue, lineWidth: 2)
                            .frame(width: size + 4, height: size + 4)
                    }
                }
                
                // Color name
                Text(colorItem.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: size + 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(SpringButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - ColorDetailCard

struct ColorDetailCard: View {
    
    let colorItem: ColorItem
    let isAvoidanceMode: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row
            headerRow
            
            // Season source info (if available from database)
            if let colorData = ColorDatabaseManager.shared.getColorData(for: colorItem.hexValue) {
                seasonSourceInfo(colorData)
            }
            
            // Usage context section
            usageContextSection
            
            // Harmony reason section
            harmonyReasonSection
            
            // Action buttons
            actionButtons
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isAvoidanceMode ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var headerRow: some View {
        HStack {
            // Color circle
            Circle()
                .fill(Color(hex: colorItem.hexValue))
                .frame(width: 50, height: 50)
                .shadow(color: Color(hex: colorItem.hexValue).opacity(0.3), radius: 5, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                // Color name
                Text(colorItem.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Hex value
                HStack {
                    Text(colorItem.hexValue.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemBackground))
                        )
                    
                    // Copy button
                    Button(action: copyHexValue) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func seasonSourceInfo(_ colorData: ColorData) -> some View {
        HStack {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(.blue)
            
            Text("From \(colorData.season) • \(colorData.category)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    @ViewBuilder
    private var usageContextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Text("Usage Context")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Text(colorItem.usageContext)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 20)
        }
    }
    
    @ViewBuilder
    private var harmonyReasonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart")
                    .font(.caption)
                    .foregroundColor(.pink)
                
                Text("Why It Works")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Text(colorItem.harmonyReason)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 20)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: saveToFavorites) {
                HStack {
                    Image(systemName: "heart")
                    Text("Save to Favorites")
                }
                .font(.caption)
                .foregroundColor(.pink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.pink.opacity(0.1))
                )
            }
            
            Button(action: openOutfitIdeas) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Outfit Ideas")
                }
                .font(.caption)
                .foregroundColor(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func copyHexValue() {
        UIPasteboard.general.string = colorItem.hexValue
        // Could add a toast notification here
    }
    
    private func saveToFavorites() {
        // Implement favorites functionality
        print("Saving \(colorItem.name) to favorites")
    }
    
    private func openOutfitIdeas() {
        // Implement outfit ideas functionality
        print("Opening outfit ideas for \(colorItem.name)")
    }
}

// MARK: - SpringButtonStyle

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct EnhancedColorGrid_Previews: PreviewProvider {
    static let sampleColors = [
        ColorItem(name: "Warm Taupe", hexValue: "#B8860B", usageContext: "Perfect foundation color", harmonyReason: "Complements warm undertones"),
        ColorItem(name: "Coral Blush", hexValue: "#FF7F7F", usageContext: "Beautiful accent color", harmonyReason: "Enhances natural warmth"),
        ColorItem(name: "Forest Green", hexValue: "#228B22", usageContext: "Rich wardrobe staple", harmonyReason: "Grounds your palette"),
        ColorItem(name: "Dusty Rose", hexValue: "#D2B4DE", usageContext: "Romantic touch", harmonyReason: "Soft and feminine")
    ]
    
    static let avoidColors = [
        ColorItem(name: "Neon Pink", hexValue: "#FF69B4", usageContext: "Too bright", harmonyReason: "Clashes with undertones"),
        ColorItem(name: "Electric Blue", hexValue: "#00FFFF", usageContext: "Overpowering", harmonyReason: "Too cool-toned")
    ]
    
    static var previews: some View {
        ScrollView {
            VStack(spacing: 32) {
                EnhancedColorGrid(
                    title: "Your Best Colors",
                    description: "These colors enhance your natural beauty and work perfectly with your Season DNA.",
                    colorItems: sampleColors
                )
                
                EnhancedColorGrid(
                    title: "Colors to Avoid",
                    description: "These colors may wash you out or clash with your undertones.",
                    colorItems: avoidColors,
                    isAvoidanceMode: true,
                    columns: 3
                )
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
} 