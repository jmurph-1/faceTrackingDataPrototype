//
//  AppConfiguration.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import UIKit

/// Manages app-wide configuration including securely bundled API keys
class AppConfiguration {

    // MARK: - Singleton

    static let shared = AppConfiguration()
    private init() {
        // Load user preferences but don't load API key until needed
        loadUserPreferences()

        // Initialize ColorDatabaseManager and validate database
        DispatchQueue.global(qos: .utility).async {
            let validation = ColorDatabaseManager.shared.validateDatabase()
            #if DEBUG
            DispatchQueue.main.async {
                print("🔧 AppConfiguration: ColorDatabaseManager Validation")
                print(validation.summary)

                // Auto-setup vector store if API key becomes available (development only)
                VectorStoreManager.shared.debugAutoSetupIfPossible() // TODO: Re-enable when VectorStoreManager is added to project
            }
            #endif
        }
    }

    // MARK: - Properties

    private var openAIAPIKey: String?
    private var isAPIKeyLoaded: Bool = false
    private var isPersonalizationEnabled: Bool = false
    private var isDNAPersonalizationEnabled: Bool = false
    private var vectorStoreId: String?

    // MARK: - Public Interface

    /// Whether LLM personalization is available
    var hasPersonalizationSupport: Bool {
        loadAPIKeyIfNeeded()
        return openAIAPIKey != nil && !openAIAPIKey!.isEmpty
    }

    /// Whether DNA personalization is enabled
    var isDNAPersonalizationActive: Bool {
        return isDNAPersonalizationEnabled && hasPersonalizationSupport
    }

    /// Get the OpenAI API key for internal app use
    func getOpenAIKey() -> String? {
        loadAPIKeyIfNeeded()
        return openAIAPIKey
    }

    /// Enable/disable personalization feature
    func setPersonalizationEnabled(_ enabled: Bool) {
        isPersonalizationEnabled = enabled && hasPersonalizationSupport
        UserDefaults.standard.set(isPersonalizationEnabled, forKey: "personalization_enabled")
    }

    /// Enable/disable DNA personalization feature
    func setDNAPersonalizationEnabled(_ enabled: Bool) {
        isDNAPersonalizationEnabled = enabled && hasPersonalizationSupport
        UserDefaults.standard.set(isDNAPersonalizationEnabled, forKey: "dna_personalization_enabled")
    }

    /// Whether personalization is currently enabled
    var isPersonalizationActive: Bool {
        return isPersonalizationEnabled && hasPersonalizationSupport
    }

    /// Get the vector store ID for OpenAI file search
    func getVectorStoreId() -> String? {
        return vectorStoreId
    }

    /// Set the vector store ID (after successful setup)
    func setVectorStoreId(_ id: String) {
        vectorStoreId = id
        UserDefaults.standard.set(id, forKey: "vector_store_id")
    }

    /// Whether vector store is configured for enhanced personalization
    var hasVectorStore: Bool {
        return vectorStoreId != nil && !vectorStoreId!.isEmpty
    }

    // MARK: - Private Methods

    private func loadUserPreferences() {
        // Load user preference for personalization (doesn't require API key check)
        isPersonalizationEnabled = UserDefaults.standard.bool(forKey: "personalization_enabled")

        // Load user preference for DNA personalization
        isDNAPersonalizationEnabled = UserDefaults.standard.bool(forKey: "dna_personalization_enabled")

        // Load vector store ID
        vectorStoreId = UserDefaults.standard.string(forKey: "vector_store_id")
    }

    private func loadAPIKeyIfNeeded() {
        guard !isAPIKeyLoaded else { return }

        // Load from secure configuration
        openAIAPIKey = loadSecureAPIKey()
        isAPIKeyLoaded = true

        // Default to enabled if personalization is available and no preference set
        if UserDefaults.standard.object(forKey: "personalization_enabled") == nil && hasPersonalizationSupport {
            setPersonalizationEnabled(true)
        }

        // Default to enabled for DNA personalization if personalization is available and no preference set
        if UserDefaults.standard.object(forKey: "dna_personalization_enabled") == nil && hasPersonalizationSupport {
            setDNAPersonalizationEnabled(true)
        }
    }

