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

        // This assumes the JSON files are at the root of the bundle resources.
        guard let url = Bundle.main.url(forResource: self.seasonName, withExtension: "json") else {
            // If still not found, log and then try with the subdirectory as a fallback for debugging
            print("Season JSON file not found for: '\(self.seasonName).json' at bundle root. Trying 'Seasons' subdirectory...")
            
            guard let urlWithSubdirectory = Bundle.main.url(forResource: self.seasonName, withExtension: "json", subdirectory: "Seasons") else {
                 print("Season JSON file also not found in 'Seasons' subdirectory for: '\(self.seasonName).json'")
                 self.season = nil
                 self.colors = []
                 return
            }
            // If found in subdirectory, proceed with that URL
            print("Season JSON file found in 'Seasons' subdirectory for: '\(self.seasonName).json'")
            decodeSeasonData(from: urlWithSubdirectory)
            return
        }
        
        // If found at root, proceed with that URL
        print("Season JSON file found at bundle root for: '\(self.seasonName).json'")
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
        } catch {
            print("Error loading colors: \(error)")
        }
    }

    func colorsByCategory() -> [String: [ColorData]] {
        Dictionary(grouping: colors, by: { $0.category })
    }
}
