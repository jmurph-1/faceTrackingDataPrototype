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
            // Base metallic circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: metal.metallicGradient),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Metallic shimmer overlay
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.clear,
                            Color.white.opacity(0.2),
                            Color.clear,
                            Color.white.opacity(0.3)
                        ]),
                        center: .center
                    )
                )
                .frame(width: size, height: size)
                .blendMode(.overlay)

            // Finish texture overlay
            if let bestFinish = metal.bestFinish {
                if bestFinish.name.lowercased().contains("brushed") {
                    BrushedMetalTexture()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .blendMode(.overlay)
                        .opacity(0.3)
                } else if bestFinish.name.lowercased().contains("antique") {
                    AntiqueMetalTexture()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .blendMode(.multiply)
                        .opacity(0.2)
                }
            }

            // Highlight effect
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: size, height: size)
        }
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Texture Components

/// Brushed metal texture view
struct BrushedMetalTexture: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<20) { index in
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: geometry.size.width, height: 0.5)
                    .offset(y: CGFloat(index) * 3)
            }
        }
    }
}

/// Antique metal texture view
struct AntiqueMetalTexture: View {
    var body: some View {
        ZStack {
            // Random spots for aged effect
            ForEach(0..<15) { index in
                Circle()
                    .fill(Color.black.opacity(Double.random(in: 0.05...0.15)))
                    .frame(width: CGFloat.random(in: 2...8))
                    .position(
                        x: CGFloat.random(in: 0...60),
                        y: CGFloat.random(in: 0...60)
                    )
                    .id(index) // Ensure consistent rendering
            }
        }
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
