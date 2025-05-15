import Foundation
import UIKit
import CoreData

/// Model representing a color analysis result
class AnalysisResult: NSObject, NSSecureCoding {

    /// The classified season
    let season: SeasonClassifier.Season

    /// Confidence score (0-1)
    let confidence: Float

    /// Delta-E to next closest season
    let deltaEToNextClosest: Float

    /// Next closest season
    let nextClosestSeason: SeasonClassifier.Season

    /// Skin color (RGB)
    let skinColor: UIColor

    /// Hair color (RGB)
    let skinColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)?

    /// Hair color (RGB)
    let hairColor: UIColor?

    /// Hair color (Lab)
    let hairColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)?

    /// Date when the analysis was performed
    let date: Date

    /// Thumbnail image (optional)
    let thumbnail: UIImage?

    /// Additional notes (optional)
    var notes: String?

    /// Create an analysis result
    /// - Parameters:
    ///   - season: The classified season
    ///   - confidence: Classification confidence (0-1)
    ///   - deltaEToNextClosest: Delta-E to the next closest season
    ///   - nextClosestSeason: Next closest season
    ///   - skinColor: Skin color
    ///   - skinColorLab: Skin color in Lab space
    ///   - hairColor: Hair color (optional)
    ///   - hairColorLab: Hair color in Lab space (optional)
    ///   - thumbnail: Thumbnail image (optional)
    ///   - date: Date of analysis (defaults to current date)
    init(
        season: SeasonClassifier.Season,
        confidence: Float,
        deltaEToNextClosest: Float,
        nextClosestSeason: SeasonClassifier.Season,
        skinColor: UIColor,
        skinColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)?,
        hairColor: UIColor?,
        hairColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)?,
        thumbnail: UIImage? = nil,
        date: Date = Date()
    ) {
        self.season = season
        self.confidence = confidence
        self.deltaEToNextClosest = deltaEToNextClosest
        self.nextClosestSeason = nextClosestSeason
        self.skinColor = skinColor
        self.skinColorLab = skinColorLab
        self.hairColor = hairColor
        self.hairColorLab = hairColorLab
        self.thumbnail = thumbnail
        self.date = date
    }

    // MARK: - NSSecureCoding

    static var supportsSecureCoding: Bool = true

    enum CodingKeys: String {
        case season
        case confidence
        case deltaEToNextClosest
        case nextClosestSeason
        case skinColor
        case skinColorLabL
        case skinColorLabA
        case skinColorLabB
        case hairColor
        case hairColorLabL
        case hairColorLabA
        case hairColorLabB
        case date
        case thumbnail
        case notes
    }

    func encode(with coder: NSCoder) {
        coder.encode(season.rawValue, forKey: CodingKeys.season.rawValue)
        coder.encode(confidence, forKey: CodingKeys.confidence.rawValue)
        coder.encode(deltaEToNextClosest, forKey: CodingKeys.deltaEToNextClosest.rawValue)
        coder.encode(nextClosestSeason.rawValue, forKey: CodingKeys.nextClosestSeason.rawValue)

        // Encode UIColors as Data
        if let skinColorData = try? NSKeyedArchiver.archivedData(withRootObject: skinColor, requiringSecureCoding: true) {
            coder.encode(skinColorData, forKey: CodingKeys.skinColor.rawValue)
        }

        if let hairColor = hairColor, let hairColorData = try? NSKeyedArchiver.archivedData(withRootObject: hairColor, requiringSecureCoding: true) {
            coder.encode(hairColorData, forKey: CodingKeys.hairColor.rawValue)
        }

        // Encode Lab values
        if let lab = skinColorLab {
            coder.encode(lab.L, forKey: CodingKeys.skinColorLabL.rawValue)
            coder.encode(lab.a, forKey: CodingKeys.skinColorLabA.rawValue)
            coder.encode(lab.b, forKey: CodingKeys.skinColorLabB.rawValue)
        }

        if let lab = hairColorLab {
            coder.encode(lab.L, forKey: CodingKeys.hairColorLabL.rawValue)
            coder.encode(lab.a, forKey: CodingKeys.hairColorLabA.rawValue)
            coder.encode(lab.b, forKey: CodingKeys.hairColorLabB.rawValue)
        }

        coder.encode(date, forKey: CodingKeys.date.rawValue)
        coder.encode(notes, forKey: CodingKeys.notes.rawValue)

        // Encode thumbnail as PNG data if present
        if let thumbnail = thumbnail, let thumbnailData = thumbnail.pngData() {
            coder.encode(thumbnailData, forKey: CodingKeys.thumbnail.rawValue)
        }
    }

    required init?(coder: NSCoder) {
        // Decode season and ensure it's valid
        guard let seasonString = coder.decodeObject(of: NSString.self, forKey: CodingKeys.season.rawValue) as String?,
              let season = SeasonClassifier.Season(rawValue: seasonString) else {
            return nil
        }
        self.season = season

        // Decode next closest season and ensure it's valid
        guard let nextSeasonString = coder.decodeObject(of: NSString.self, forKey: CodingKeys.nextClosestSeason.rawValue) as String?,
              let nextSeason = SeasonClassifier.Season(rawValue: nextSeasonString) else {
            return nil
        }
        self.nextClosestSeason = nextSeason

        // Decode confidence and delta-E
        self.confidence = coder.decodeFloat(forKey: CodingKeys.confidence.rawValue)
        self.deltaEToNextClosest = coder.decodeFloat(forKey: CodingKeys.deltaEToNextClosest.rawValue)

        // Decode colors
        if let skinColorData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.skinColor.rawValue) as Data? {
            self.skinColor = (try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: skinColorData)) ?? UIColor.clear
        } else {
            self.skinColor = UIColor.clear
        }

        if let hairColorData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.hairColor.rawValue) as Data? {
            self.hairColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: hairColorData)
        } else {
            self.hairColor = nil
        }

        // Decode Lab values
        if coder.containsValue(forKey: CodingKeys.skinColorLabL.rawValue) {
            let l = coder.decodeDouble(forKey: CodingKeys.skinColorLabL.rawValue)
            let a = coder.decodeDouble(forKey: CodingKeys.skinColorLabA.rawValue)
            let b = coder.decodeDouble(forKey: CodingKeys.skinColorLabB.rawValue)
            self.skinColorLab = (CGFloat(l), CGFloat(a), CGFloat(b))
        } else {
            self.skinColorLab = nil
        }

        if coder.containsValue(forKey: CodingKeys.hairColorLabL.rawValue) {
            let l = coder.decodeDouble(forKey: CodingKeys.hairColorLabL.rawValue)
            let a = coder.decodeDouble(forKey: CodingKeys.hairColorLabA.rawValue)
            let b = coder.decodeDouble(forKey: CodingKeys.hairColorLabB.rawValue)
            self.hairColorLab = (CGFloat(l), CGFloat(a), CGFloat(b))
        } else {
            self.hairColorLab = nil
        }

        // Decode date
        if let date = coder.decodeObject(of: NSDate.self, forKey: CodingKeys.date.rawValue) as Date? {
            self.date = date
        } else {
            self.date = Date()
        }

        // Decode notes
        self.notes = coder.decodeObject(of: NSString.self, forKey: CodingKeys.notes.rawValue) as String?

        // Decode thumbnail
        if let thumbnailData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.thumbnail.rawValue) as Data? {
            self.thumbnail = UIImage(data: thumbnailData)
        } else {
            self.thumbnail = nil
        }
    }

    // MARK: - Helper Methods

    /// Format date as a readable string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Get a display name for the result
    var displayName: String {
        return "\(season.rawValue) - \(formattedDate)"
    }

    /// Get the confidence as a percentage
    var confidencePercentage: String {
        return "\(Int(confidence * 100))%"
    }

    /// Get the season description
    var seasonDescription: String {
        return season.description
    }
}

