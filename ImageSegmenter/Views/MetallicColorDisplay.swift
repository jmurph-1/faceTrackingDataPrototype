//
//  MetallicColorDisplay.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import SwiftUI

struct MetallicColorDisplay: View {
    let metal: MetalRecommendation
    let size: CGFloat

    init(metal: MetalRecommendation, size: CGFloat = 60) {
        self.metal = metal
        self.size = size
    }

    var body: some View {
        ZStack {
            if metal.isMixed {
                // Mixed metal display (split vertically)
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: metal.metallicGradient),
                            startPoint: UnitPoint(x: 0, y: 0.5),
                            endPoint: UnitPoint(x: 1, y: 0.5)
                        )
                    )
                    .frame(width: size, height: size)
            } else {
                // Regular metal display
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: metal.metallicGradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
            }

            // Edge highlight
            Circle()
                .stroke(
                    Color.black.opacity(0.1),
                    lineWidth: 0.5
                )
                .frame(width: size, height: size)
        }
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

struct MetallicColorDisplay_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                MetallicColorDisplay(
                    metal: MetalRecommendation(
                        name: "Gold",
                        availableFinishes: [
                            MetalRecommendation.FinishOption(name: "Bright", priority: .great, seasonSource: "True Spring")
                        ],
                        priority: .great,
                        seasonSources: ["True Spring"]
                    ),
                    size: 80
                )

                MetallicColorDisplay(
                    metal: MetalRecommendation(
                        name: "Silver",
                        availableFinishes: [
                            MetalRecommendation.FinishOption(name: "Brushed", priority: .good, seasonSource: "True Summer")
                        ],
                        priority: .good,
                        seasonSources: ["True Summer"]
                    ),
                    size: 80
                )

                MetallicColorDisplay(
                    metal: MetalRecommendation(
                        name: "Copper",
                        availableFinishes: [
                            MetalRecommendation.FinishOption(name: "Antique", priority: .great, seasonSource: "True Autumn")
                        ],
                        priority: .great,
                        seasonSources: ["True Autumn"]
                    ),
                    size: 80
                )
            }

            HStack(spacing: 20) {
                MetallicColorDisplay(
                    metal: MetalRecommendation(
                        name: "Rose Gold",
                        availableFinishes: [
                            MetalRecommendation.FinishOption(name: "Bright", priority: .great, seasonSource: "Light Spring")
                        ],
                        priority: .great,
                        seasonSources: ["Light Spring"]
                    ),
                    size: 60
                )

                MetallicColorDisplay(
                    metal: MetalRecommendation(
                        name: "Platinum",
                        availableFinishes: [
                            MetalRecommendation.FinishOption(name: "Polished", priority: .great, seasonSource: "True Winter")
                        ],
                        priority: .great,
                        seasonSources: ["True Winter"]
                    ),
                    size: 60
                )

                MetallicColorDisplay(
                    metal: MetalRecommendation(
                        name: "Bronze",
                        availableFinishes: [
                            MetalRecommendation.FinishOption(name: "Antique", priority: .good, seasonSource: "Dark Autumn")
                        ],
                        priority: .good,
                        seasonSources: ["Dark Autumn"]
                    ),
                    size: 60
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .preferredColorScheme(.light)
    }
}
