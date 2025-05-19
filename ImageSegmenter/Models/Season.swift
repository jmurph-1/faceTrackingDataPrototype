// Season.swift
// Existing code at the top...

import Foundation
import SwiftUI

struct Season: Identifiable, Decodable {
    var id: String { name }
    let name: String
    let tagline: String
    let introduction: String
    let characteristics: Characteristics
    let palette: Palette
    let styling: Styling
    
    struct Characteristics: Decodable {
        let note: String
        let overview: String
        let features: Features
        
        struct Features: Decodable {
            let eyes: EyeFeatureDescription
            let skin: SkinFeatureDescription
            let hair: HairFeatureDescription
            let contrast: Contrast
            
            struct EyeFeatureDescription: Decodable {
                let description: String
                let eyeColors: [String]?
                let image: String?
            }
            
            struct SkinFeatureDescription: Decodable {
                let description: String
                let skinTones: [String: [String]]?
                let image: String?
            }
            
            struct HairFeatureDescription: Decodable {
                let description: String
                let hairColors: [String: [String]]?
                let image: String?
            }
            
            struct Contrast: Decodable {
                let value: String
                let description: String
            }
        }
    }
    
    struct Palette: Decodable {
        let description: String
        let hue: ColorAspect
        let value: ColorAspect
        let chroma: ColorAspect
        let sisterPalettes: SisterPalettes
        let paletteImgUrl: String?

        struct ColorAspect: Decodable {
            let value: String
            let explanation: String
        }
        
        struct SisterPalettes: Decodable {
            let description: String
            let sisters: [String]
            let image: String?
        }
    }
    
    struct Styling: Decodable {
        let neutrals: StyleDescription
        let colorsToAvoid: ColorsToAvoid
        let colorCombinations: ColorCombinationsDetail?
        let patternsAndPrints: PatternsAndPrintsDetail?
        let metalsAndAccessories: MetalsAndAccessoriesDetail?

        struct StyleDescription: Decodable {
            let description: String
            let image: String?
        }
        
        struct ColorsToAvoid: Decodable {
            let description: String
            let colors: [String]?
            let image: String?
        }

        struct ColorCombinationsDetail: Decodable {
            let description: String?
            let combinations: [[String]]?
            let image: String?
        }

        struct PatternsAndPrintsDetail: Decodable {
            let description: String?
            let color: PatternsAndPrintsAspect?
            let contrast: PatternsAndPrintsAspect?
            let elements: PatternsAndPrintsElementsAspect?
        }

        struct PatternsAndPrintsAspect: Decodable {
            let description: String?
            let combinations: [String: [String]]?
            let image: String?
        }
        
        struct PatternsAndPrintsElementsAspect: Decodable {
            let description: String?
            let combinations: [String: [String]]?
            let image: String?
        }

        struct MetalsAndAccessoriesDetail: Decodable {
            let description: String?
            let metals: MetalsDetail?
            let stones: StonesDetail?
            let image: String?
        }

        struct MetalsDetail: Decodable {
            let type: [String: String]?
            let finish: [String: String]?
        }

        struct StonesDetail: Decodable {
            let description: String?
            let stones: [String]?
        }
    }
}
// End of file
