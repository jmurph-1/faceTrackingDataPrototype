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

import Foundation
import UIKit
import CoreVideo

// MARK: - ClassificationServiceDelegate
protocol ClassificationServiceDelegate: AnyObject {
    func classificationService(_ service: ClassificationService, didCompleteAnalysis result: AnalysisResult)
    func classificationService(_ service: ClassificationService, didFailWithError error: Error)
}

// MARK: - ClassificationService
class ClassificationService {
    // MARK: - Properties
    weak var delegate: ClassificationServiceDelegate?

    // MARK: - Initialization
    init() {}

    // MARK: - Public Methods

    /// Analyze the current frame with the provided color info
    /// - Parameters:
    ///   - pixelBuffer: The current video pixel buffer for thumbnail creation
    ///   - colorInfo: Color information from segmentation
    func analyzeFrame(pixelBuffer: CVPixelBuffer, colorInfo: ColorExtractor.ColorInfo) {
        if colorInfo.skinColor == .clear || colorInfo.hairColor == .clear {
            delegate?.classificationService(self, didFailWithError: ClassificationError.insufficientColorData)
            return
        }

        // Get colors for analysis
        let skinColor = colorInfo.skinColor
        let hairColor = colorInfo.hairColor

        // Convert colors to Lab space
        let skinLab = ColorUtils.convertRGBToLab(color: skinColor)
        let hairLab = ColorUtils.convertRGBToLab(color: hairColor)

        // Perform classification with the season classifier
        let classificationResult = SeasonClassifier.classifySeason(
            skinLab: (skinLab.L, skinLab.a, skinLab.b),
            hairLab: (hairLab.L, hairLab.a, hairLab.b)
        )

        // Create thumbnail from current frame
        let thumbnail = createThumbnailFromPixelBuffer(pixelBuffer)

        // Create analysis result
        let result = AnalysisResult(
            season: classificationResult.season,
            confidence: classificationResult.confidence,
            deltaEToNextClosest: classificationResult.deltaEToNextClosest,
            nextClosestSeason: classificationResult.nextClosestSeason,
            skinColor: skinColor,
            skinColorLab: skinLab,
            hairColor: hairColor,
            hairColorLab: hairLab,
            thumbnail: thumbnail
        )

        // Notify delegate
        delegate?.classificationService(self, didCompleteAnalysis: result)
    }

    // MARK: - Private Methods

    /// Create a thumbnail from a pixel buffer
    /// - Parameter pixelBuffer: CVPixelBuffer to convert
    /// - Returns: UIImage thumbnail
    private func createThumbnailFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - ClassificationError
enum ClassificationError: Error {
    case insufficientColorData
    case analysisFailure
}
