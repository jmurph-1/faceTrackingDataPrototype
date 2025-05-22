// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import CoreGraphics
import MediaPipeTasksVision
import AVFoundation
import Metal
import MetalKit

class FaceLandmarkRenderer: RendererProtocol {
    
    var description: String = "Face Landmark Renderer"
    var isPrepared = false
    
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private var renderPipelineState: MTLRenderPipelineState?
    private var useMetalRendering = false
    private var outputFormatDescription: CMFormatDescription?

    // Default colors for different landmark types
    private let landmarkColor = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
    private let meshLinesColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.7)
    private let contourColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.8)
    private let landmarkIDColor = UIColor.yellow
    private let polygonColor = UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.8)

    // Configuration options
    var showLandmarks: Bool = true
    var showMesh: Bool = true
    var showContours: Bool = true
    var landmarkSize: Float = 3.0
    var highlightedLandmarkIndices: Set<Int>? = nil

    init() {
        // Initialize Metal if available, otherwise use CoreGraphics-only approach
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            setupPipeline()
        } else {
            self.device = nil
            self.commandQueue = nil
            print("Metal not available, falling back to Core Graphics rendering")
        }
    }

    private func setupPipeline() {
        // Setup Metal rendering pipeline
        guard let library = device?.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }

        // First check if the shader functions exist in the library
        guard let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
            print("Failed to find required shader functions. Metal rendering will be disabled.")
            return
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            renderPipelineState = try device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }

    // Render face landmarks using Core Graphics
    func renderFaceLandmarks(on pixelBuffer: CVPixelBuffer, faceLandmarks: [NormalizedLandmark], completion: @escaping (UIImage?) -> Void) {
        guard !faceLandmarks.isEmpty else {
            completion(nil)
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let viewportSize = CGSize(width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(viewportSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            completion(nil)
            return
        }

        // Clear background
        context.clear(CGRect(origin: .zero, size: viewportSize))

        // Draw landmarks and connections
        if showLandmarks {
            drawPoints(context: context,
                       landmarks: faceLandmarks,
                       viewportSize: viewportSize,
                       color: landmarkColor)
        }

        if showMesh {
            drawConnections(context: context,
                            landmarks: faceLandmarks,
                            connections: MediaPipeFaceMesh.faceOval,
                            viewportSize: viewportSize,
                            color: contourColor)

            drawConnections(context: context,
                            landmarks: faceLandmarks,
                            connections: MediaPipeFaceMesh.leftEye,
                            viewportSize: viewportSize,
                            color: meshLinesColor)

            drawConnections(context: context,
                            landmarks: faceLandmarks,
                            connections: MediaPipeFaceMesh.rightEye,
                            viewportSize: viewportSize,
                            color: meshLinesColor)

            drawConnections(context: context,
                            landmarks: faceLandmarks,
                            connections: MediaPipeFaceMesh.lips,
                            viewportSize: viewportSize,
                            color: meshLinesColor)
        }
        
        // Draw polygon outlines
        drawPolygonOutlines(context: context,
                           landmarks: faceLandmarks,
                           viewportSize: viewportSize)

        let outputImage = UIGraphicsGetImageFromCurrentImageContext()
        completion(outputImage)
    }

    // Draw landmark IDs only for specified highlightedLandmarkIndices
    private func drawPoints(
        context: CGContext,
        landmarks: [NormalizedLandmark],
        viewportSize: CGSize,
        color: UIColor
    ) {
        // Only draw indices that are highlighted if set
        if let indicesToDraw = highlightedLandmarkIndices {
            context.setFillColor(UIColor.yellow.cgColor) // Highlight color
            
            for (index, landmark) in landmarks.enumerated() where indicesToDraw.contains(index) {
                let point = CGPoint(
                    x: CGFloat(landmark.x) * viewportSize.width,
                    y: CGFloat(landmark.y) * viewportSize.height
                )
                
                // Draw landmark ID
                let text = "\(index)" as NSString
                let attributes = [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                    NSAttributedString.Key.foregroundColor: UIColor.yellow
                ]
                
                text.draw(at: point, withAttributes: attributes)
            }
        }
        
        // Draw all points normally
        context.setFillColor(color.cgColor)
        for landmark in landmarks {
            let point = CGPoint(
                x: CGFloat(landmark.x) * viewportSize.width,
                y: CGFloat(landmark.y) * viewportSize.height
            )
            
            let rect = CGRect(
                x: point.x - CGFloat(landmarkSize/2),
                y: point.y - CGFloat(landmarkSize/2),
                width: CGFloat(landmarkSize),
                height: CGFloat(landmarkSize)
            )
            
            context.fillEllipse(in: rect)
        }
    }

    // Draw connections between landmarks
    private func drawConnections(
        context: CGContext,
        landmarks: [NormalizedLandmark],
        connections: [(Int, Int)],
        viewportSize: CGSize,
        color: UIColor
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)

        for connection in connections {
            let start = connection.0
            let end = connection.1

            guard start < landmarks.count && end < landmarks.count else {
                continue
            }

            let startPoint = CGPoint(
                x: CGFloat(landmarks[start].x) * viewportSize.width,
                y: CGFloat(landmarks[start].y) * viewportSize.height
            )

            let endPoint = CGPoint(
                x: CGFloat(landmarks[end].x) * viewportSize.width,
                y: CGFloat(landmarks[end].y) * viewportSize.height
            )

            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }

        context.restoreGState()
    }

    // Draw polygon outlines
    private func drawPolygonOutlines(
        context: CGContext,
        landmarks: [NormalizedLandmark],
        viewportSize: CGSize
    ) {
        // Define the three polygons
        let leftCheekIndices = [117, 118, 101, 36, 205, 187, 123]
        let rightCheekIndices = [348, 347, 346, 280, 425, 266, 371, 329]
        let foreheadIndices = [10, 338, 297, 299, 337, 9, 108, 69, 67, 109] 
        
        context.saveGState()
        context.setStrokeColor(polygonColor.cgColor)
        context.setLineWidth(2.0)
        
        let polygons = [leftCheekIndices, rightCheekIndices, foreheadIndices]
        
        for indices in polygons {
            guard !indices.isEmpty else { continue }
            
            // Move to first point
            if let firstIndex = indices.first, firstIndex < landmarks.count {
                let firstPoint = CGPoint(
                    x: CGFloat(landmarks[firstIndex].x) * viewportSize.width,
                    y: CGFloat(landmarks[firstIndex].y) * viewportSize.height
                )
                context.move(to: firstPoint)
            }
            
            // Draw lines to subsequent points
            for index in indices.dropFirst() {
                guard index < landmarks.count else { continue }
                let point = CGPoint(
                    x: CGFloat(landmarks[index].x) * viewportSize.width,
                    y: CGFloat(landmarks[index].y) * viewportSize.height
                )
                context.addLine(to: point)
            }
            
            // Close the polygon
            if let firstIndex = indices.first, firstIndex < landmarks.count {
                let firstPoint = CGPoint(
                    x: CGFloat(landmarks[firstIndex].x) * viewportSize.width,
                    y: CGFloat(landmarks[firstIndex].y) * viewportSize.height
                )
                context.addLine(to: firstPoint)
            }
            
            context.strokePath()
        }
        
        context.restoreGState()
    }

    // Metal-based rendering for better performance (alternative to Core Graphics)
    func renderFaceLandmarks(on texture: MTLTexture, faceLandmarks: [NormalizedLandmark]?) -> MTLTexture? {
        // Implementation for Metal-based rendering
        // This would use the Metal pipeline set up earlier
        return texture
    }
    
    
    func prepare(with formatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int, needChangeWidthHeight: Bool) {
        isPrepared = true
        outputFormatDescription = formatDescription
        setupPipeline()
    }
    
    func render(pixelBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>?) -> CVPixelBuffer? {
        // This renderer doesn't use segmentation data, but instead would use landmarks
        return pixelBuffer
    }
    
    func reset() {
        isPrepared = false
        outputFormatDescription = nil
    }
    
    func handleMemoryWarning() {
    }
}

