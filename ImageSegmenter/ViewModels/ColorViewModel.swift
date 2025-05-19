import Foundation
import SwiftUI

class ColorViewModel: ObservableObject {
    @Published var softSummerColors: [ColorData] = []
    @Published var softSummerSeason: Season?
    
    private let softSummerSeasonName = "Soft Summer"
    
    init() {
        loadColors()
        loadSeason()
    }
    
    func loadColors() {
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json") else {
            print("Colors JSON file not found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let allColors = try JSONDecoder().decode([ColorData].self, from: data)
            softSummerColors = allColors.filter { $0.season == softSummerSeasonName }
        } catch {
            print("Error loading colors: \(error)")
        }
    }
    
    func loadSeason() {
        guard let url = Bundle.main.url(forResource: "softSummer", withExtension: "json") else {
            print("Season JSON file not found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let seasonData = try JSONDecoder().decode([String: Season].self, from: data)
            softSummerSeason = seasonData[softSummerSeasonName]
        } catch {
            print("Error loading season: \(error)")
        }
    }
    
    func colorsByCategory() -> [String: [ColorData]] {
        Dictionary(grouping: softSummerColors, by: { $0.category })
    }
}
