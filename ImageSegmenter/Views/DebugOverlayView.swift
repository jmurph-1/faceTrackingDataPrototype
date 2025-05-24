import SwiftUI

/// Debug overlay view for displaying performance metrics and color data
struct DebugOverlayView: View {
    // MARK: - Logging
    private func logQualityScore() {
        guard let quality = qualityScore else {
            LoggingService.debug("No quality score available")
            return
        }

        // Split into multiple lines to avoid exceeding character limit
        // LoggingService.debug("Quality scores - Overall: \(quality.overall), FaceSize: \(quality.faceSize)")
        // LoggingService.debug("Quality scores - Position: \(quality.facePosition), Brightness: \(quality.brightness), Sharpness: \(quality.sharpness)")
    }

    /// FPS measurement
    let fps: Float

    /// Current skin color in Lab space
    let skinColorLab: ColorConverters.LabColor?

    /// Current hair color in Lab space
    let hairColorLab: ColorConverters.LabColor?

    /// Delta-E to each season
    let deltaEToSeasons: [SeasonClassifier.Season: CGFloat]?

    /// Quality score
    let qualityScore: FrameQualityService.QualityScore?

    /// Flag to control expanded view
    @State private var isExpanded: Bool = false

    // Init with logging
    init(fps: Float,
         skinColorLab: ColorConverters.LabColor?,
         hairColorLab: ColorConverters.LabColor?,
         deltaEToSeasons: [SeasonClassifier.Season: CGFloat]?,
         qualityScore: FrameQualityService.QualityScore?) {
        self.fps = fps
        self.skinColorLab = skinColorLab
        self.hairColorLab = hairColorLab
        self.deltaEToSeasons = deltaEToSeasons
        self.qualityScore = qualityScore

        // print("DebugOverlayView initialized with qualityScore: \(String(describing: qualityScore))")

    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with toggle
            HStack {
                Text("DEBUG")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)

                Spacer()

                Text("FPS: \(String(format: "%.1f", fps))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(fpsColor())

                Button(action: {
                    isExpanded.toggle()
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.8))
            .cornerRadius(6)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Color values
                    colorSection()

                    // Delta-E values
                    deltaESection()

                    // Quality scores
                    qualitySection()
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(6)
            }
        }
        .padding(10)
        .id(qualityScore?.overall ?? 0) // Force refresh when quality score changes
        .onAppear {
            logQualityScore()
        }
    }

    // MARK: - Helper views

    /// Section for displaying color values
    private func colorSection() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("COLOR VALUES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)

            if let skin = skinColorLab {
                HStack {
                    colorSample(Color(UIColor(red: CGFloat(skin.L)/100, green: 0.5, blue: 0.5, alpha: 1.0)))
                    Text("Skin: L=\(String(format: "%.1f", skin.L)), a=\(String(format: "%.1f", skin.a)), b=\(String(format: "%.1f", skin.b))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
            } else {
                Text("No skin color detected")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            if let hair = hairColorLab {
                HStack {
                    colorSample(Color(UIColor(red: CGFloat(hair.L)/100, green: 0.5, blue: 0.5, alpha: 1.0)))
                    Text("Hair: L=\(String(format: "%.1f", hair.L)), a=\(String(format: "%.1f", hair.a)), b=\(String(format: "%.1f", hair.b))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
            } else {
                Text("No hair color detected")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }

    /// Section for displaying delta-E values
    private func deltaESection() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DELTA-E TO SEASONS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)

            if let deltaEs = deltaEToSeasons {
                let sortedSeasons = deltaEs.sorted { $0.value < $1.value }

                ForEach(sortedSeasons.prefix(4), id: \.key) { (season, deltaE) in
                    HStack {
                        Text(season.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(seasonColor(for: season))
                            .frame(width: 60, alignment: .leading)

                        Text("\(String(format: "%.2f", deltaE))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)

                        // Simple bar visualization
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: 100, height: 6)
                                .foregroundColor(.gray.opacity(0.3))

                            Rectangle()
                                .frame(width: max(2, min(100, 100 - deltaE * 5)), height: 6)
                                .foregroundColor(seasonColor(for: season))
                        }
                    }
                }

                // Add margin info to next closest season if we have at least 2 seasons
                if sortedSeasons.count >= 2 {
                    let closest = sortedSeasons[0]
                    let nextClosest = sortedSeasons[1]
                    let margin = nextClosest.value - closest.value

                    HStack {
                        Text("Margin to \(nextClosest.key.rawValue):")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)

                        Text("\(String(format: "%.2f", margin)) ΔE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("No delta-E data available")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }

    /// Section for displaying quality scores
    private func qualitySection() -> some View {
        // LoggingService.debug("DebugOverlayView qualitySection called with qualityScore: \(String(describing: qualityScore))")

        return VStack(alignment: .leading, spacing: 4) {
            Text("QUALITY SCORES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)

            if let quality = qualityScore {
                HStack {
                    Text("Overall: \(String(format: "%.2f", quality.overall))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(quality.overall >= FrameQualityService.minimumQualityScoreForAnalysis ? .green : .orange)
                        .frame(width: 80, alignment: .leading)

                    Text("Face Size: \(String(format: "%.2f", quality.faceSize))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(quality.faceSize >= FrameQualityService.minimumFaceSizeScoreForAnalysis ? .green : .orange)
                }

                HStack {
                    Text("Position: \(String(format: "%.2f", quality.facePosition))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(quality.facePosition >= FrameQualityService.minimumFacePositionScoreForAnalysis ? .green : .orange)
                        .frame(width: 80, alignment: .leading)

                    Text("Brightness: \(String(format: "%.2f", quality.brightness))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(quality.brightness >= FrameQualityService.minimumBrightnessScoreForAnalysis ? .green : .orange)
                }

                HStack {
                    Text("Sharpness: \(String(format: "%.2f", quality.sharpness))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(quality.sharpness >= 0.5 ? .green : .orange)
                }
            } else {
                Text("No quality data available")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }

    /// Helper to create a color sample view
    private func colorSample(_ color: Color) -> some View {
        color
            .frame(width: 10, height: 10)
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
    }

    // MARK: - Helper methods

    /// Determine color for FPS display
    private func fpsColor() -> Color {
        if fps >= 25 {
            return .green
        } else if fps >= 18 {
            return .yellow
        } else {
            return .red
        }
    }

    /// Get a color for a season
    private func seasonColor(for season: SeasonClassifier.Season) -> Color {
        switch season {
        case .spring:
            return .yellow
        case .summer:
            return .blue
        case .autumn:
            return .orange
        case .winter:
            return .purple
        }
    }
}

// MARK: - Preview
struct DebugOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample data
        let skin = ColorConverters.LabColor(L: 65.0, a: 8.0, b: 16.0)
        let hair = ColorConverters.LabColor(L: 35.0, a: 6.0, b: 12.0)

        let deltaEs: [SeasonClassifier.Season: CGFloat] = [
            .spring: 5.2,
            .summer: 8.7,
            .autumn: 3.1,
            .winter: 6.4
        ]

        let quality = FrameQualityService.QualityScore(
            overall: 0.75,
            faceSize: 0.8,
            facePosition: 0.7,
            brightness: 0.9,
            sharpness: 0.6
        )

        return ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            DebugOverlayView(
                fps: 24.5,
                skinColorLab: skin,
                hairColorLab: hair,
                deltaEToSeasons: deltaEs,
                qualityScore: quality
            )
        }
    }
}
