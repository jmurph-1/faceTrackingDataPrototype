//
//
//

import Foundation
import AVFoundation
import CoreVideo

class PixelBufferPoolManager {
    static let shared = PixelBufferPoolManager()
    
    private var pixelBufferPools: [String: CVPixelBufferPool] = [:]
    
    private let lock = NSLock()
    
    private(set) var totalCreated: Int = 0
    private(set) var totalReused: Int = 0
    
    private init() {}
    
    func getPixelBuffer(
        width: Int,
        height: Int,
        pixelFormat: OSType = kCVPixelFormatType_32BGRA
    ) -> CVPixelBuffer? {
        let key = "\(width)x\(height)x\(pixelFormat)"
        
        lock.lock()
        defer { lock.unlock() }
        
        var pool = pixelBufferPools[key]
        if pool == nil {
            pool = createPixelBufferPool(width: width, height: height, pixelFormat: pixelFormat)
            if let newPool = pool {
                pixelBufferPools[key] = newPool
            }
        }
        
        guard let pixelBufferPool = pool else {
            print("Failed to create pixel buffer pool")
            return nil
        }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        
        if status == kCVReturnSuccess, let buffer = pixelBuffer {
            totalReused += 1
            return buffer
        } else {
            print("Failed to create pixel buffer from pool: \(status)")
            return nil
        }
    }
    
    private func createPixelBufferPool(
        width: Int,
        height: Int,
        pixelFormat: OSType
    ) -> CVPixelBufferPool? {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        var pixelBufferPool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            nil,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pixelBufferPool
        )
        
        if status != kCVReturnSuccess {
            print("Failed to create pixel buffer pool: \(status)")
            return nil
        }
        
        totalCreated += 1
        return pixelBufferPool
    }
    
    func clearPools() {
        lock.lock()
        defer { lock.unlock() }
        
        pixelBufferPools.removeAll()
    }
    
    func getStatistics() -> (hitRate: Double, created: Int, reused: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let total = totalCreated + totalReused
        let hitRate = total > 0 ? Double(totalReused) / Double(total) : 0.0
        
        return (hitRate: hitRate, created: totalCreated, reused: totalReused)
    }
}
