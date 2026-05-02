//
//  SavedAnalysesView.swift
//  ImageSegmenter
//
//  Created by John Murphy on 4/26/26.
//

import SwiftUI
import UIKit

struct SavedAnalysesView: View {

    @Environment(\.presentationMode) private var presentationMode
    @State private var savedAnalyses: [PersonalizedSeasonData] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading analyses...")
                } else if savedAnalyses.isEmpty {
                    emptyState
                } else {
                    analysesList
                }
            }
            .navigationBarTitle("My Analyses", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            loadAnalyses()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Saved Analyses")
                .font(.title2)
                .fontWeight(.bold)

            Text("Save a personalized season analysis to view it here anytime.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var analysesList: some View {
        List {
            ForEach(savedAnalyses, id: \.id) { analysis in
                analysisRow(analysis)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openAnalysis(analysis)
                    }
            }
            .onDelete { indexSet in
                deleteAnalyses(at: indexSet)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private func analysisRow(_ analysis: PersonalizedSeasonData) -> some View {
        HStack(spacing: 14) {
            let theme = SeasonTheme.getTheme(for: analysis.baseSeason)

            Circle()
                .fill(theme.primaryColor)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(seasonAbbreviation(for: analysis.baseSeason))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(analysis.baseSeason)
                    .font(.headline)

                Text(analysis.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Text(analysis.personalizedTagline)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func loadAnalyses() {
        isLoading = true
        savedAnalyses = CoreDataManager.shared.fetchAllPersonalizedSeasonData()
        isLoading = false
    }

    private func deleteAnalyses(at indexSet: IndexSet) {
        for index in indexSet {
            let analysis = savedAnalyses[index]
            _ = CoreDataManager.shared.deletePersonalizedSeasonData(id: analysis.id)
        }
        savedAnalyses.remove(atOffsets: indexSet)
    }

    private func openAnalysis(_ analysis: PersonalizedSeasonData) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }

        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        SeasonViewNavigationManager.presentPersonalizedSeasonView(
            from: presenter,
            personalizedData: analysis
        )
    }

    private func seasonAbbreviation(for seasonName: String) -> String {
        let words = seasonName.split(separator: " ").map { String($0) }
        guard words.count >= 2 else { return String(seasonName.prefix(3)).uppercased() }
        let first = words[0]
        switch first.lowercased() {
        case "true": return "TRU"
        case "bright": return "BRT"
        case "light": return "LGT"
        case "soft": return "SFT"
        case "dark": return "DRK"
        default:
            return (String(words[0].prefix(1)) + String(words[1].prefix(2))).uppercased()
        }
    }
}
