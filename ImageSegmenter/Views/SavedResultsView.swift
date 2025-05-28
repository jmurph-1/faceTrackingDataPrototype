import SwiftUI

/// View for displaying saved season analysis results
struct SavedResultsView: View {

    /// View model for analysis results
    @ObservedObject var viewModel: AnalysisResultViewModel

    /// Controls whether the sheet is presented
    @Binding var isPresented: Bool

    /// Selected result for details
    @State private var selectedResult: AnalysisResult?

    /// Show details sheet
    @State private var showDetails = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    // Loading indicator
                    ProgressView("Loading results...")
                } else if viewModel.savedResults.isEmpty {
                    // Empty state
                    emptyStateView()
                } else {
                    // Results list
                    resultsList()
                }
            }
            .navigationBarTitle("Saved Analyses", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
        .sheet(isPresented: $showDetails) {
            if let result = selectedResult {
                detailView(for: result)
            }
        }
        .onAppear {
            viewModel.loadSavedResults()
        }
    }

    // MARK: - Helper views

    /// Empty state view
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Saved Analyses")
                .font(.title2)
                .fontWeight(.bold)

            Text("Your saved season analyses will appear here.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    /// Results list
    private func resultsList() -> some View {
        List {
            ForEach(viewModel.savedResults, id: \.date) { result in
                resultRow(result)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedResult = result
                        showDetails = true
                    }
            }
            .onDelete { indexSet in
                deleteResults(at: indexSet)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    /// Result row
    private func resultRow(_ result: AnalysisResult) -> some View {
        HStack(spacing: 15) {
            // Season badge
            ZStack {
                Circle()
                    .fill(seasonColor(for: result.season))
                    .frame(width: 50, height: 50)

                Image(systemName: seasonIcon(for: result.season))
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            // Result info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.season.rawValue)
                    .font(.headline)

                Text(result.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // Color samples
                HStack(spacing: 8) {
                    // Skin color
                    Circle()
                        .fill(Color(result.skinColor))
                        .frame(width: 15, height: 15)
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 0.5))

                    // Hair color (if available)
                    if let hairColor = result.hairColor {
                        Circle()
                            .fill(Color(hairColor))
                            .frame(width: 15, height: 15)
                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                    }

                    Spacer()

                    // Confidence
                    Text(result.confidencePercentage)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.1))
                        )
                }
            }

            Spacer()

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }

    /// Detail view for a result
    private func detailView(for result: AnalysisResult) -> some View {
        AnalysisResultView(
            viewModel: viewModel,
            onDismiss: {
                showDetails = false
            },
            onRetry: {
                showDetails = false
                isPresented = false
            },
            onSeeDetails: {
                // Stub for future expansion
            }
        )
        .onAppear {
            viewModel.updateWithResult(result)
        }
    }

    // MARK: - Helper methods

    /// Delete results at given indices
    private func deleteResults(at indexSet: IndexSet) {
        for index in indexSet {
            let result = viewModel.savedResults[index]
            _ = viewModel.deleteResult(with: result.date)
        }
    }

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
struct SavedResultsView_Previews: PreviewProvider {
    static var previews: some View {
        // Setup a sample view model with results
        let viewModel = AnalysisResultViewModel()

        // Add sample results
        let seasons: [SeasonClassifier.Season] = [.spring, .summer, .autumn, .winter]

        for (index, season) in seasons.enumerated() {
            let result = AnalysisResult(
                season: season,
                confidence: Float(0.7 + Double(index) * 0.05),
                deltaEToNextClosest: Float(1.0 + Double(index) * 0.2),
                nextClosestSeason: index < seasons.count - 1 ? seasons[index + 1] : seasons[0],
                skinColor: UIColor(
                    red: 0.7 + CGFloat(index) * 0.05,
                    green: 0.6 - CGFloat(index) * 0.05,
                    blue: 0.5,
                    alpha: 1.0
                ),
                skinColorLab: (L: 70.0, a: 5.0 + CGFloat(index) * 2, b: 15.0 + CGFloat(index) * 2),
                hairColor: UIColor(
                    red: 0.3 - CGFloat(index) * 0.05,
                    green: 0.2 + CGFloat(index) * 0.05,
                    blue: 0.1,
                    alpha: 1.0
                ),
                hairColorLab: (L: 30.0, a: 5.0, b: 10.0),
                contrastValue: 0.5 + Double(index) * 0.1,
                contrastLevel: ["low", "medium", "medium-high", "high"][index],
                contrastDescription: "Sample contrast description for \(season.rawValue)",
                thumbnail: nil,
                date: Date().addingTimeInterval(-Double(index) * 86400) // Subtract days
            )

            viewModel.savedResults.append(result)
        }

        return Group {
            // With results
            SavedResultsView(
                viewModel: viewModel,
                isPresented: .constant(true)
            )

            // Empty state
            SavedResultsView(
                viewModel: AnalysisResultViewModel(),
                isPresented: .constant(true)
            )
        }
    }
}
