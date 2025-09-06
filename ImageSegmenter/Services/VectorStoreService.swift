//
//  VectorStoreService.swift
//  ImageSegmenter
//
//  Created by Claude Code on 12/30/24.
//

import Foundation

// MARK: - VectorStoreService

class VectorStoreService {

    // MARK: - Properties

    private let baseURL = "https://api.openai.com/v1"
    private let timeout: TimeInterval = 60.0

    // MARK: - Public Methods

    /// Create a vector store and upload season documentation files
    /// - Parameters:
    ///   - apiKey: OpenAI API key
    ///   - completion: Completion handler with vector store ID or error
    func setupVectorStore(
        apiKey: String,
        completion: @escaping (Result<String, VectorStoreError>) -> Void
    ) {
        createVectorStore(apiKey: apiKey) { [weak self] result in
            switch result {
            case .success(let vectorStoreId):
                self?.uploadFiles(apiKey: apiKey, vectorStoreId: vectorStoreId) { uploadResult in
                    switch uploadResult {
                    case .success:
                        completion(.success(vectorStoreId))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Validate that a vector store exists and is accessible
    /// - Parameters:
    ///   - vectorStoreId: The vector store ID to validate
    ///   - apiKey: OpenAI API key
    ///   - completion: Completion handler with validation result
    func validateVectorStore(
        vectorStoreId: String,
        apiKey: String,
        completion: @escaping (Result<Bool, VectorStoreError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            switch httpResponse.statusCode {
            case 200:
                completion(.success(true))
            case 404:
                completion(.success(false))
            default:
                completion(.failure(.apiError(httpResponse.statusCode)))
            }
        }.resume()
    }

    // MARK: - Private Methods

    private func createVectorStore(
        apiKey: String,
        completion: @escaping (Result<String, VectorStoreError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/vector_stores") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        let requestBody: [String: Any] = [
            "name": "Season13 Knowledge Base",
            "expires_after": [
                "anchor": "last_active_at",
                "days": 365
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(.requestCreationFailed))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard httpResponse.statusCode == 200 else {
                completion(.failure(.apiError(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let vectorStoreId = json?["id"] as? String else {
                    completion(.failure(.invalidResponseFormat))
                    return
                }

                completion(.success(vectorStoreId))
            } catch {
                completion(.failure(.jsonParsingFailed))
            }
        }.resume()
    }

    private func uploadFiles(
        apiKey: String,
        vectorStoreId: String,
        completion: @escaping (Result<Void, VectorStoreError>) -> Void
    ) {
        // Get file URLs for season docs and colors.json
        let filesToUpload = getKnowledgeFiles()

        guard !filesToUpload.isEmpty else {
            completion(.failure(.noFilesFound))
            return
        }

        let dispatchGroup = DispatchGroup()
        var uploadErrors: [VectorStoreError] = []

        for fileURL in filesToUpload {
            dispatchGroup.enter()

            uploadFile(fileURL: fileURL, apiKey: apiKey, vectorStoreId: vectorStoreId) { result in
                if case .failure(let error) = result {
                    uploadErrors.append(error)
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            if uploadErrors.isEmpty {
                completion(.success(()))
            } else {
                completion(.failure(uploadErrors.first!))
            }
        }
    }

    private func uploadFile(
        fileURL: URL,
        apiKey: String,
        vectorStoreId: String,
        completion: @escaping (Result<String, VectorStoreError>) -> Void
    ) {
        // First upload the file
        uploadFileToOpenAI(fileURL: fileURL, apiKey: apiKey) { [weak self] result in
            switch result {
            case .success(let fileId):
                // Then attach it to the vector store
                self?.attachFileToVectorStore(fileId: fileId, vectorStoreId: vectorStoreId, apiKey: apiKey, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func uploadFileToOpenAI(
        fileURL: URL,
        apiKey: String,
        completion: @escaping (Result<String, VectorStoreError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/files") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        do {
            let fileData = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent

            var body = Data()

            // Add purpose field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
            body.append("assistants\r\n".data(using: .utf8)!)

            // Add file field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

        } catch {
            completion(.failure(.fileReadError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard httpResponse.statusCode == 200 else {
                completion(.failure(.apiError(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let fileId = json?["id"] as? String else {
                    completion(.failure(.invalidResponseFormat))
                    return
                }

                completion(.success(fileId))
            } catch {
                completion(.failure(.jsonParsingFailed))
            }
        }.resume()
    }

    private func attachFileToVectorStore(
        fileId: String,
        vectorStoreId: String,
        apiKey: String,
        completion: @escaping (Result<String, VectorStoreError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)/files") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        let requestBody: [String: Any] = [
            "file_id": fileId
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(.requestCreationFailed))
            return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard httpResponse.statusCode == 200 else {
                completion(.failure(.apiError(httpResponse.statusCode)))
                return
            }

            completion(.success(fileId))
        }.resume()
    }

    private func getKnowledgeFiles() -> [URL] {
        var files: [URL] = []

        guard let bundle = Bundle.main.resourceURL else {
            return files
        }

        // Add colors.json
        let colorsPath = bundle.appendingPathComponent("colors.json")
        if FileManager.default.fileExists(atPath: colorsPath.path) {
            files.append(colorsPath)
        }

        // Find Knowledge directory and add season docs
        let knowledgePath = bundle.appendingPathComponent("Knowledge")
        if FileManager.default.fileExists(atPath: knowledgePath.path) {
            do {
                let knowledgeFiles = try FileManager.default.contentsOfDirectory(
                    at: knowledgePath,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )

                // Add all markdown files from Knowledge directory
                for file in knowledgeFiles where file.pathExtension == "md" {
                    files.append(file)
                }
            } catch {
                #if DEBUG
                print("🔴 VectorStoreService: Could not read Knowledge directory: \(error)")
                #endif
            }
        }

        return files
    }
}

// MARK: - VectorStoreError

enum VectorStoreError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(Int)
    case noData
    case invalidResponseFormat
    case jsonParsingFailed
    case requestCreationFailed
    case fileReadError
    case noFilesFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid API response"
        case .apiError(let code):
            return "API error with status code: \(code)"
        case .noData:
            return "No data received from API"
        case .invalidResponseFormat:
            return "Invalid response format from API"
        case .jsonParsingFailed:
            return "Failed to parse JSON response"
        case .requestCreationFailed:
            return "Failed to create API request"
        case .fileReadError:
            return "Failed to read file"
        case .noFilesFound:
            return "No knowledge files found to upload"
        }
    }
}
