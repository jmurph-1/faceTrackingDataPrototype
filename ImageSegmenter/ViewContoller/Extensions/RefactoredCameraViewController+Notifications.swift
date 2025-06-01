//
//  RefactoredCameraViewController+Notifications.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import UIKit
import Foundation

// MARK: - Notifications Extension

extension RefactoredCameraViewController {
    
    /// Setup notification manager and observers
    func setupNotificationManager() {
        notificationManager = NotificationManager(viewController: self)
    }
    
    /// Remove notification observers when view disappears
    func cleanupNotificationManager() {
        notificationManager?.removeNotificationObservers()
        notificationManager = nil
    }
    
    /// Handle app lifecycle notifications
    func setupAppLifecycleNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// Remove app lifecycle notifications
    func removeAppLifecycleNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
    }
    
    // MARK: - App Lifecycle Handlers
    
    @objc private func handleAppDidEnterBackground() {
        // Pause camera to save battery
        if viewModel.isSessionRunning {
            viewModel.stopCamera()
        }
    }
    
    @objc private func handleAppWillTerminate() {
        // Clean up resources
        cleanupNotificationManager()
        viewModel.stopCamera()
    }
    
    // MARK: - Custom Notification Handlers
    
    /// Setup any custom notification observers specific to this view controller
    func setupCustomNotifications() {
        // Add any custom notifications specific to camera functionality
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersonalizationStatusChanged),
            name: Notification.Name("PersonalizationStatusChanged"),
            object: nil
        )
    }
    
    /// Remove custom notification observers
    func removeCustomNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("PersonalizationStatusChanged"), object: nil)
    }
    
    @objc private func handlePersonalizationStatusChanged() {
        // Handle changes to personalization availability
        updatePersonalizationUI()
    }
    
    /// Update UI based on personalization status
    private func updatePersonalizationUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update any UI elements that depend on personalization status
            let isPersonalizationActive = AppConfiguration.shared.isPersonalizationActive
            
            // For example, update a status indicator or tooltip
            if isPersonalizationActive {
                // Show personalization available indicator
                showPersonalizationIndicator()
            } else {
                // Hide personalization indicator
                hidePersonalizationIndicator()
            }
        }
    }
    
    /// Show indicator that personalization is available
    private func showPersonalizationIndicator() {
        // Add visual indicator that personalization is available
        // This could be a small icon or status text
    }
    
    /// Hide personalization indicator
    private func hidePersonalizationIndicator() {
        // Remove personalization indicator
    }
} 