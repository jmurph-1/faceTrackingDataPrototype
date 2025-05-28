import SwiftUI

/// View for displaying season analysis results
struct AnalysisResultView: View {

    /// View model for analysis results
    @ObservedObject var viewModel: AnalysisResultViewModel

    /// Dismiss action
    var onDismiss: () -> Void

    /// Retry action
    var onRetry: () -> Void

    /// See details action (stub for future expansion)
    var onSeeDetails: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Your Season Analysis")
                .font(.headline)
                .padding(.top)

            // Result content
            if let result = viewModel.currentResult {
                resultContent(result)
            } else {
                // Fallback if no result
                Text("No analysis result available")
                    .foregroundColor(.gray)
                    .padding()
            }

            // Actions
            actionButtons()
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 5)
        .padding()
    }

    // MARK: - Helper views

    /// Create the result content section
    private func resultContent(_ result: AnalysisResult) -> some View {
        VStack(spacing: 20) {
            // Season badge
            seasonBadge(for: result.season)
                .padding()

            // Color samples
            colorSamples(result)
                .padding(.horizontal)

            // Season description
            Text(result.seasonDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Confidence information
            HStack {
                Text("Match confidence: ")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Text(result.confidencePercentage)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)

                Spacer()

                if result.deltaEToNextClosest > 0 {
                    Text("ΔE to \(result.nextClosestSeason.rawValue): \(String(format: "%.1f", result.deltaEToNextClosest))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
        }
    }

    /// Create the season badge
    private func seasonBadge(for season: SeasonClassifier.Season) -> some View {
        VStack {
            // Badge icon with season-specific color
            ZStack {
                Circle()
                    .fill(seasonColor(for: season))
                    .frame(width: 120, height: 120)

                Image(systemName: seasonIcon(for: season))
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // Season name
            Text(season.rawValue)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 8)
        }
    }

    /// Create color sample views
    private func colorSamples(_ result: AnalysisResult) -> some View {
        VStack(spacing: 15) {
            // First row: Skin and Hair
            HStack(spacing: 20) {
                // Skin color
                VStack {
                    Circle()
                        .fill(Color(result.skinColor))
                        .frame(width: 50, height: 50)
                        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        .shadow(radius: 2)

                    Text("Skin")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Hair color (if available)
                if let hairColor = result.hairColor {
                    VStack {
                        Circle()
                            .fill(Color(hairColor))
                            .frame(width: 50, height: 50)
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .shadow(radius: 2)

                        Text("Hair")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            // Second row: Eye colors (if available)
            if hasEyeColors(result) {
                HStack(spacing: 15) {
                    // Left eye color
                    if let leftEyeColor = result.leftEyeColor, result.leftEyeConfidence > 0 {
                        VStack {
                            Circle()
                                .fill(Color(leftEyeColor))
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                .shadow(radius: 2)

                            Text("Left Eye")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }

                    // Right eye color
                    if let rightEyeColor = result.rightEyeColor, result.rightEyeConfidence > 0 {
                        VStack {
                            Circle()
                                .fill(Color(rightEyeColor))
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                .shadow(radius: 2)

                            Text("Right Eye")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }

                    // Average eye color
                    if let averageEyeColor = result.averageEyeColor {
                        VStack {
                            Circle()
                                .fill(Color(averageEyeColor))
                                .frame(width: 45, height: 45)
                                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                .shadow(radius: 2)

                            Text("Avg Eye")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }

    /// Check if the result has any eye color data
    private func hasEyeColors(_ result: AnalysisResult) -> Bool {
        return (result.leftEyeColor != nil && result.leftEyeConfidence > 0) ||
               (result.rightEyeColor != nil && result.rightEyeConfidence > 0) ||
               result.averageEyeColor != nil
    }

    /// Action buttons
    private func actionButtons() -> some View {
        VStack(spacing: 12) {
            // Save button
            if let result = viewModel.currentResult {
                Button(action: {
                    _ = viewModel.saveCurrentResult()
                }) {
                    Label(
                        viewModel.isResultSaved(result) ? "Saved" : "Save Result",
                        systemImage: viewModel.isResultSaved(result) ? "checkmark.circle.fill" : "square.and.arrow.down"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.isResultSaved(result) ? Color.gray.opacity(0.3) : Color.blue)
                    )
                    .foregroundColor(viewModel.isResultSaved(result) ? .gray : .white)
                }
                .disabled(viewModel.isResultSaved(result))
            }

            // Bottom action buttons
            HStack {
                // Retry button
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.2))
                        )
                        .foregroundColor(.primary)
                }

                // See details button (stub for future)
                Button(action: onSeeDetails) {
                    Label("See Details", systemImage: "list.bullet")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.2))
                        )
                        .foregroundColor(.primary)
                }
            }

            // Close button
            Button(action: onDismiss) {
                Text("Close")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helper methods

    /// Get a color for a season
    private func seasonColor(for season: SeasonClassifier.Season) -> Color {
        switch season {
        case .spring:
            return Color.yellow
        case .summer:
            return Color.blue
        case .autumn:
            return Color.orange
        case .winter:
            return Color.purple
        }
    }

    /// Get an icon for a season
    private func seasonIcon(for season: SeasonClassifier.Season) -> String {
        switch season {
        case .spring:
            return "sun.max.fill"
        case .summer:
            return "water.waves"
        case .autumn:
            return "leaf.fill"
        case .winter:
            return "snowflake"
        }
    }
}

// MARK: - Preview
struct AnalysisResultView_Previews: PreviewProvider {
    static var previews: some View {
        // Setup a sample analysis result
        let viewModel = AnalysisResultViewModel()
        let sampleResult = AnalysisResult(
            season: .autumn,
            confidence: 0.85,
            deltaEToNextClosest: 1.2,
            nextClosestSeason: .winter,
            skinColor: UIColor(red: 0.8, green: 0.7, blue: 0.6, alpha: 1.0),
            skinColorLab: (L: 70.0, a: 8.0, b: 22.0),
            hairColor: UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0),
            hairColorLab: (L: 30.0, a: 10.0, b: 15.0),
            leftEyeColor: UIColor(red: 0.4, green: 0.6, blue: 0.3, alpha: 1.0),
            leftEyeColorLab: (L: 55.0, a: -15.0, b: 25.0),
            rightEyeColor: UIColor(red: 0.35, green: 0.55, blue: 0.25, alpha: 1.0),
            rightEyeColorLab: (L: 52.0, a: -18.0, b: 28.0),
            averageEyeColor: UIColor(red: 0.375, green: 0.575, blue: 0.275, alpha: 1.0),
            averageEyeColorLab: (L: 53.5, a: -16.5, b: 26.5),
            leftEyeConfidence: 0.8,
            rightEyeConfidence: 0.75,
            thumbnail: nil
        )
        viewModel.updateWithResult(sampleResult)

        return Group {
            // Light mode
            AnalysisResultView(
                viewModel: viewModel,
                onDismiss: {},
                onRetry: {},
                onSeeDetails: {}
            )
            .previewLayout(.sizeThatFits)
            .padding()

            // Dark mode
            AnalysisResultView(
                viewModel: viewModel,
                onDismiss: {},
                onRetry: {},
                onSeeDetails: {}
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
        }
    }
}
