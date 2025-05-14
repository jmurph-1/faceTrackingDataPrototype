//
//
//

import Foundation
import Metal

class TexturePoolManager {
    static let shared = TexturePoolManager()
    
    private var availableTextures: [MTLPixelFormat: [String: [MTLTexture]]] = [:]
    
    private let lock = NSLock()
    
    private(set) var totalCreated: Int = 0
    private(set) var totalReused: Int = 0
    
    private init() {}
    
    func getTexture(
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite],
        device: MTLDevice
    ) -> MTLTexture? {
        let key = "\(width)x\(height)x\(usage.rawValue)"
        
        lock.lock()
        defer { lock.unlock() }
        
        if var formatTextures = availableTextures[pixelFormat],
           var sizeTextures = formatTextures[key],
           !sizeTextures.isEmpty {
            
            let texture = sizeTextures.removeLast()
            formatTextures[key] = sizeTextures
            availableTextures[pixelFormat] = formatTextures
            
            totalReused += 1
            return texture
        }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = usage
        
        guard let newTexture = device.makeTexture(descriptor: textureDescriptor) else {
            print("Failed to create texture in pool")
            return nil
        }
        
        totalCreated += 1
        return newTexture
    }
    
    func recycleTexture(_ texture: MTLTexture) {
        let key = "\(texture.width)x\(texture.height)x\(texture.usage.rawValue)"
        
        lock.lock()
        defer { lock.unlock() }
        
        var formatTextures = availableTextures[texture.pixelFormat] ?? [:]
        var sizeTextures = formatTextures[key] ?? []
        
        let maxPoolSize = 10
        if sizeTextures.count < maxPoolSize {
            sizeTextures.append(texture)
            formatTextures[key] = sizeTextures
            availableTextures[texture.pixelFormat] = formatTextures
        }
    }
    
    func clearPool() {
        lock.lock()
        defer { lock.unlock() }
        
        availableTextures.removeAll()
    }
    
    func getStatistics() -> (hitRate: Double, created: Int, reused: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let total = totalCreated + totalReused
        let hitRate = total > 0 ? Double(totalReused) / Double(total) : 0.0
        
        return (hitRate: hitRate, created: totalCreated, reused: totalReused)
    }
}
