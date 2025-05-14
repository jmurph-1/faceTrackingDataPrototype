//
//  TexturePoolManager.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/14/25.
//

import Metal
import Foundation

class TexturePoolManager {
    static let shared = TexturePoolManager()
    
    private var device: MTLDevice
    private var availableTextures: [String: [MTLTexture]] = [:]
    private let queue = DispatchQueue(label: "com.colorAnalysisApp.texturePool")
    
    init(device: MTLDevice = MTLCreateSystemDefaultDevice()!) {
        self.device = device
    }
    
    // Generate a key for the texture cache based on its properties
    private func keyForTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat) -> String {
        return "\\(width)x\\(height)_\\(pixelFormat.rawValue)"
    }
    
    // Get a texture from the pool or create a new one
    func getTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, usage: MTLTextureUsage = [.shaderRead, .shaderWrite]) -> MTLTexture {
        let key = keyForTexture(width: width, height: height, pixelFormat: pixelFormat)
        
        return queue.sync {
            if var textures = availableTextures[key], !textures.isEmpty {
                let texture = textures.removeLast()
                availableTextures[key] = textures
                return texture
            } else {
                // Create a new texture if none available
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: pixelFormat,
                    width: width,
                    height: height,
                    mipmapped: false)
                descriptor.usage = usage
                
                guard let newTexture = device.makeTexture(descriptor: descriptor) else {
                    fatalError("Failed to create texture")
                }
                
                return newTexture
            }
        }
    }
    
    // Return a texture to the pool for reuse
    func recycleTexture(_ texture: MTLTexture) {
        let key = keyForTexture(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat)
        
        queue.sync {
            var textures = availableTextures[key] ?? []
            // Limit pool size to prevent excessive memory usage
            if textures.count < 5 {
                textures.append(texture)
                availableTextures[key] = textures
            }
            // If pool is full, texture will be deallocated naturally
        }
    }
    
    // Clear all cached textures
    func clearCache() {
        queue.sync {
            availableTextures.removeAll()
        }
    }
}
