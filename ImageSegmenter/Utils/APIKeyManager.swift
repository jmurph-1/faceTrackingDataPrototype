//
//  APIKeyManager.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import Security

class APIKeyManager {
    
    // MARK: - Constants
    
    private static let keychainService = "com.season13.apikeys"
    private static let openAIKeyAccount = "openai_api_key"
    
    // MARK: - Public Methods
    
    /// Check if a valid OpenAI API key is stored
    static var hasValidKey: Bool {
        return getOpenAIKey() != nil && !getOpenAIKey()!.isEmpty
    }
    
    /// Get the stored OpenAI API key
    static func getOpenAIKey() -> String? {
        return getKeychainValue(account: openAIKeyAccount)
    }
    
    /// Store the OpenAI API key securely
    /// - Parameter key: The API key to store
    /// - Returns: True if successfully stored
    @discardableResult
    static func setOpenAIKey(_ key: String) -> Bool {
        // Validate key format (OpenAI keys start with "sk-")
        guard key.hasPrefix("sk-") && key.count > 20 else {
            return false
        }
        
        return setKeychainValue(key, account: openAIKeyAccount)
    }
    
    /// Remove the stored OpenAI API key
    /// - Returns: True if successfully removed
    @discardableResult
    static func removeOpenAIKey() -> Bool {
        return deleteKeychainValue(account: openAIKeyAccount)
    }
    
    /// Test if the API key is valid by making a simple API call
    /// - Parameters:
    ///   - key: The API key to test
    ///   - completion: Completion handler with success boolean and optional error
    static func validateOpenAIKey(_ key: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            completion(false, APIKeyError.invalidURL)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, APIKeyError.invalidResponse)
                    return
                }
                
                // API key is valid if we get a 200 response
                completion(httpResponse.statusCode == 200, nil)
            }
        }.resume()
    }
    
    // MARK: - Private Keychain Methods
    
    private static func setKeychainValue(_ value: String, account: String) -> Bool {
        let data = value.data(using: .utf8)!
        
        // First try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        if updateStatus == errSecSuccess {
            return true
        }
        
        // If update failed, try to add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }
    
    private static func getKeychainValue(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private static func deleteKeychainValue(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Errors

enum APIKeyError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidKeyFormat
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response"
        case .invalidKeyFormat:
            return "Invalid API key format. OpenAI keys should start with 'sk-'"
        case .networkError:
            return "Network error occurred"
        }
    }
}

