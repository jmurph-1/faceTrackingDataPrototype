//
//
//

import Foundation
import CoreVideo
import CoreMedia

class PixelBufferPoolManager {
    static let shared = PixelBufferPoolManager()
    
    private var pixelBufferPools: [String: CVPixelBufferPool] = [:]
    private var formatDescriptions: [String: CMFormatDescription] = [:]
    
    private let lock = NSLock()
    
    private(set) var totalCreated: Int = 0
    private(set) var totalReused: Int = 0
    
    private init() {}
    
    func getPixelBuffer(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA) -> CVPixelBuffer? {
        let key = "\(width)x\(height)x\(pixelFormat)"
        
        lock.lock()
        defer { lock.unlock() }
        
        if let pool = pixelBufferPools[key] {
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            
            if status == kCVReturnSuccess, let buffer = pixelBuffer {
                totalReused += 1
                return buffer
            }
        }
        
        if createPixelBufferPool(width: width, height: height, pixelFormat: pixelFormat, key: key) {
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPools[key]!, &pixelBuffer)
            
            if status == kCVReturnSuccess, let buffer = pixelBuffer {
                totalCreated += 1
                return buffer
            }
        }
        
        print("Failed to create pixel buffer from pool")
        return nil
    }
    
    private func createPixelBufferPool(width: Int, height: Int, pixelFormat: OSType, key: String) -> Bool {
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey as String: 3]
        
        var pixelBufferPool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                            poolAttributes as CFDictionary,
                                            pixelBufferAttributes as CFDictionary,
                                            &pixelBufferPool)
        
        guard status == kCVReturnSuccess, let pool = pixelBufferPool else {
            print("Failed to create pixel buffer pool with status: \(status)")
            return false
        }
        
        var formatDescription: CMFormatDescription?
        var pixelBuffer: CVPixelBuffer?
        
        if CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
           let buffer = pixelBuffer {
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                        imageBuffer: buffer,
                                                        formatDescriptionOut: &formatDescription)
            CVPixelBufferRelease(buffer)
        }
        
        pixelBufferPools[key] = pool
        if let formatDesc = formatDescription {
            formatDescriptions[key] = formatDesc
        }
        
        preallocatePixelBuffers(pool: pool, count: 3)
        
        return true
    }
    
    private func preallocatePixelBuffers(pool: CVPixelBufferPool, count: Int) {
        var pixelBuffers: [CVPixelBuffer] = []
        
        for _ in 0..<count {
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            
            if status == kCVReturnSuccess, let buffer = pixelBuffer {
                pixelBuffers.append(buffer)
            }
        }
        
        pixelBuffers.removeAll()
    }
    
    func getFormatDescription(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA) -> CMFormatDescription? {
        let key = "\(width)x\(height)x\(pixelFormat)"
        
        lock.lock()
        defer { lock.unlock() }
        
        if let formatDescription = formatDescriptions[key] {
            return formatDescription
        }
        
        if createPixelBufferPool(width: width, height: height, pixelFormat: pixelFormat, key: key) {
            return formatDescriptions[key]
        }
        
        return nil
    }
    
    func clearPools() {
        lock.lock()
        defer { lock.unlock() }
        
        pixelBufferPools.removeAll()
        formatDescriptions.removeAll()
        
        totalCreated = 0
        totalReused = 0
    }
    
    func getStatistics() -> (hitRate: Double, created: Int, reused: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let total = totalCreated + totalReused
        let hitRate = total > 0 ? Double(totalReused) / Double(total) : 0.0
        
        return (hitRate: hitRate, created: totalCreated, reused: totalReused)
    }
}
