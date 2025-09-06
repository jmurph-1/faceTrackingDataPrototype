#!/usr/bin/env swift

import Foundation

// Test if our models can decode the actual API response
let jsonString = """
{
  "id": "resp_68b66c453c34819481b9b474ead6897d03e3a2807282506e",
  "object": "response",
  "created_at": 1756785733,
  "status": "completed",
  "model": "gpt-4o-2024-08-06",
  "output": [
    {
      "id": "msg_68b66c49b2f88194a74537af449ed23503e3a2807282506e",
      "type": "message",
      "status": "completed",
      "content": [
        {
          "type": "output_text",
          "annotations": [],
          "logprobs": [],
          "text": "{\\"test\\": \\"value\\"}"
        }
      ],
      "role": "assistant"
    }
  ],
  "usage": {
    "input_tokens": 19267,
    "output_tokens": 418,
    "total_tokens": 19685
  }
}
"""

// Minimal models for testing
struct TestResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let output: [TestOutputEvent]
    let usage: TestUsage?

    enum CodingKeys: String, CodingKey {
        case id, object, model, output, usage
        case created = "created_at"
    }
}

struct TestOutputEvent: Codable {
    let id: String?
    let type: String
    let status: String?
    let content: [TestOutputContent]?
    let role: String?
}

struct TestOutputContent: Codable {
    let type: String
    let text: String?
    let annotations: [String]?
    let logprobs: [String]?
}

struct TestUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

guard let data = jsonString.data(using: .utf8) else {
    print("❌ Failed to create data from JSON string")
    exit(1)
}

do {
    let response = try JSONDecoder().decode(TestResponse.self, from: data)
    print("✅ Successfully decoded response!")
    print("   ID: \(response.id)")
    print("   Model: \(response.model)")
    print("   Output events: \(response.output.count)")
    if let usage = response.usage {
        print("   Usage: \(usage.inputTokens) input, \(usage.outputTokens) output")
    }
} catch {
    print("❌ Failed to decode: \(error)")
    if let decodingError = error as? DecodingError {
        print("   Details: \(decodingError)")
    }
}
