//
//  ColorExtractor+Constrants.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/22/25.
//

extension ColorExtractor {
    enum Threshold {
        // brightness low / high for skin pixel acceptance
        static let minSkinBrightness: Float = 20.0
        static let maxSkinBrightness: Float = 240.0

        static let minHairBrightness: Float = 5.0
        static let maxHairBrightness: Float = 250.0
    }
}
