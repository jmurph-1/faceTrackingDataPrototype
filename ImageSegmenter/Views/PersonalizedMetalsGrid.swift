//
//  PersonalizedMetalsGrid.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import SwiftUI

struct PersonalizedMetalsGrid: View {
    let metals: [MetalRecommendation]
    let primaryColor: Color
    let columns: Int

    @State private var selectedMetalId: UUID?
    @State private var showingDetailCard = false

    init(metals: [MetalRecommendation], primaryColor: Color, columns: Int = 3) {
        self.metals = metals
        self.primaryColor = primaryColor
        self.columns = columns
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }

    private var selectedMetal: MetalRecommendation? {
        return metals.first { $0.id == selectedMetalId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
//                Image(systemName: "sparkles")
//                    .font(.system(size: 20, weight: .semibold))
//                    .foregroundColor(primaryColor)
//                
                Text("Metals")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                // Count badge
                Text("\(metals.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(primaryColor)
                    .cornerRadius(10)
            }

//            // Subtitle
//            Text("Metallic finishes that enhance your natural coloring")
//                .font(.system(size: 14))
//                .foregroundColor(.secondary)
//                .fixedSize(horizontal: false, vertical: true)
//            
            // Priority legend
//            HStack(spacing: 16) {
//                HStack(spacing: 4) {
//                    Image(systemName: "star.fill")
//                        .font(.system(size: 10))
//                        .foregroundColor(primaryColor)
//                    Text("Best Choice")
//                        .font(.system(size: 11, weight: .medium))
//                        .foregroundColor(.primary)
//                }
//                
//                HStack(spacing: 4) {
//                    Circle()
//                        .fill(Color.secondary.opacity(0.6))
//                        .frame(width: 8, height: 8)
//                    Text("Good Option")
//                        .font(.system(size: 11, weight: .medium))
//                        .foregroundColor(.secondary)
//                }
//                
//                Spacer()
//            }

            // Metals grid organized by priority
            VStack(spacing: 16) {
                let greatMetals = metals.filter { $0.priority == .great }
                let goodMetals = metals.filter { $0.priority == .good }

                // Best metals section
                if !greatMetals.isEmpty {
                    VStack(spacing: 12) {
                        if !goodMetals.isEmpty {
                            // Only show section header if there are also good metals
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(primaryColor)
                                Text("Best Choices")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }

                        // Best metals grid with inline detail card
                        MetalsGridWithDetailCard(
                            metals: greatMetals,
                            gridColumns: gridColumns,
                            primaryColor: primaryColor,
                            selectedMetalId: selectedMetalId,
                            showingDetailCard: showingDetailCard,
                            selectedMetal: selectedMetal,
                            onMetalTap: handleMetalTap,
                            onDismiss: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                    showingDetailCard = false
                                    selectedMetalId = nil
                                }
                            }
                        )
                    }
                }

                // Good metals section
                if !goodMetals.isEmpty {
                    VStack(spacing: 12) {
                        if !greatMetals.isEmpty {
                            // Add divider between sections
                            Divider()
                                .padding(.horizontal, 20)

                            HStack {
                                Circle()
                                    .fill(Color.secondary.opacity(0.6))
                                    .frame(width: 12, height: 12)
                                Text("Good Options")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }

                        // Good metals grid with inline detail card
                        MetalsGridWithDetailCard(
                            metals: goodMetals,
                            gridColumns: gridColumns,
                            primaryColor: primaryColor,
                            selectedMetalId: selectedMetalId,
                            showingDetailCard: showingDetailCard,
                            selectedMetal: selectedMetal,
                            onMetalTap: handleMetalTap,
                            onDismiss: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                    showingDetailCard = false
                                    selectedMetalId = nil
                                }
                            }
                        )
                    }
                }

            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Actions

    private func handleMetalTap(_ metal: MetalRecommendation) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            if selectedMetalId == metal.id && showingDetailCard {
                // Tapping the same metal while detail is shown - dismiss
                showingDetailCard = false
                selectedMetalId = nil
            } else {
                // Select new metal and show detail card
                selectedMetalId = metal.id
                showingDetailCard = true
            }
        }
    }
}

// MARK: - Metal Card Component

struct MetalCard: View {
    let metal: MetalRecommendation
    let primaryColor: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Metal display
                ZStack {
                    let metalSize: CGFloat = isSelected ? 65 : 60
                    let borderSize: CGFloat = metalSize + 8

                    MetallicColorDisplay(metal: metal, size: metalSize)
                        .overlay(
                            // Temperature indicator
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Circle()
                                        .fill(temperatureColor)
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 1)
                                        )
                                }
                            }
                        )

                    // Selection border - dynamically sized and always present for smooth animation
                    Circle()
                        .stroke(primaryColor, lineWidth: 3)
                        .frame(width: borderSize, height: borderSize)
                        .opacity(isSelected ? 1.0 : 0.0)
                }

                // Metal info
                VStack(spacing: 2) {
                    Text(metal.name.capitalized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Priority badge area - always takes same space for alignment
                    Group {
                        if metal.priority == .great {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                Text("Best")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(primaryColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(primaryColor.opacity(0.15))
                            .cornerRadius(4)
                        } else {
                            // Invisible placeholder to maintain consistent height
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                Text("Best")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(.clear)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        }
                    }
                    .frame(height: 18) // Fixed height for consistent alignment
                }
                .multilineTextAlignment(.center)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: isSelected)
        }
        .buttonStyle(SpringButtonStyle())
    }

    private var temperatureColor: Color {
        switch metal.temperatureCategory {
        case .warm:
            return Color.orange
        case .cool:
            return Color.blue
        case .neutral:
            return Color.gray
        }
    }
}