    /// Force reload configuration (for development)
    func reloadConfiguration() {
        isAPIKeyLoaded = false
        openAIAPIKey = nil
        vectorStoreId = nil
        loadUserPreferences()
        loadAPIKeyIfNeeded()
    }

    private func loadSecureAPIKey() -> String? {
        // Use APIKeyManager as the single source of truth for API keys
        // This provides validation, error handling, and consistent keychain access
        if let apiKey = APIKeyManager.getOpenAIKey() {
            return apiKey
        }

        #if DEBUG
        print("🟡 AppConfiguration: No API key in APIKeyManager keychain, checking file...")
        #endif

        // Fallback: Try to load from local file (for development/testing)
        // If found, store it in APIKeyManager for future use
        if let fileKey = APIKeyFileManager.loadOpenAIKeyFromFile() {
            #if DEBUG
            print("🟢 AppConfiguration: API key found in file, storing in APIKeyManager")
            #endif
            APIKeyManager.setOpenAIKey(fileKey) // Store in canonical location
            return fileKey
        }

        // No API key found - print helpful message for developers
        #if DEBUG
        print("🔴 AppConfiguration: No API key found")
        print(APIKeyFileManager.getSetupInstructions())
        #endif

        return nil
    }

}

// MARK: - Development Helper

#if DEBUG
extension AppConfiguration {
    /// Set API key for development/testing (debug builds only)
    func setDevelopmentAPIKey(_ key: String) {
        // Delegate to APIKeyManager for consistent API key management
        APIKeyManager.setOpenAIKey(key)
        // Reload configuration to pick up the new key
        reloadConfiguration()
    }

    /// Set API key using file-based storage (preferred for development)
    func setDevelopmentAPIKeyToFile(_ key: String) {
        APIKeyFileManager.setDevelopmentAPIKey(key)
        // Reload configuration to pick up the new key
        reloadConfiguration()
    }

    /// Create example config file for easy setup
    func createExampleConfigFile() {
        APIKeyFileManager.createExampleConfigFile()
    }

    /// Print current configuration status
    func printConfigurationStatus() {
        print("\n🔧 App Configuration Status:")
        print("Personalization Support: \(hasPersonalizationSupport)")
        print("Personalization Active: \(isPersonalizationActive)")
        print("DNA Personalization Active: \(isDNAPersonalizationActive)")
        print("Vector Store: \(hasVectorStore ? "✅ Configured" : "❌ Not configured")")
        if let storeId = vectorStoreId {
            let maskedStoreId = String(storeId.prefix(7)) + "..." + String(storeId.suffix(4))
            print("Vector Store ID: \(maskedStoreId)")
        }

        // Use APIKeyManager as the single source of truth for API key status
        if let apiKey = APIKeyManager.getOpenAIKey() {
            let maskedKey = String(apiKey.prefix(7)) + "..." + String(apiKey.suffix(4))
            print("API Key: \(maskedKey)")
        } else {
            print("API Key: Not configured")
        }

        // Print database validation status
        let validation = ColorDatabaseManager.shared.validateDatabase()
        print("Color Database: \(validation.isValid ? "✅ Valid" : "❌ Invalid") (\(validation.totalColors) colors)")

        // Print file-based config status
        APIKeyFileManager.printConfigStatus()

        // Print vector store status
        VectorStoreManager.shared.printSetupStatus() // TODO: Re-enable when VectorStoreManager is added to project
    }

    /// Force reload configuration and print status (for debugging)
    func debugReloadAndPrintStatus() {
        print("\n🔧 === DEBUG: Force Reloading Configuration ===")
        reloadConfiguration()
        printConfigurationStatus()
        print("=== END DEBUG ===\n")
    }
}
#endif
