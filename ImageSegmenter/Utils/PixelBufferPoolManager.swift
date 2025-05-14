//
//  PixelBufferPoolManager.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/14/25.
//

// Add to a new file: PixelBufferPoolManager.swift
import CoreVideo
import Foundation

class PixelBufferPoolManager {
    static let shared = PixelBufferPoolManager()
    
    private var pixelBufferPools: [String: CVPixelBufferPool] = [:]
    private let queue = DispatchQueue(label: "com.colorAnalysisApp.pixelBufferPool")
    
    // Generate a key for the pool based on buffer properties
    private func keyForPixelBufferPool(width: Int, height: Int, pixelFormat: OSType) -> String {
        return "\\(width)x\\(height)_\\(pixelFormat)"
    }
    
    // Get or create a pixel buffer pool
    func getPool(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA) -> CVPixelBufferPool? {
        let key = keyForPixelBufferPool(width: width, height: height, pixelFormat: pixelFormat)
        
        return queue.sync {
            if let existingPool = pixelBufferPools[key] {
                return existingPool
            } else {
                let attributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                ]
                
                var pixelBufferPool: CVPixelBufferPool?
                let status = CVPixelBufferPoolCreate(
                    kCFAllocatorDefault,
                    nil,
                    attributes as CFDictionary,
                    &pixelBufferPool)
                
                guard status == kCVReturnSuccess, let pool = pixelBufferPool else {
                    print("Failed to create pixel buffer pool: \\(status)")
                    return nil
                }
                
                pixelBufferPools[key] = pool
                return pool
            }
        }
    }
    
    // Get a pixel buffer from a pool
    func getPixelBuffer(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA) -> CVPixelBuffer? {
        guard let pool = getPool(width: width, height: height, pixelFormat: pixelFormat) else {
            return nil
        }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("Failed to create pixel buffer from pool: \\(status)")
            return nil
        }
        
        return buffer
    }
    
    // Clear all pools
    func clearPools() {
        queue.sync {
            pixelBufferPools.removeAll()
        }
    }
}
