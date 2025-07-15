//
//  NotificationManager.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import UIKit

/// Centralized manager for handling analysis and personalization notifications
class NotificationManager {
    
    // MARK: - Notification Names
    
    static let analysisResultReady = Notification.Name("AnalysisResultReady")
    static let personalizationReady = Notification.Name("PersonalizationReady")
    static let personalizationFailed = Notification.Name("PersonalizationFailed")
    
    // MARK: - Properties
    
    private weak var viewController: UIViewController?
    private var pendingAnalysisResult: AnalysisResult?
    private var pendingPersonalizedData: PersonalizedSeasonData?
    private var timeoutWorkItem: DispatchWorkItem?
    
    // MARK: - Initialization
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        setupNotificationObservers()
    }
    
    deinit {
        removeNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /// Setup notification observers
    func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnalysisResult(_:)),
            name: Self.analysisResultReady,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersonalizationReady(_:)),
            name: Self.personalizationReady,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersonalizationFailed(_:)),
            name: Self.personalizationFailed,
            object: nil
        )
    }
    
    /// Remove notification observers
    func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleAnalysisResult(_ notification: Notification) {
        guard let analysisResult = notification.userInfo?["result"] as? AnalysisResult else {
            print("Error: Invalid analysis result in notification")
            return
        }
        
        #if DEBUG
        print("🔵 NotificationManager: handleAnalysisResult called for season: \(analysisResult.season.rawValue)")
        #endif
        
        // Store the result in case personalization comes later
        pendingAnalysisResult = analysisResult
        
        // Save to Core Data
        if CoreDataManager.shared.saveAnalysisResult(analysisResult) {
            print("Analysis result saved to Core Data")
        }
        
        // Check if we should wait for personalization or present immediately
        if AppConfiguration.shared.isPersonalizationActive {
            #if DEBUG
            print("🔵 NotificationManager: Personalization is active, waiting 30 seconds for personalization result")
            #endif
            
            // Cancel any existing timeout
            timeoutWorkItem?.cancel()
            
            // Create a new timeout work item
            let workItem = DispatchWorkItem { [weak self] in
                self?.presentResultIfStillPending()
            }
            timeoutWorkItem = workItem
            
            // Wait longer for personalization (30 seconds), then present default if it doesn't come
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0, execute: workItem)
        } else {
            #if DEBUG
            print("🔵 NotificationManager: Personalization not active, presenting default view immediately")
            #endif
            // Present default season view immediately
            presentDefaultSeasonView(with: analysisResult)
        }
    }
    
    @objc private func handlePersonalizationReady(_ notification: Notification) {
        guard let personalizedData = notification.userInfo?["personalizedData"] as? PersonalizedSeasonData else {
            print("Error: Invalid personalized data in notification")
            return
        }
        
        #if DEBUG
        print("🟢 NotificationManager: handlePersonalizationReady called for season: \(personalizedData.baseSeason)")
        #endif
        
        // Cancel the timeout since personalization completed
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        // Store personalized data
        pendingPersonalizedData = personalizedData
        
        // Save to Core Data if we have a linked analysis result
        if let analysisResult = pendingAnalysisResult {
            // Create a UUID for the analysis result if it doesn't have one
            // Note: You may need to add an ID field to AnalysisResult if it doesn't exist
            let _ = personalizedData.saveToCoreData(linkedToAnalysisResultId: nil)
        }
        
        #if DEBUG
        print("🟢 NotificationManager: Presenting PersonalizedSeasonView")
        #endif
        
        // Dismiss any existing presented view (in case default view was already shown)
        if let viewController = viewController, 
           let presentedViewController = viewController.presentedViewController {
            #if DEBUG
            print("🔵 NotificationManager: Dismissing existing view before showing PersonalizedSeasonView")
            #endif
            presentedViewController.dismiss(animated: false) { [weak self] in
                self?.presentPersonalizedSeasonView(with: personalizedData)
            }
        } else {
            // Present personalized view directly
            presentPersonalizedSeasonView(with: personalizedData)
        }
        
        // Clear pending data
        clearPendingData()
    }
    
    @objc private func handlePersonalizationFailed(_ notification: Notification) {
        guard let error = notification.userInfo?["error"] as? Error,
              let fallbackResult = notification.userInfo?["fallbackResult"] as? AnalysisResult else {
            print("Error: Invalid personalization failure notification")
            return
        }
        
        #if DEBUG
        print("🔴 NotificationManager: handlePersonalizationFailed called - \(error.localizedDescription)")
        #endif
        
        print("Personalization failed: \(error.localizedDescription). Using default season view.")
        
        // Present default season view as fallback
        presentDefaultSeasonView(with: fallbackResult)
        
        // Clear pending data
        clearPendingData()
    }
    
    // MARK: - Private Methods
    
    private func presentResultIfStillPending() {
        #if DEBUG
        print("🔵 NotificationManager: presentResultIfStillPending called")
        print("🔵 NotificationManager: pendingAnalysisResult exists: \(pendingAnalysisResult != nil)")
        print("🔵 NotificationManager: pendingPersonalizedData exists: \(pendingPersonalizedData != nil)")
        #endif
        
        // If we still have a pending result and no personalization came through, present default
        if let analysisResult = pendingAnalysisResult, pendingPersonalizedData == nil {
            #if DEBUG
            print("🔴 NotificationManager: Timeout reached - presenting DefaultSeasonView as fallback")
            #endif
            presentDefaultSeasonView(with: analysisResult)
            clearPendingData()
        } else {
            #if DEBUG
            print("🟢 NotificationManager: Personalization completed within timeout - no need for fallback")
            #endif
        }
    }
    
    private func presentPersonalizedSeasonView(with personalizedData: PersonalizedSeasonData) {
        guard let viewController = viewController else { return }
        
        DispatchQueue.main.async {
            SeasonViewNavigationManager.presentPersonalizedSeasonView(
                from: viewController,
                personalizedData: personalizedData
            )
        }
    }
    
    private func presentDefaultSeasonView(with analysisResult: AnalysisResult) {
        guard let viewController = viewController else { return }
        
        DispatchQueue.main.async {
            SeasonViewNavigationManager.presentDefaultSeasonView(
                from: viewController,
                analysisResult: analysisResult
            )
        }
    }
    
    private func clearPendingData() {
        pendingAnalysisResult = nil
        pendingPersonalizedData = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }
}

// MARK: - Static Notification Posting Helpers

extension NotificationManager {
    
    /// Post analysis result ready notification
    /// - Parameters:
    ///   - result: The analysis result
    ///   - sender: The object posting the notification
    static func postAnalysisResult(_ result: AnalysisResult, from sender: AnyObject) {
        NotificationCenter.default.post(
            name: analysisResultReady,
            object: sender,
            userInfo: ["result": result]
        )
    }
    
    /// Post personalization ready notification
    /// - Parameters:
    ///   - personalizedData: The personalized data
    ///   - sender: The object posting the notification
    static func postPersonalizationReady(_ personalizedData: PersonalizedSeasonData, from sender: AnyObject) {
        NotificationCenter.default.post(
            name: personalizationReady,
            object: sender,
            userInfo: ["personalizedData": personalizedData]
        )
    }
    
    /// Post personalization failed notification
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - fallbackResult: The fallback analysis result
    ///   - sender: The object posting the notification
    static func postPersonalizationFailed(_ error: Error, fallbackResult: AnalysisResult, from sender: AnyObject) {
        NotificationCenter.default.post(
            name: personalizationFailed,
            object: sender,
            userInfo: [
                "error": error,
                "fallbackResult": fallbackResult
            ]
        )
    }
} 