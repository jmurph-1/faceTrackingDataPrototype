//
//
//

import Foundation
import CoreMedia
import CoreVideo
import Metal
import UIKit

protocol RendererProtocol {
    func prepare(
        with formatDescription: CMFormatDescription,
        outputRetainedBufferCountHint: Int,
        needChangeWidthHeight: Bool
    )
    
    func render(pixelBuffer: CVPixelBuffer, segmentDatas: UnsafePointer<UInt8>?) -> CVPixelBuffer?
    
    func reset()
    
    func handleMemoryWarning()
    
    var isPrepared: Bool { get }
    
    var description: String { get }
}

extension RendererProtocol {
    func handleMemoryWarning() {
    }
    
    func prepare(
        with formatDescription: CMFormatDescription,
        outputRetainedBufferCountHint: Int = 3,
        needChangeWidthHeight: Bool = false
    ) {
        prepare(
            with: formatDescription,
            outputRetainedBufferCountHint: outputRetainedBufferCountHint,
            needChangeWidthHeight: needChangeWidthHeight
        )
    }
}
