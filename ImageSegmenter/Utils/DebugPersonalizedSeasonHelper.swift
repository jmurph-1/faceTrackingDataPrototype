//
//  DebugPersonalizedSeasonHelper.swift
//  ImageSegmenter
//
//  Created by John Murphy on 12/27/24.
//

import SwiftUI
import UIKit

/// Debug helper for testing PersonalizedSeasonView with mock data
struct DebugPersonalizedSeasonHelper {

    /// Present PersonalizedSeasonView with mock data
    /// - Parameters:
    ///   - mockData: Optional specific mock data (uses random if nil)
    ///   - from: The presenting view controller
    static func presentMockPersonalizedView(
        mockData: PersonalizedSeasonData? = nil,
        from viewController: UIViewController
    ) {
        let data = mockData ?? MockPersonalizedSeasonDataFactory.random()
        let colors = getSeasonColors(for: data.baseSeason)

        // Log metal recommendations for debugging
        if let metals = data.metals {
            print("🔧 Metal Recommendations for \(data.baseSeason):")
            for metal in metals {
                print("  • \(metal.name) (\(metal.priority))")
                print("    Finishes:")
                for finish in metal.availableFinishes {
                    print("      - \(finish.name) (\(finish.priority))")
                }
            }
        } else {
            print("⚠️ No metal recommendations available for \(data.baseSeason)")
        }

        let personalizedView = PersonalizedSeasonView(
            personalizedData: data,
            primaryColor: colors.primary,
            paletteWhite: colors.paletteWhite,
            accentColor: colors.accent,
            accentColor2: colors.accent2,
            backgroundColor: colors.background,
            secondaryBackgroundColor: colors.secondaryBackground,
            textColor: colors.text,
            moduleColor: colors.module
        )

        let hostingController = UIHostingController(rootView: personalizedView)
        hostingController.modalPresentationStyle = .fullScreen
        viewController.present(hostingController, animated: true)
    }

    /// Create a debug menu for testing different mock scenarios
    static func presentDebugMenu(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Debug Personalized Season View",
            message: "Choose a mock scenario to test",
            preferredStyle: .actionSheet
        )

        // Add options for different mock scenarios
        alert.addAction(UIAlertAction(title: "Bright Spring (DNA Blend)", style: .default) { _ in
            presentMockPersonalizedView(
                mockData: MockPersonalizedSeasonDataFactory.brightSpringWithBlend(),
                from: viewController
            )
        })

        alert.addAction(UIAlertAction(title: "Soft Autumn (Pure)", style: .default) { _ in
            presentMockPersonalizedView(
                mockData: MockPersonalizedSeasonDataFactory.softAutumn(),
                from: viewController
            )
        })

        alert.addAction(UIAlertAction(title: "Dark Winter (Complex)", style: .default) { _ in
            presentMockPersonalizedView(
                mockData: MockPersonalizedSeasonDataFactory.deepWinterComplex(),
                from: viewController
            )
        })

        alert.addAction(UIAlertAction(title: "Random", style: .default) { _ in
            presentMockPersonalizedView(from: viewController)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Handle iPad presentation
        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(alert, animated: true)
    }

}

// MARK: - LLM Pipeline Testing (Debug only)

#if DEBUG
extension DebugPersonalizedSeasonHelper {

