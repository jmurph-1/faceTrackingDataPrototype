//
//  APIKeyFileManager.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation

/// Manages API keys from local configuration files (for development/testing)
class APIKeyFileManager {
    
    // MARK: - Constants
    
    private static let configFileName = "ApiKeys" // This will be in .gitignore
    private static let configFileExtension = "plist"
    private static let openAIKeyKey = "OPENAI_API_KEY"
    
    // MARK: - Public Methods
    
    /// Load OpenAI API key from configuration file
    /// - Returns: API key if found in config file
    static func loadOpenAIKeyFromFile() -> String? {
        // First, try to load from bundle (easy for developers)
        if let bundleKey = loadFromBundle() {
            return bundleKey
        }
        
        // Fallback to Documents directory approach
        return loadFromDocumentsDirectory()
    }
    
    /// Load API key from app bundle (for development)
    private static func loadFromBundle() -> String? {
        guard let bundlePath = Bundle.main.path(forResource: configFileName, ofType: configFileExtension),
              let configData = NSDictionary(contentsOfFile: bundlePath),
              let apiKey = configData[openAIKeyKey] as? String,
              !apiKey.isEmpty else {
            return nil
        }
        
        // Validate key format
        guard apiKey.hasPrefix("sk-") else {
            print("❌ Invalid OpenAI API key format in bundle config file")
            return nil
        }
        
        print("✅ API key loaded from app bundle")
        return apiKey
    }
    
    /// Load API key from Documents directory (fallback)
    private static func loadFromDocumentsDirectory() -> String? {
        guard let configPath = getConfigFilePath(),
              let configData = NSDictionary(contentsOfFile: configPath),
              let apiKey = configData[openAIKeyKey] as? String,
              !apiKey.isEmpty else {
            // Silently return nil if no API key found - let caller decide whether to show setup instructions
            return nil
        }
        
        // Validate key format
        guard apiKey.hasPrefix("sk-") else {
            print("❌ Invalid OpenAI API key format in Documents config file")
            return nil
        }
        
        print("✅ API key loaded from Documents directory")
        return apiKey
    }
    
    /// Check if config file exists
    /// - Returns: True if config file exists
    static func configFileExists() -> Bool {
        guard let configPath = getConfigFilePath() else { return false }
        return FileManager.default.fileExists(atPath: configPath)
    }
    
    /// Get the path where config file should be located
    /// - Returns: Path to config file
    static func getConfigFilePath() -> String? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let configURL = documentsPath.appendingPathComponent("\(configFileName).\(configFileExtension)")
        return configURL.path
    }
    
    /// Create example config file for developers
    /// - Returns: True if example file was created successfully
    @discardableResult
    static func createExampleConfigFile() -> Bool {
        guard let configPath = getConfigFilePath() else { return false }
        
        // Don't overwrite existing file
        if FileManager.default.fileExists(atPath: configPath) {
            print("Config file already exists at: \(configPath)")
            return true
        }
        
        let exampleConfig: [String: Any] = [
            openAIKeyKey: "sk-your-openai-api-key-here",
            "_instructions": [
                "Replace 'sk-your-openai-api-key-here' with your actual OpenAI API key",
                "This file is in .gitignore and won't be committed to the repository",
                "Get your API key from: https://platform.openai.com/api-keys"
            ]
        ]
        
        let configData = NSDictionary(dictionary: exampleConfig)
        let success = configData.write(toFile: configPath, atomically: true)
        
        if success {
            print("📝 Example config file created at: \(configPath)")
            print("🔑 Please edit this file and add your OpenAI API key")
        } else {
            print("❌ Failed to create example config file")
        }
        
        return success
    }
    
    /// Get instructions for setting up the config file
    /// - Returns: Setup instructions string
    static func getSetupInstructions() -> String {
        let bundleInstructions = """
        
        🔧 API Key Setup Instructions (Recommended):
        
        **Method 1 - Add to Xcode Project (Easy):**
        
        1. In Xcode, right-click on your project and select "Add Files to ImageSegmenter"
        
        2. Create a new file named 'ApiKeys.plist'
        
        3. Add this content to the file:
        
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>\(openAIKeyKey)</key>
            <string>sk-your-actual-openai-api-key-here</string>
        </dict>
        </plist>
        
        4. Make sure to add 'ApiKeys.plist' to your .gitignore file!
        
        5. Get your API key from: https://platform.openai.com/api-keys
        
        """
        
        guard let documentsPath = getConfigFilePath() else {
            return bundleInstructions
        }
        
        let fallbackInstructions = """
        
        **Method 2 - Documents Directory (Alternative):**
        
        Create the file at: \(documentsPath)
        (Same content as above)
        
        Note: This path is in the iOS app sandbox and harder to access.
        
        """
        
        return bundleInstructions + fallbackInstructions
    }
}

// MARK: - Development Helper

#if DEBUG
extension APIKeyFileManager {
    
    /// Set API key in config file for development
    /// - Parameter apiKey: The API key to store
    /// - Returns: True if successfully stored
    static func setDevelopmentAPIKey(_ apiKey: String) -> Bool {
        guard apiKey.hasPrefix("sk-") else {
            print("❌ Invalid API key format")
            return false
        }
        
        guard let configPath = getConfigFilePath() else {
            print("❌ Unable to get config file path")
            return false
        }
        
        let config: [String: Any] = [
            openAIKeyKey: apiKey,
            "_last_updated": Date().description,
            "_note": "This file is automatically managed and in .gitignore"
        ]
        
        let configData = NSDictionary(dictionary: config)
        let success = configData.write(toFile: configPath, atomically: true)
        
        if success {
            print("✅ API key saved to config file")
        } else {
            print("❌ Failed to save API key to config file")
        }
        
        return success
    }
    
    /// Remove config file (for testing)
    static func removeConfigFile() -> Bool {
        guard let configPath = getConfigFilePath() else { return false }
        
        do {
            try FileManager.default.removeItem(atPath: configPath)
            print("🗑️ Config file removed")
            return true
        } catch {
            print("❌ Failed to remove config file: \(error)")
            return false
        }
    }
    
    /// Print current config file status
    static func printConfigStatus() {
        print("\n📋 Config File Status:")
        print("Path: \(getConfigFilePath() ?? "unknown")")
        print("Exists: \(configFileExists())")
        
        if let apiKey = loadOpenAIKeyFromFile() {
            let maskedKey = String(apiKey.prefix(7)) + "..." + String(apiKey.suffix(4))
            print("API Key: \(maskedKey)")
        } else {
            print("API Key: Not found")
        }
        print("")
    }
}
#endif 