// MARK: - Metals Grid with Detail Card

struct MetalsGridWithDetailCard: View {
    let metals: [MetalRecommendation]
    let gridColumns: [GridItem]
    let primaryColor: Color
    let selectedMetalId: UUID?
    let showingDetailCard: Bool
    let selectedMetal: MetalRecommendation?
    let onMetalTap: (MetalRecommendation) -> Void
    let onDismiss: () -> Void

    private var selectedMetalIndex: Int? {
        guard let selectedMetalId = selectedMetalId else { return nil }
        return metals.firstIndex { $0.id == selectedMetalId }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Calculate how many items per row based on grid columns
            let itemsPerRow = gridColumns.count
            let totalRows = (metals.count + itemsPerRow - 1) / itemsPerRow

            ForEach(0..<totalRows, id: \.self) { rowIndex in
                let startIndex = rowIndex * itemsPerRow
                let endIndex = min(startIndex + itemsPerRow, metals.count)
                let rowMetals = Array(metals[startIndex..<endIndex])

                VStack(spacing: 16) {
                    // Metal cards row
                    HStack(spacing: 20) {
                        ForEach(rowMetals) { metal in
                            MetalCard(
                                metal: metal,
                                primaryColor: primaryColor,
                                isSelected: selectedMetalId == metal.id
                            ) {
                                onMetalTap(metal)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Add spacers for incomplete rows
                        if rowMetals.count < itemsPerRow {
                            ForEach(0..<(itemsPerRow - rowMetals.count), id: \.self) { _ in
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    // Show detail card if selected metal is in this row and belongs to this metals array
                    if showingDetailCard,
                       let selectedMetal = selectedMetal,
                       let selectedIndex = selectedMetalIndex,
                       selectedIndex >= startIndex && selectedIndex < endIndex,
                       metals.contains(where: { $0.id == selectedMetal.id }) {
                        MetalDetailCard(
                            metal: selectedMetal,
                            primaryColor: primaryColor,
                            onDismiss: onDismiss
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
            }
        }
    }
}

// MARK: - Metal Detail Card

struct MetalDetailCard: View {
    let metal: MetalRecommendation
    let primaryColor: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row
            headerRow

            // Available finishes
            finishesSection

            // Usage suggestions
            usageSection
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(primaryColor.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack {
            // Metal display
            MetallicColorDisplay(metal: metal, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                // Metal name
                Text(metal.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Season sources
                Text(metal.seasonSources.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }

            Spacer()

            // Priority badge
            if metal.priority == .great {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("Best")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(primaryColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(primaryColor.opacity(0.15))
                .cornerRadius(6)
            }

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var finishesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Finishes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                ForEach(metal.availableFinishes.sorted {
                    // Sort by priority: great first, then good
                    if $0.priority == $1.priority {
                        return $0.displayName < $1.displayName
                    }
                    return $0.priority == .great
                }) { finish in
                    VStack(spacing: 4) {
                        Text(finish.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)

                        if finish.priority == .great {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(primaryColor)
                        } else {
                            Circle()
                                .fill(Color.secondary.opacity(0.6))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(finish.priority == .great ? primaryColor.opacity(0.1) : Color(.tertiarySystemBackground))
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Suggestions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            ForEach(metal.usageSuggestions, id: \.self) { suggestion in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(suggestion)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Preview

struct PersonalizedMetalsGrid_Previews: PreviewProvider {
    static var previews: some View {
        let sampleMetals = [
            MetalRecommendation(
                name: "Gold",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Bright", priority: .great, seasonSource: "True Spring"),
                    MetalRecommendation.FinishOption(name: "Brushed", priority: .good, seasonSource: "True Spring")
                ],
                priority: .great,
                seasonSources: ["True Spring"]
            ),
            MetalRecommendation(
                name: "Silver",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Brushed", priority: .good, seasonSource: "True Summer"),
                    MetalRecommendation.FinishOption(name: "Polished", priority: .good, seasonSource: "True Summer")
                ],
                priority: .good,
                seasonSources: ["True Summer"]
            ),
            MetalRecommendation(
                name: "Copper",
                availableFinishes: [
                    MetalRecommendation.FinishOption(name: "Antique", priority: .great, seasonSource: "True Autumn")
                ],
                priority: .great,
                seasonSources: ["True Autumn"]
            )
        ]

        PersonalizedMetalsGrid(
            metals: sampleMetals,
            primaryColor: Color.blue,
            columns: 3
        )
        .padding()
        .background(Color(.systemGroupedBackground))
        .preferredColorScheme(.light)
    }
}
