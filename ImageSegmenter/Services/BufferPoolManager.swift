//
//
//

import Foundation
import Metal

class BufferPoolManager {
    static let shared = BufferPoolManager()

    private var availableBuffers: [String: [MTLBuffer]] = [:]

    private let lock = NSLock()

    private(set) var totalCreated: Int = 0
    private(set) var totalReused: Int = 0

    private var metalDevice: MTLDevice?

    private init() {
        metalDevice = MTLCreateSystemDefaultDevice()
    }

    func getBuffer(length: Int, options: MTLResourceOptions = .storageModeShared) -> MTLBuffer? {
        guard let device = metalDevice else {
            print("No Metal device available")
            return nil
        }

        let roundedLength = nextPowerOfTwo(length)
        let key = "\(roundedLength)x\(options.rawValue)"

        lock.lock()
        defer { lock.unlock() }

        if var sizeBuffers = availableBuffers[key], !sizeBuffers.isEmpty {
            let buffer = sizeBuffers.removeLast()
            availableBuffers[key] = sizeBuffers

            totalReused += 1
            return buffer
        }

        guard let newBuffer = device.makeBuffer(length: roundedLength, options: options) else {
            print("Failed to create buffer in pool")
            return nil
        }

        totalCreated += 1
        return newBuffer
    }

    func recycleBuffer(_ buffer: MTLBuffer) {
        let key = "\(buffer.length)x\(buffer.resourceOptions.rawValue)"

        lock.lock()
        defer { lock.unlock() }

        var sizeBuffers = availableBuffers[key] ?? []

        let maxPoolSize = 10
        if sizeBuffers.count < maxPoolSize {
            sizeBuffers.append(buffer)
            availableBuffers[key] = sizeBuffers
        }
    }

    func clearPool() {
        lock.lock()
        defer { lock.unlock() }

        availableBuffers.removeAll()
    }

    func getStatistics() -> (hitRate: Double, created: Int, reused: Int) {
        lock.lock()
        defer { lock.unlock() }

        let total = totalCreated + totalReused
        let hitRate = total > 0 ? Double(totalReused) / Double(total) : 0.0

        return (hitRate: hitRate, created: totalCreated, reused: totalReused)
    }

    private func nextPowerOfTwo(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }
}