    /// Show a menu of pre-built AnalysisResult fixtures and run each through
    /// the real LLM personalization pipeline, displaying the result when done.
    static func presentLLMTestMenu(
        viewModel: CameraViewModel,
        from viewController: UIViewController
    ) {
        let alert = UIAlertController(
            title: "🔬 LLM Personalization Test",
            message: "Runs a pre-built analysis through the real LLM pipeline. Requires an API key and network.",
            preferredStyle: .actionSheet
        )

        for fixture in MockAnalysisResultFactory.all {
            alert.addAction(UIAlertAction(title: fixture.label, style: .default) { _ in
                runLLMTest(
                    with: fixture.result,
                    label: fixture.label,
                    viewModel: viewModel,
                    from: viewController
                )
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        viewController.present(alert, animated: true)
    }

    private static func runLLMTest(
        with mockResult: AnalysisResult,
        label: String,
        viewModel: CameraViewModel,
        from viewController: UIViewController
    ) {
        let loadingVC = makeLLMLoadingOverlay(label: label)
        viewController.present(loadingVC, animated: true)

        viewModel.testPersonalization(with: mockResult) { result in
            DispatchQueue.main.async {
                loadingVC.dismiss(animated: true) {
                    switch result {
                    case .success(let personalizedData):
                        print("🟢 LLM Test [\(label)]: personalization succeeded")
                        presentMockPersonalizedView(mockData: personalizedData, from: viewController)
                    case .failure(let error):
                        print("🔴 LLM Test [\(label)]: personalization failed — \(error)")
                        let errAlert = UIAlertController(
                            title: "LLM Test Failed",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        errAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        viewController.present(errAlert, animated: true)
                    }
                }
            }
        }
    }

    private static func makeLLMLoadingOverlay(label: String) -> UIViewController {
        let vc = UIViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        vc.view.backgroundColor = UIColor.black.withAlphaComponent(0.55)

        let card = UIView()
        card.backgroundColor = UIColor.systemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(card)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Running LLM Test"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = label
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let noteLabel = UILabel()
        noteLabel.text = "Calling OpenAI — this may take up to 30s"
        noteLabel.font = .systemFont(ofSize: 12)
        noteLabel.textColor = .tertiaryLabel
        noteLabel.textAlignment = .center
        noteLabel.numberOfLines = 0
        noteLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(spinner)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(noteLabel)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 260),

            spinner.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            spinner.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            noteLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            noteLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            noteLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            noteLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        ])

        return vc
    }
}
#endif

// MARK: - Season Color Helpers

extension DebugPersonalizedSeasonHelper {

    /// Color configuration for PersonalizedSeasonView
    struct SeasonColors {
        let primary: Color
        let paletteWhite: Color
        let accent: Color
        let accent2: Color
        let background: Color
        let secondaryBackground: Color
        let text: Color
        let module: Color
    }

    /// Get appropriate colors for a season
    static func getSeasonColors(for season: String) -> SeasonColors {
        let seasonLower = season.lowercased()

        if seasonLower.contains("spring") {
            return SeasonColors(
                primary: Color(hex: "#FFB347"),
                paletteWhite: Color.white,
                accent: Color(hex: "#FF6B35"),
                accent2: Color(hex: "#06FFA5"),
                background: Color(.systemBackground),
                secondaryBackground: Color(.secondarySystemBackground),
                text: Color(.label),
                module: Color(.systemGray6)
            )
        } else if seasonLower.contains("summer") {
            return SeasonColors(
                primary: Color(hex: "#87CEEB"),
                paletteWhite: Color.white,
                accent: Color(hex: "#DDA0DD"),
                accent2: Color(hex: "#FFB6C1"),
                background: Color(.systemBackground),
                secondaryBackground: Color(.secondarySystemBackground),
                text: Color(.label),
                module: Color(.systemGray6)
            )
        } else if seasonLower.contains("autumn") {
            return SeasonColors(
                primary: Color(hex: "#CD853F"),
                paletteWhite: Color.white,
                accent: Color(hex: "#D2691E"),
                accent2: Color(hex: "#DAA520"),
                background: Color(.systemBackground),
                secondaryBackground: Color(.secondarySystemBackground),
                text: Color(.label),
                module: Color(.systemGray6)
            )
        } else { // Winter
            return SeasonColors(
                primary: Color(hex: "#4682B4"),
                paletteWhite: Color.white,
                accent: Color(hex: "#DC143C"),
                accent2: Color(hex: "#800080"),
                background: Color(.systemBackground),
                secondaryBackground: Color(.secondarySystemBackground),
                text: Color(.label),
                module: Color(.systemGray6)
            )
        }
    }
}

// MARK: - SwiftUI Preview Helper

#if DEBUG
struct DebugPersonalizedSeasonView_Previews: PreviewProvider {
    static var previews: some View {
        let mockData = MockPersonalizedSeasonDataFactory.brightSpringWithBlend()
        let colors = DebugPersonalizedSeasonHelper.getSeasonColors(for: mockData.baseSeason)

        PersonalizedSeasonView(
            personalizedData: mockData,
            primaryColor: colors.primary,
            paletteWhite: colors.paletteWhite,
            accentColor: colors.accent,
            accentColor2: colors.accent2,
            backgroundColor: colors.background,
            secondaryBackgroundColor: colors.secondaryBackground,
            textColor: colors.text,
            moduleColor: colors.module
        )
    }
}
#endif
