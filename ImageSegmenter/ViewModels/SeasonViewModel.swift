import SwiftUI
import Combine

class SeasonViewModel: ObservableObject {
    @Published var season: Season?
    @Published var colors: [ColorData] = []
    let seasonName: String // This will remain the display name, e.g., "Dark Autumn"

    init(seasonName: String) {
        self.seasonName = seasonName
        loadSeason()
    }
    
    func loadSeason() {
        print("SeasonViewModel: Attempting to load file for season '\(self.seasonName)' using filename: '\(self.seasonName).json'")
        
        guard let url = Bundle.main.url(forResource: self.seasonName, withExtension: "json") else {
            print("Season JSON file not found in 'Seasons' subdirectory for: '\(self.seasonName).json'")
            self.season = nil
            self.colors = []
            return
        }
        
        print("Season JSON file found in 'Seasons' subdirectory for: '\(self.seasonName).json'")
        decodeSeasonData(from: url)
    }

    private func decodeSeasonData(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let seasonData = try JSONDecoder().decode([String: Season].self, from: data) 
            
            if let loadedSeason = seasonData[self.seasonName] {
                self.season = loadedSeason
                loadColors() 
            } else {
                print("Season data for key '\(self.seasonName)' not found in decoded JSON from file at URL: \(url.path).")
                self.season = nil
                self.colors = []
            }
            
        } catch {
            print("Error loading season \(self.seasonName) (from URL \(url.path)): \(error)")
            self.season = nil
            self.colors = []
        }
    }

    func loadColors() {
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json") else {
            print("Colors JSON file not found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let allColors = try JSONDecoder().decode([ColorData].self, from: data)
            colors = allColors.filter { $0.season == seasonName }
            if colors.isEmpty && !seasonName.isEmpty { // Also check seasonName is not empty
                 print("Warning: No colors found for season '\(seasonName)' after filtering 'colors.json'. Ensure 'colors.json' contains entries with this exact season name.")
            }
        } catch {
            print("Error loading colors: \(error)")
        }
    }

    func colorsByCategory() -> [String: [ColorData]] {
        Dictionary(grouping: colors, by: { $0.category })
    }
}
