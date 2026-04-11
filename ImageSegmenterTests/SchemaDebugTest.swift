//
//  SchemaDebugTest.swift
//  ImageSegmenterTests
//
//  Created by Claude Code on 1/6/25.
//

import XCTest
@testable import ImageSegmenter

class SchemaDebugTest: XCTestCase {
    
    func testCurrentSchemaContent() throws {
        print("\n" + String(repeating: "=", count: 80))
        print("🔍 DEBUGGING CURRENT SCHEMA CONTENT")
        print(String(repeating: "=", count: 80))
        
        let textFormat = ResponsesAPISchemaFactory.createPersonalizationTextFormat()
        let schema = textFormat.format
        
        print("\n📋 Schema Basic Info:")
        print("   • Type: \(schema.type)")
        print("   • Name: \(schema.name)")
        print("   • Strict: \(schema.strict)")
        
        print("\n📝 Required Fields:")
        for field in schema.schema.required.sorted() {
            print("   • \(field)")
        }
        
        print("\n🔍 Checking for New Fields:")
        let hasSeasonDNA = schema.schema.required.contains("seasonDNA")
        let hasEnhancedColorData = schema.schema.required.contains("enhancedColorData")
        
        print("   • seasonDNA in required: \(hasSeasonDNA ? "✅" : "❌")")
        print("   • enhancedColorData in required: \(hasEnhancedColorData ? "✅" : "❌")")
        
        if !hasSeasonDNA || !hasEnhancedColorData {
            print("\n❌ SCHEMA IS MISSING NEW FIELDS!")
            print("This means the ResponsesAPISchemaProperties is not including the new fields.")
        } else {
            print("\n✅ Schema includes new fields correctly")
        }
        
        // Test serialization to see what's actually being sent
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(textFormat)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            
            print("\n📤 ACTUAL JSON SCHEMA BEING SENT:")
            print(String(repeating: "-", count: 60))
            print(jsonString)
            print(String(repeating: "-", count: 60))
        } catch {
            print("❌ Failed to serialize schema: \(error)")
        }
        
        print(String(repeating: "=", count: 80))
    }
}