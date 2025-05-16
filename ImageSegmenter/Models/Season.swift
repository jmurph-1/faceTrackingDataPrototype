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
            let eyes: FeatureDescription
            let skin: FeatureDescription
            let hair: FeatureDescription
            let contrast: Contrast
            
            struct FeatureDescription: Decodable {
                let description: String
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
        
        struct ColorAspect: Decodable {
            let value: String
            let explanation: String
        }
        
        struct SisterPalettes: Decodable {
            let description: String
            let sisters: [String]
        }
    }
    
    struct Styling: Decodable {
        let neutrals: StyleDescription
        let colorsToAvoid: ColorsToAvoid
        
        struct StyleDescription: Decodable {
            let description: String
        }
        
        struct ColorsToAvoid: Decodable {
            let description: String
            let colors: [String]?
        }
    }
}
