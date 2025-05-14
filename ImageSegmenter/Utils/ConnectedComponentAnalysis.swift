import Foundation
import UIKit

/// Utility for analyzing connected components in segmentation masks
class ConnectedComponentAnalysis {
    
    /// Result of connected component analysis
    struct ComponentInfo {
        let pixelCount: Int
        let boundingBox: CGRect
        let centroid: CGPoint
        let maskBuffer: [Bool]
        let width: Int
        let height: Int
        
        /// Convert to UIImage for visualization (debug purposes)
        func toUIImage() -> UIImage? {
            let bytesPerRow = 4 * width
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                return nil
            }
            
            guard let data = context.data else {
                return nil
            }
            
            let buffer = data.bindMemory(to: UInt32.self, capacity: width * height)
            
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    let pixelIndex = y * width + x
                    
                    // Set white for component pixels, transparent for others
                    if index < maskBuffer.count && maskBuffer[index] {
                        buffer[pixelIndex] = 0xFFFFFFFF  // White
                    } else {
                        buffer[pixelIndex] = 0x00000000  // Transparent
                    }
                }
            }
            
            guard let cgImage = context.makeImage() else {
                return nil
            }
            
            return UIImage(cgImage: cgImage)
        }
    }
    
    /// Find the largest connected component for a given class in the segmentation mask
    /// - Parameters:
    ///   - segmentationMask: The input segmentation mask buffer
    ///   - width: Width of the mask
    ///   - height: Height of the mask
    ///   - targetClass: The class ID to analyze
    /// - Returns: Information about the largest connected component, or nil if none found
    static func findLargestComponent(
        in segmentationMask: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        targetClass: UInt8
    ) -> ComponentInfo? {
        
        // Create a binary mask for the target class
        var binaryMask = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                binaryMask[index] = segmentationMask[index] == targetClass
            }
        }
        
        // Connected component analysis
        var components = findConnectedComponents(in: binaryMask, width: width, height: height)
        
        // Return the largest component
        guard let largestComponent = components.max(by: { $0.pixelCount < $1.pixelCount }) else {
            return nil
        }
        
        return largestComponent
    }
    
    /// Find all connected components in a binary mask
    private static func findConnectedComponents(
        in binaryMask: [Bool],
        width: Int,
        height: Int
    ) -> [ComponentInfo] {
        
        var visited = [Bool](repeating: false, count: width * height)
        var components = [ComponentInfo]()
        
        // 4-way connectivity directions (up, right, down, left)
        let dx = [0, 1, 0, -1]
        let dy = [-1, 0, 1, 0]
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                
                // Skip if already visited or not part of the mask
                if visited[index] || !binaryMask[index] {
                    continue
                }
                
                // BFS to find connected component
                var queue = [(x, y)]
                var component = [Bool](repeating: false, count: width * height)
                var minX = x
                var minY = y
                var maxX = x
                var maxY = y
                var sumX = 0
                var sumY = 0
                var count = 0
                
                visited[index] = true
                component[index] = true
                
                var queueIndex = 0
                while queueIndex < queue.count {
                    let (cx, cy) = queue[queueIndex]
                    queueIndex += 1
                    
                    sumX += cx
                    sumY += cy
                    count += 1
                    
                    // Check neighbors
                    for i in 0..<4 {
                        let nx = cx + dx[i]
                        let ny = cy + dy[i]
                        
                        // Check if within bounds
                        if nx < 0 || nx >= width || ny < 0 || ny >= height {
                            continue
                        }
                        
                        let neighborIndex = ny * width + nx
                        
                        // Check if unvisited and part of the mask
                        if !visited[neighborIndex] && binaryMask[neighborIndex] {
                            visited[neighborIndex] = true
                            component[neighborIndex] = true
                            queue.append((nx, ny))
                            
                            // Update bounding box
                            minX = min(minX, nx)
                            minY = min(minY, ny)
                            maxX = max(maxX, nx)
                            maxY = max(maxY, ny)
                        }
                    }
                }
                
                // Skip tiny components (noise)
                if count < 10 {
                    continue
                }
                
                // Calculate centroid
                let centroidX = CGFloat(sumX) / CGFloat(count)
                let centroidY = CGFloat(sumY) / CGFloat(count)
                
                // Create component info
                let componentInfo = ComponentInfo(
                    pixelCount: count,
                    boundingBox: CGRect(
                        x: minX,
                        y: minY,
                        width: maxX - minX + 1,
                        height: maxY - minY + 1
                    ),
                    centroid: CGPoint(x: centroidX, y: centroidY),
                    maskBuffer: component,
                    width: width,
                    height: height
                )
                
                components.append(componentInfo)
            }
        }
        
        return components
    }
    
    /// Calculate median color from an image using a component mask
    /// - Parameters:
    ///   - image: Source UIImage
    ///   - component: Component info with mask
    /// - Returns: Median color or nil if couldn't be calculated
    static func calculateMedianColor(from image: UIImage, using component: ComponentInfo) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = component.width
        let height = component.height
        
        guard width == cgImage.width && height == cgImage.height else {
            print("Image dimensions don't match component dimensions")
            return nil
        }
        
        guard let data = CFDataCreateMutable(nil, 0) else { return nil }
        CFDataSetLength(data, CFIndex(width * height * 4))
        
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: CFDataGetMutableBytePtr(data),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let context = context else { return nil }
        
        // Draw image to context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Get image data
        let pixelData = CFDataGetBytePtr(data)!
        
        // Collect RGB values from masked pixels
        var redValues = [UInt8]()
        var greenValues = [UInt8]()
        var blueValues = [UInt8]()
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                
                // Check if pixel is part of the component
                if component.maskBuffer[index] {
                    let offset = index * 4
                    redValues.append(pixelData[offset + 0])
                    greenValues.append(pixelData[offset + 1])
                    blueValues.append(pixelData[offset + 2])
                }
            }
        }
        
        // Find median values
        guard !redValues.isEmpty else { return nil }
        
        redValues.sort()
        greenValues.sort()
        blueValues.sort()
        
        let medianIndex = redValues.count / 2
        
        let medianRed = CGFloat(redValues[medianIndex]) / 255.0
        let medianGreen = CGFloat(greenValues[medianIndex]) / 255.0
        let medianBlue = CGFloat(blueValues[medianIndex]) / 255.0
        
        return UIColor(red: medianRed, green: medianGreen, blue: medianBlue, alpha: 1.0)
    }
} 