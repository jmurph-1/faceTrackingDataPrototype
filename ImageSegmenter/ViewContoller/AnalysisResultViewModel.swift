import Foundation
import UIKit
import Combine

/// View model for analysis results
class AnalysisResultViewModel: ObservableObject {
    
    // MARK: - Published properties
    
    /// Current analysis result
    @Published var currentResult: AnalysisResult?
    
    /// All saved results
    @Published var savedResults: [AnalysisResult] = []
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Error state
    @Published var errorMessage: String?
    
    // MARK: - Services
    
    private let coreDataManager = CoreDataManager.shared
    
    // MARK: - Initialization
    
    init() {
        loadSavedResults()
    }
    
    // MARK: - Public methods
    
    /// Update with a new analysis result
    /// - Parameter result: The analysis result
    func updateWithResult(_ result: AnalysisResult) {
        self.currentResult = result
    }
    
    /// Save the current result
    /// - Returns: Success or failure
    func saveCurrentResult() -> Bool {
        guard let result = currentResult else { return false }
        
        isLoading = true
        
        let success = coreDataManager.saveAnalysisResult(result)
        
        if success {
            loadSavedResults()
        } else {
            errorMessage = "Failed to save result"
        }
        
        isLoading = false
        return success
    }
    
    /// Load all saved results
    func loadSavedResults() {
        isLoading = true
        
        savedResults = coreDataManager.fetchAllAnalysisResults()
        
        isLoading = false
    }
    
    /// Delete a result by date
    /// - Parameter date: The date of the result to delete
    /// - Returns: Success or failure
    func deleteResult(with date: Date) -> Bool {
        isLoading = true
        
        let success = coreDataManager.deleteAnalysisResult(with: date)
        
        if success {
            loadSavedResults()
        } else {
            errorMessage = "Failed to delete result"
        }
        
        isLoading = false
        return success
    }
    
    /// Check if result is saved
    /// - Parameter result: The analysis result
    /// - Returns: True if the result is saved
    func isResultSaved(_ result: AnalysisResult) -> Bool {
        return savedResults.contains { $0.date == result.date }
    }
    
    /// Clear the current result
    func clearCurrentResult() {
        currentResult = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
} 