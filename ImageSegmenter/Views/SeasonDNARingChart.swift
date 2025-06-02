//
//  SeasonDNARingChart.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import SwiftUI

struct SeasonDNARingChart: View {
    
    // MARK: - Properties
    
    let seasonDNA: SeasonDNA
    let primaryColor: Color
    let secondaryColor: Color?
    let tertiaryColor: Color?
    let size: CGFloat
    
    @State private var animationProgress: Double = 0
    
    // Ring configuration
    private let ringWidth: CGFloat
    private let backgroundRingOpacity: Double = 0.1
    
    init(seasonDNA: SeasonDNA, 
         primaryColor: Color, 
         secondaryColor: Color? = nil, 
         tertiaryColor: Color? = nil, 
         size: CGFloat = 200) {
        self.seasonDNA = seasonDNA
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.tertiaryColor = tertiaryColor
        self.size = size
        self.ringWidth = size * 0.15 // Ring width is 15% of total size
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(backgroundRingOpacity), lineWidth: ringWidth)
                .frame(width: size, height: size)
            
            // Primary season arc
            Circle()
                .trim(from: 0, to: CGFloat(seasonDNA.primary.weight) * animationProgress)
                .stroke(
                    primaryColor.opacity(0.8),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90)) // Start from top
            
            // Secondary season arc (if exists)
            if let secondary = seasonDNA.secondary,
               let secondaryColor = secondaryColor {
                Circle()
                    .trim(
                        from: CGFloat(seasonDNA.primary.weight),
                        to: CGFloat(seasonDNA.primary.weight + secondary.weight) * animationProgress
                    )
                    .stroke(
                        secondaryColor.opacity(0.7),
                        style: StrokeStyle(lineWidth: ringWidth * 0.8, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
            }
            
            // Tertiary season arc (if exists)
            if let tertiary = seasonDNA.tertiary,
               let tertiaryColor = tertiaryColor {
                Circle()
                    .trim(
                        from: CGFloat(seasonDNA.primary.weight + (seasonDNA.secondary?.weight ?? 0)),
                        to: CGFloat(seasonDNA.primary.weight + (seasonDNA.secondary?.weight ?? 0) + tertiary.weight) * animationProgress
                    )
                    .stroke(
                        tertiaryColor.opacity(0.6),
                        style: StrokeStyle(lineWidth: ringWidth * 0.6, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
            }
            
            // Center content
            centerContent
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
                animationProgress = 1.0
            }
        }
    }
    
    @ViewBuilder
    private var centerContent: some View {
        VStack(spacing: 8) {
            // Primary season name
            Text(formatSeasonName(seasonDNA.primary.season))
                .font(.system(size: size * 0.12, weight: .bold, design: .serif))
                .foregroundColor(primaryColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Primary percentage
            Text(seasonDNA.primary.percentageString)
                .font(.system(size: size * 0.15, weight: .heavy))
                .foregroundColor(primaryColor)
            
            // Secondary season (if exists)
            if let secondary = seasonDNA.secondary {
                HStack(spacing: 4) {
                    Text("+")
                        .font(.system(size: size * 0.08))
                        .foregroundColor(.secondary)
                    
                    Text(formatSeasonName(secondary.season, short: true))
                        .font(.system(size: size * 0.08, weight: .medium))
                        .foregroundColor(secondaryColor ?? .secondary)
                    
                    Text("(\(secondary.percentageString))")
                        .font(.system(size: size * 0.08))
                        .foregroundColor(.secondary)
                }
            }
            
            // Pure match indicator
            if seasonDNA.isPureMatch {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: size * 0.08))
                        .foregroundColor(.green)
                    
                    Text("Pure Match")
                        .font(.system(size: size * 0.08, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .frame(width: size * 0.6) // Center content takes 60% of total size
    }
    
    // MARK: - Helper Methods
    
    private func formatSeasonName(_ season: String, short: Bool = false) -> String {
        if short {
            // For secondary/tertiary display, abbreviate if needed
            let words = season.components(separatedBy: " ")
            if words.count > 1 {
                return words.last ?? season
            }
        }
        return season
    }
}

// MARK: - Preview

struct SeasonDNARingChart_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Pure season example
            SeasonDNARingChart(
                seasonDNA: SeasonDNA(
                    primary: SeasonWeight(season: "True Autumn", weight: 1.0),
                    explanation: "Pure True Autumn characteristics",
                    classificationConfidence: 0.92
                ),
                primaryColor: .orange,
                size: 200
            )
            
            // Blended season example
            SeasonDNARingChart(
                seasonDNA: SeasonDNA(
                    primary: SeasonWeight(season: "Soft Summer", weight: 0.75),
                    secondary: SeasonWeight(season: "Soft Autumn", weight: 0.25),
                    explanation: "Soft Summer with Autumn influences",
                    classificationConfidence: 0.85,
                    blendJustification: "Muted qualities suggest autumn overlap"
                ),
                primaryColor: .blue,
                secondaryColor: .orange,
                size: 200
            )
            
            // Complex blend example
            SeasonDNARingChart(
                seasonDNA: SeasonDNA(
                    primary: SeasonWeight(season: "Light Spring", weight: 0.65),
                    secondary: SeasonWeight(season: "Light Summer", weight: 0.25),
                    tertiary: SeasonWeight(season: "Clear Spring", weight: 0.10),
                    explanation: "Light Spring with summer and clear influences",
                    classificationConfidence: 0.78,
                    blendJustification: "Light qualities with cool and clear elements"
                ),
                primaryColor: .yellow,
                secondaryColor: .blue,
                tertiaryColor: .green,
                size: 200
            )
        }
        .padding()
        .background(Color(.systemBackground))
    }
} 