// MARK: - Core Data Integration

extension AnalysisResult {

    /// Create an AnalysisResult from a Core Data managed object
    convenience init?(from managedObject: NSManagedObject) {
        guard let seasonString = managedObject.value(forKey: "season") as? String,
              let season = SeasonClassifier.Season(rawValue: seasonString),
              let nextSeasonString = managedObject.value(forKey: "nextClosestSeason") as? String,
              let nextSeason = SeasonClassifier.Season(rawValue: nextSeasonString) else {
            return nil
        }

        let confidence = managedObject.value(forKey: "confidence") as? Float ?? 0
        let deltaE = managedObject.value(forKey: "deltaE") as? Float ?? 0

        // Decode colors
        var skinColor = UIColor.clear
        var hairColor: UIColor?

        if let skinColorData = managedObject.value(forKey: "skinColorData") as? Data {
            skinColor = (try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: skinColorData)) ?? UIColor.clear
        }

        if let hairColorData = managedObject.value(forKey: "hairColorData") as? Data {
            hairColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: hairColorData)
        }

        // Decode Lab values
        var skinLab: (L: CGFloat, a: CGFloat, b: CGFloat)?
        var hairLab: (L: CGFloat, a: CGFloat, b: CGFloat)?

        if let skinL = managedObject.value(forKey: "skinColorLabL") as? Double {
            let skinA = managedObject.value(forKey: "skinColorLabA") as? Double ?? 0
            let skinB = managedObject.value(forKey: "skinColorLabB") as? Double ?? 0
            skinLab = (CGFloat(skinL), CGFloat(skinA), CGFloat(skinB))
        }

        if let hairL = managedObject.value(forKey: "hairColorLabL") as? Double {
            let hairA = managedObject.value(forKey: "hairColorLabA") as? Double ?? 0
            let hairB = managedObject.value(forKey: "hairColorLabB") as? Double ?? 0
            hairLab = (CGFloat(hairL), CGFloat(hairA), CGFloat(hairB))
        }

        let date = managedObject.value(forKey: "date") as? Date ?? Date()
        let notes = managedObject.value(forKey: "notes") as? String

        var thumbnail: UIImage?
        if let thumbnailData = managedObject.value(forKey: "thumbnailData") as? Data {
            thumbnail = UIImage(data: thumbnailData)
        }

        self.init(
            season: season,
            confidence: confidence,
            deltaEToNextClosest: deltaE,
            nextClosestSeason: nextSeason,
            skinColor: skinColor,
            skinColorLab: skinLab,
            hairColor: hairColor,
            hairColorLab: hairLab,
            thumbnail: thumbnail,
            date: date
        )

        self.notes = notes
    }

    /// Save the result to a Core Data managed object
    func save(to managedObject: NSManagedObject) {
        // Save basic properties
        managedObject.setValue(season.rawValue, forKey: "season")
        managedObject.setValue(confidence, forKey: "confidence")
        managedObject.setValue(deltaEToNextClosest, forKey: "deltaE")
        managedObject.setValue(nextClosestSeason.rawValue, forKey: "nextClosestSeason")
        managedObject.setValue(date, forKey: "date")
        managedObject.setValue(notes, forKey: "notes")

        // Save colors as archived data
        if let skinColorData = try? NSKeyedArchiver.archivedData(withRootObject: skinColor, requiringSecureCoding: true) {
            managedObject.setValue(skinColorData, forKey: "skinColorData")
        }

        if let hairColor = hairColor,
           let hairColorData = try? NSKeyedArchiver.archivedData(withRootObject: hairColor, requiringSecureCoding: true) {
            managedObject.setValue(hairColorData, forKey: "hairColorData")
        }

        // Save Lab values
        if let lab = skinColorLab {
            managedObject.setValue(Double(lab.L), forKey: "skinColorLabL")
            managedObject.setValue(Double(lab.a), forKey: "skinColorLabA")
            managedObject.setValue(Double(lab.b), forKey: "skinColorLabB")
        }

        if let lab = hairColorLab {
            managedObject.setValue(Double(lab.L), forKey: "hairColorLabL")
            managedObject.setValue(Double(lab.a), forKey: "hairColorLabA")
            managedObject.setValue(Double(lab.b), forKey: "hairColorLabB")
        }

        // Save thumbnail
        if let thumbnail = thumbnail, let thumbnailData = thumbnail.pngData() {
            managedObject.setValue(thumbnailData, forKey: "thumbnailData")
        }
    }
}
