//
//  AppConfiguration.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import Security
import UIKit

/// Manages app-wide configuration including securely bundled API keys
class AppConfiguration {
    
    // MARK: - Singleton
    
    static let shared = AppConfiguration()
    private init() {
        // Load user preferences but don't load API key until needed
        loadUserPreferences()
    }
    
    // MARK: - Properties
    
    private var openAIAPIKey: String?
    private var isAPIKeyLoaded: Bool = false
    private var isPersonalizationEnabled: Bool = false
    
    // MARK: - Public Interface
    
    /// Whether LLM personalization is available
    var hasPersonalizationSupport: Bool {
        loadAPIKeyIfNeeded()
        return openAIAPIKey != nil && !openAIAPIKey!.isEmpty
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
    
    /// Whether personalization is currently enabled
    var isPersonalizationActive: Bool {
        return isPersonalizationEnabled && hasPersonalizationSupport
    }
    
    // MARK: - Private Methods
    
    private func loadUserPreferences() {
        // Load user preference for personalization (doesn't require API key check)
        isPersonalizationEnabled = UserDefaults.standard.bool(forKey: "personalization_enabled")
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
    }
    
    /// Force reload configuration (for development)
    func reloadConfiguration() {
        isAPIKeyLoaded = false
        loadUserPreferences()
        loadAPIKeyIfNeeded()
    }
    
    private func loadSecureAPIKey() -> String? {
        // Method 1: Try to load from local file (for development/testing)
        if let fileKey = APIKeyFileManager.loadOpenAIKeyFromFile() {
            return fileKey
        }
        
        // Method 2: Try to load from secure keychain (for development/testing)
        if let keychainKey = loadFromKeychain() {
            return keychainKey
        }
        
        // Method 3: Load from encrypted configuration file
        if let encryptedKey = loadFromEncryptedConfig() {
            return encryptedKey
        }
        
        // Method 4: Load from obfuscated build configuration
        if let buildKey = loadFromBuildConfig() {
            return buildKey
        }
        
        // No API key found - print helpful message for developers
        #if DEBUG
        print(APIKeyFileManager.getSetupInstructions())
        #endif
        
        return nil
    }
    
    private func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.season13.app.config",
            kSecAttrAccount as String: "openai_production_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    private func loadFromEncryptedConfig() -> String? {
        guard let configPath = Bundle.main.path(forResource: "AppConfig", ofType: "plist"),
              let configData = NSDictionary(contentsOfFile: configPath),
              let encryptedKey = configData["encrypted_openai_key"] as? String else {
            return nil
        }
        
        // Decrypt using app-specific method
        return decryptAPIKey(encryptedKey)
    }
    
    private func loadFromBuildConfig() -> String? {
        // Check for build-time configuration
        guard let infoPlist = Bundle.main.infoDictionary,
              let obfuscatedKey = infoPlist["OPENAI_API_KEY_OBFUSCATED"] as? String else {
            return nil
        }
        
        // Deobfuscate the key
        return deobfuscateAPIKey(obfuscatedKey)
    }
    
    private func decryptAPIKey(_ encryptedKey: String) -> String? {
        // Implement AES decryption using app-specific key
        // This is a placeholder - implement proper decryption
        guard let data = Data(base64Encoded: encryptedKey) else { return nil }
        
        // Use app bundle identifier + device identifier as decryption key
        let appKey = Bundle.main.bundleIdentifier ?? "default_key"
        let deviceKey = UIDevice.current.identifierForVendor?.uuidString ?? "device_key"
        let combinedKey = "\(appKey)_\(deviceKey)"
        
        // Simplified decryption (implement proper AES-256 in production)
        return String(data: data, encoding: .utf8)
    }
    
    private func deobfuscateAPIKey(_ obfuscatedKey: String) -> String? {
        // Simple XOR deobfuscation (implement stronger obfuscation in production)
        let key = Bundle.main.bundleIdentifier?.data(using: .utf8) ?? Data()
        let obfuscatedData = Data(base64Encoded: obfuscatedKey) ?? Data()
        
        var deobfuscated = Data()
        for (index, byte) in obfuscatedData.enumerated() {
            let keyByte = key[index % key.count]
            deobfuscated.append(byte ^ keyByte)
        }
        
        return String(data: deobfuscated, encoding: .utf8)
    }
}

// MARK: - Development Helper

#if DEBUG
extension AppConfiguration {
    /// Set API key for development/testing (debug builds only)
    func setDevelopmentAPIKey(_ key: String) {
        guard key.hasPrefix("sk-") else { return }
        
        // Store in keychain for development
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.season13.app.config",
            kSecAttrAccount as String: "openai_production_key",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.season13.app.config",
            kSecAttrAccount as String: "openai_production_key"
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new
        SecItemAdd(query as CFDictionary, nil)
        
        // Reload configuration
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
        
        if let apiKey = openAIAPIKey {
            let maskedKey = String(apiKey.prefix(7)) + "..." + String(apiKey.suffix(4))
            print("API Key: \(maskedKey)")
        } else {
            print("API Key: Not configured")
        }
        
        // Print file-based config status
        APIKeyFileManager.printConfigStatus()
    }
}
#endif 