//
//  VectorStoreManager.swift
//  ImageSegmenter
//
//  Created by Claude Code on 12/30/24.
//

import Foundation

// MARK: - VectorStoreManager

/// Manages vector store setup and validation for enhanced personalization
class VectorStoreManager {

    // MARK: - Singleton

    static let shared = VectorStoreManager()
    private init() {}

    // MARK: - Properties

    private let vectorStoreService = VectorStoreService()
    private var setupInProgress = false

    // MARK: - Public Methods

    /// Setup vector store if needed and not already in progress
    /// - Parameters:
    ///   - force: Force setup even if vector store already exists
    ///   - completion: Completion handler with setup result
    func setupVectorStoreIfNeeded(
        force: Bool = false,
        completion: @escaping (Result<String, VectorStoreError>) -> Void
    ) {
        // Check if already in progress
        guard !setupInProgress else {
            completion(.failure(.requestCreationFailed)) // Use as "already in progress" error
            return
        }

        // Check if already configured and not forcing
        if !force, AppConfiguration.shared.hasVectorStore {
            if let existingId = AppConfiguration.shared.getVectorStoreId() {
                completion(.success(existingId))
                return
            }
        }

        // Check prerequisites
        guard AppConfiguration.shared.hasPersonalizationSupport,
              let apiKey = AppConfiguration.shared.getOpenAIKey() else {
            completion(.failure(.noFilesFound)) // Use as "no API key" error
            return
        }

        setupInProgress = true

        #if DEBUG
        print("🔵 VectorStoreManager: Starting vector store setup...")
        #endif

        vectorStoreService.setupVectorStore(apiKey: apiKey) { [weak self] result in
            DispatchQueue.main.async {
                self?.setupInProgress = false

                switch result {
                case .success(let vectorStoreId):
                    #if DEBUG
                    print("🟢 VectorStoreManager: Vector store setup successful: \(vectorStoreId)")
                    #endif

                    // Store the vector store ID
                    AppConfiguration.shared.setVectorStoreId(vectorStoreId)
                    completion(.success(vectorStoreId))

                case .failure(let error):
                    #if DEBUG
                    print("🔴 VectorStoreManager: Vector store setup failed: \(error)")
                    #endif
                    completion(.failure(error))
                }
            }
        }
    }

    /// Validate that the current vector store is still accessible
    /// - Parameters:
    ///   - completion: Completion handler with validation result
    func validateCurrentVectorStore(
        completion: @escaping (Result<Bool, VectorStoreError>) -> Void
    ) {
        guard let vectorStoreId = AppConfiguration.shared.getVectorStoreId(),
              let apiKey = AppConfiguration.shared.getOpenAIKey() else {
            completion(.success(false))
            return
        }

        vectorStoreService.validateVectorStore(
            vectorStoreId: vectorStoreId,
            apiKey: apiKey
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let isValid):
                    if !isValid {
                        #if DEBUG
                        print("🔴 VectorStoreManager: Vector store \(vectorStoreId) is no longer valid")
                        #endif
                        // Clear invalid vector store ID
                        AppConfiguration.shared.setVectorStoreId("")
                    }
                    completion(.success(isValid))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// Get setup status information
    var setupStatus: VectorStoreSetupStatus {
        if !AppConfiguration.shared.hasPersonalizationSupport {
            return .noAPIKey
        }

        if setupInProgress {
            return .settingUp
        }

        if AppConfiguration.shared.hasVectorStore {
            return .ready
        }

        return .notSetup
    }

    /// Clear current vector store configuration
    func clearVectorStore() {
        AppConfiguration.shared.setVectorStoreId("")
        #if DEBUG
        print("🟡 VectorStoreManager: Vector store configuration cleared")
        #endif
    }

    // MARK: - Development Helpers

    #if DEBUG
    /// Force setup vector store (debug builds only)
    func debugForceSetup(completion: @escaping (Result<String, VectorStoreError>) -> Void) {
        setupVectorStoreIfNeeded(force: true, completion: completion)
    }

    /// Print vector store status (debug builds only)
    func printSetupStatus() {
        print("\n🔧 Vector Store Manager Status:")
        print("Setup Status: \(setupStatus.description)")
        print("Has Vector Store: \(AppConfiguration.shared.hasVectorStore)")
        print("Setup In Progress: \(setupInProgress)")

        if let vectorStoreId = AppConfiguration.shared.getVectorStoreId() {
            let maskedId = String(vectorStoreId.prefix(7)) + "..." + String(vectorStoreId.suffix(4))
            print("Vector Store ID: \(maskedId)")
        } else {
            print("Vector Store ID: Not configured")
        }
        print("")
    }

    /// Auto-setup vector store if API key is available (debug builds only)
    func debugAutoSetupIfPossible() {
        if setupStatus == .notSetup {
            print("🔧 VectorStoreManager: Auto-setting up vector store for development...")
            setupVectorStoreIfNeeded { result in
                switch result {
                case .success(let id):
                    print("🟢 VectorStoreManager: Auto-setup successful: \(id)")
                case .failure(let error):
                    print("🔴 VectorStoreManager: Auto-setup failed: \(error)")
                }
            }
        }
    }
    #endif
}

// MARK: - VectorStoreSetupStatus

enum VectorStoreSetupStatus {
    case noAPIKey
    case notSetup
    case settingUp
    case ready

    var description: String {
        switch self {
        case .noAPIKey:
            return "No API Key"
        case .notSetup:
            return "Not Setup"
        case .settingUp:
            return "Setting Up..."
        case .ready:
            return "Ready"
        }
    }

    var needsSetup: Bool {
        return self == .notSetup
    }
}
