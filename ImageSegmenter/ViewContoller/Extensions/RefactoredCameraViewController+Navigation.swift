//
//  RefactoredCameraViewController+Navigation.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import UIKit
import SwiftUI

// MARK: - Navigation Extension

extension RefactoredCameraViewController {
    
    /// Setup navigation-related UI and handlers
    func setupNavigationHandlers() {
        // Setup back button if needed
        setupBackButton()
        
        // Setup navigation bar appearance
        setupNavigationBarAppearance()
    }
    
    /// Setup back button functionality
    private func setupBackButton() {
        // Add custom back button if using custom navigation
        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(true, animated: false)
        }
    }
    
    /// Setup navigation bar appearance
    private func setupNavigationBarAppearance() {
        // Configure navigation bar appearance if needed
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.barStyle = .default
    }
    
    /// Handle navigation to season view with analysis result
    /// - Parameter analysisResult: The analysis result to display
    func navigateToSeasonView(with analysisResult: AnalysisResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            SeasonViewNavigationManager.presentDefaultSeasonView(
                from: self,
                analysisResult: analysisResult
            )
        }
    }
    
    /// Handle navigation to personalized season view
    /// - Parameter personalizedData: The personalized data to display
    func navigateToPersonalizedSeasonView(with personalizedData: PersonalizedSeasonData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            SeasonViewNavigationManager.presentPersonalizedSeasonView(
                from: self,
                personalizedData: personalizedData
            )
        }
    }
    
    /// Navigate back to landing page
    func navigateToLandingPage() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let navigationController = self.navigationController {
                navigationController.popViewController(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        }
    }
    
    /// Handle navigation after successful analysis
    /// This method coordinates between different types of results
    func handleAnalysisNavigation() {
        // Navigation is now handled by NotificationManager
        // This method can be used for additional navigation logic if needed
    }
    
    /// Present error alert and navigate appropriately
    /// - Parameters:
    ///   - error: The error to display
    ///   - allowRetry: Whether to show a retry option
    func presentErrorAndNavigate(_ error: Error, allowRetry: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(
                title: "Analysis Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            
            if allowRetry {
                alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                    // Reset for another attempt
                    self.resetForNewAnalysis()
                })
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.navigateToLandingPage()
            })
            
            self.present(alert, animated: true)
        }
    }
    
    /// Reset UI for a new analysis attempt
    private func resetForNewAnalysis() {
        // Reset any UI state for retry
        resetAnalysisState()
    }
    
    /// Reset analysis state (to be implemented in main controller)
    func resetAnalysisState() {
        // This method should be implemented in the main controller
        // It's declared here for consistency with the extension pattern
    }
} 