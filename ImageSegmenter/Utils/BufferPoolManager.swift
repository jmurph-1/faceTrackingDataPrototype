//
//  BufferPoolManager.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/14/25.
//

import Metal
import Foundation

class BufferPoolManager {
    static let shared = BufferPoolManager()
    
    private var device: MTLDevice
    private var availableBuffers: [String: [MTLBuffer]] = [:]
    private let queue = DispatchQueue(label: "com.colorAnalysisApp.bufferPool")
    
    init(device: MTLDevice = MTLCreateSystemDefaultDevice()!) {
        self.device = device
    }
    
    // Generate a key for the buffer cache based on its properties
    private func keyForBuffer(length: Int, options: MTLResourceOptions) -> String {
        return "\\(length)_\\(options.rawValue)"
    }
    
    // Get a buffer from the pool or create a new one
    func getBuffer(length: Int, options: MTLResourceOptions = .storageModeShared) -> MTLBuffer {
        let key = keyForBuffer(length: length, options: options)
        
        return queue.sync {
            if var buffers = availableBuffers[key], !buffers.isEmpty {
                let buffer = buffers.removeLast()
                availableBuffers[key] = buffers
                return buffer
            } else {
                // Create a new buffer if none available
                guard let newBuffer = device.makeBuffer(length: length, options: options) else {
                    fatalError("Failed to create buffer")
                }
                
                return newBuffer
            }
        }
    }
    
    // Return a buffer to the pool for reuse
    func recycleBuffer(_ buffer: MTLBuffer) {
        let key = keyForBuffer(length: buffer.length, options: buffer.resourceOptions)
        
        queue.sync {
            var buffers = availableBuffers[key] ?? []
            // Limit pool size to prevent excessive memory usage
            if buffers.count < 5 {
                buffers.append(buffer)
                availableBuffers[key] = buffers
            }
            // If pool is full, buffer will be deallocated naturally
        }
    }
    
    // Clear all cached buffers
    func clearCache() {
        queue.sync {
            availableBuffers.removeAll()
        }
    }
}