// MediaPipe Face Mesh connection definitions
struct MediaPipeFaceMesh {
    // These are the indices for connecting landmarks in the face mesh
    static let faceOval: [(Int, Int)] = [
        (10, 338), (338, 297), (297, 332), (332, 284), (284, 251), (251, 389),
        (389, 356), (356, 454), (454, 323), (323, 361), (361, 288), (288, 397),
        (397, 365), (365, 379), (379, 378), (378, 400), (400, 377), (377, 152),
        (152, 148), (148, 176), (176, 149), (149, 150), (150, 136), (136, 172),
        (172, 58), (58, 132), (132, 93), (93, 234), (234, 127), (127, 162),
        (162, 21), (21, 54), (54, 103), (103, 67), (67, 109), (109, 10)
    ]

    static let leftEye: [(Int, Int)] = [
        (33, 7), (7, 163), (163, 144), (144, 145), (145, 153), (153, 154),
        (154, 155), (155, 133), (133, 173), (173, 157), (157, 158), (158, 159),
        (159, 160), (160, 161), (161, 246), (246, 33)
    ]

    static let rightEye: [(Int, Int)] = [
        (362, 382), (382, 398), (398, 384), (384, 385), (385, 386), (386, 387),
        (387, 388), (388, 466), (466, 390), (390, 373), (373, 374), (374, 380),
        (380, 381), (381, 382), (382, 362)
    ]

    static let lips: [(Int, Int)] = [
        (61, 146), (146, 91), (91, 181), (181, 84), (84, 17), (17, 314),
        (314, 405), (405, 321), (321, 375), (375, 291), (291, 409), (409, 270),
        (270, 269), (269, 267), (267, 0), (0, 37), (37, 39), (39, 40), (40, 185)
    ]
}
