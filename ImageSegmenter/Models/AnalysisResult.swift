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

    /// Left eye color (RGB)
    let leftEyeColor: UIColor?

    /// Left eye color (Lab)
    let leftEyeColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)?

    /// Right eye color (RGB)
    let rightEyeColor: UIColor?

    /// Right eye color (Lab)
    let rightEyeColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)?

    /// Average eye color (RGB)
    let averageEyeColor: UIColor?

    /// Average eye color (Lab)
    let averageEyeColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)?

    /// Left eye confidence score (0.0 - 1.0)
    let leftEyeConfidence: Float

    /// Right eye confidence score (0.0 - 1.0)
    let rightEyeConfidence: Float

    /// Date when the analysis was performed
    let date: Date

    /// Thumbnail image (optional)
    let thumbnail: UIImage?

    /// Additional notes (optional)
    var notes: String?

    /// Contrast analysis properties
    let contrastValue: Double
    let contrastLevel: String
    let contrastDescription: String

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
    ///   - leftEyeColor: Left eye color (optional)
    ///   - leftEyeColorLab: Left eye color in Lab space (optional)
    ///   - rightEyeColor: Right eye color (optional)
    ///   - rightEyeColorLab: Right eye color in Lab space (optional)
    ///   - averageEyeColor: Average eye color (optional)
    ///   - averageEyeColorLab: Average eye color in Lab space (optional)
    ///   - leftEyeConfidence: Left eye confidence score (0.0 - 1.0)
    ///   - rightEyeConfidence: Right eye confidence score (0.0 - 1.0)
    ///   - contrastValue: Contrast value
    ///   - contrastLevel: Contrast level
    ///   - contrastDescription: Contrast description
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
        leftEyeColor: UIColor? = nil,
        leftEyeColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)? = nil,
        rightEyeColor: UIColor? = nil,
        rightEyeColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)? = nil,
        averageEyeColor: UIColor? = nil,
        averageEyeColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)? = nil,
        leftEyeConfidence: Float = 0.0,
        rightEyeConfidence: Float = 0.0,
        contrastValue: Double,
        contrastLevel: String,
        contrastDescription: String,
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
        self.leftEyeColor = leftEyeColor
        self.leftEyeColorLab = leftEyeColorLab
        self.rightEyeColor = rightEyeColor
        self.rightEyeColorLab = rightEyeColorLab
        self.averageEyeColor = averageEyeColor
        self.averageEyeColorLab = averageEyeColorLab
        self.leftEyeConfidence = leftEyeConfidence
        self.rightEyeConfidence = rightEyeConfidence
        self.contrastValue = contrastValue
        self.contrastLevel = contrastLevel
        self.contrastDescription = contrastDescription
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
        case leftEyeColor
        case leftEyeColorLabL
        case leftEyeColorLabA
        case leftEyeColorLabB
        case rightEyeColor
        case rightEyeColorLabL
        case rightEyeColorLabA
        case rightEyeColorLabB
        case averageEyeColor
        case averageEyeColorLabL
        case averageEyeColorLabA
        case averageEyeColorLabB
        case leftEyeConfidence
        case rightEyeConfidence
        case contrastValue
        case contrastLevel
        case contrastDescription
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

        // Encode eye colors
        if let leftEyeColor = leftEyeColor, let leftEyeColorData = try? NSKeyedArchiver.archivedData(withRootObject: leftEyeColor, requiringSecureCoding: true) {
            coder.encode(leftEyeColorData, forKey: CodingKeys.leftEyeColor.rawValue)
        }

        if let rightEyeColor = rightEyeColor, let rightEyeColorData = try? NSKeyedArchiver.archivedData(withRootObject: rightEyeColor, requiringSecureCoding: true) {
            coder.encode(rightEyeColorData, forKey: CodingKeys.rightEyeColor.rawValue)
        }

        if let averageEyeColor = averageEyeColor, let averageEyeColorData = try? NSKeyedArchiver.archivedData(withRootObject: averageEyeColor, requiringSecureCoding: true) {
            coder.encode(averageEyeColorData, forKey: CodingKeys.averageEyeColor.rawValue)
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

        if let lab = leftEyeColorLab {
            coder.encode(lab.L, forKey: CodingKeys.leftEyeColorLabL.rawValue)
            coder.encode(lab.a, forKey: CodingKeys.leftEyeColorLabA.rawValue)
            coder.encode(lab.b, forKey: CodingKeys.leftEyeColorLabB.rawValue)
        }

        if let lab = rightEyeColorLab {
            coder.encode(lab.L, forKey: CodingKeys.rightEyeColorLabL.rawValue)
            coder.encode(lab.a, forKey: CodingKeys.rightEyeColorLabA.rawValue)
            coder.encode(lab.b, forKey: CodingKeys.rightEyeColorLabB.rawValue)
        }

        if let lab = averageEyeColorLab {
            coder.encode(lab.L, forKey: CodingKeys.averageEyeColorLabL.rawValue)
            coder.encode(lab.a, forKey: CodingKeys.averageEyeColorLabA.rawValue)
            coder.encode(lab.b, forKey: CodingKeys.averageEyeColorLabB.rawValue)
        }

        // Encode eye confidence scores
        coder.encode(leftEyeConfidence, forKey: CodingKeys.leftEyeConfidence.rawValue)
        coder.encode(rightEyeConfidence, forKey: CodingKeys.rightEyeConfidence.rawValue)

        coder.encode(contrastValue, forKey: CodingKeys.contrastValue.rawValue)
        coder.encode(contrastLevel, forKey: CodingKeys.contrastLevel.rawValue)
        coder.encode(contrastDescription, forKey: CodingKeys.contrastDescription.rawValue)

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

        // Decode eye colors
        if let leftEyeColorData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.leftEyeColor.rawValue) as Data? {
            self.leftEyeColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: leftEyeColorData)
        } else {
            self.leftEyeColor = nil
        }

        if let rightEyeColorData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.rightEyeColor.rawValue) as Data? {
            self.rightEyeColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: rightEyeColorData)
        } else {
            self.rightEyeColor = nil
        }

        if let averageEyeColorData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.averageEyeColor.rawValue) as Data? {
            self.averageEyeColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: averageEyeColorData)
        } else {
            self.averageEyeColor = nil
        }

        // Decode Lab values
        if coder.containsValue(forKey: CodingKeys.skinColorLabL.rawValue) {
            let labL = coder.decodeDouble(forKey: CodingKeys.skinColorLabL.rawValue)
            let labA = coder.decodeDouble(forKey: CodingKeys.skinColorLabA.rawValue)
            let labB = coder.decodeDouble(forKey: CodingKeys.skinColorLabB.rawValue)
            self.skinColorLab = (CGFloat(labL), CGFloat(labA), CGFloat(labB))
        } else {
            self.skinColorLab = nil
        }

        if coder.containsValue(forKey: CodingKeys.hairColorLabL.rawValue) {
            let labL = coder.decodeDouble(forKey: CodingKeys.hairColorLabL.rawValue)
            let labA = coder.decodeDouble(forKey: CodingKeys.hairColorLabA.rawValue)
            let labB = coder.decodeDouble(forKey: CodingKeys.hairColorLabB.rawValue)
            self.hairColorLab = (CGFloat(labL), CGFloat(labA), CGFloat(labB))
        } else {
            self.hairColorLab = nil
        }

        if coder.containsValue(forKey: CodingKeys.leftEyeColorLabL.rawValue) {
            let labL = coder.decodeDouble(forKey: CodingKeys.leftEyeColorLabL.rawValue)
            let labA = coder.decodeDouble(forKey: CodingKeys.leftEyeColorLabA.rawValue)
            let labB = coder.decodeDouble(forKey: CodingKeys.leftEyeColorLabB.rawValue)
            self.leftEyeColorLab = (CGFloat(labL), CGFloat(labA), CGFloat(labB))
        } else {
            self.leftEyeColorLab = nil
        }

        if coder.containsValue(forKey: CodingKeys.rightEyeColorLabL.rawValue) {
            let labL = coder.decodeDouble(forKey: CodingKeys.rightEyeColorLabL.rawValue)
            let labA = coder.decodeDouble(forKey: CodingKeys.rightEyeColorLabA.rawValue)
            let labB = coder.decodeDouble(forKey: CodingKeys.rightEyeColorLabB.rawValue)
            self.rightEyeColorLab = (CGFloat(labL), CGFloat(labA), CGFloat(labB))
        } else {
            self.rightEyeColorLab = nil
        }

        if coder.containsValue(forKey: CodingKeys.averageEyeColorLabL.rawValue) {
            let labL = coder.decodeDouble(forKey: CodingKeys.averageEyeColorLabL.rawValue)
            let labA = coder.decodeDouble(forKey: CodingKeys.averageEyeColorLabA.rawValue)
            let labB = coder.decodeDouble(forKey: CodingKeys.averageEyeColorLabB.rawValue)
            self.averageEyeColorLab = (CGFloat(labL), CGFloat(labA), CGFloat(labB))
        } else {
            self.averageEyeColorLab = nil
        }

        // Decode eye confidence scores
        self.leftEyeConfidence = coder.decodeFloat(forKey: CodingKeys.leftEyeConfidence.rawValue)
        self.rightEyeConfidence = coder.decodeFloat(forKey: CodingKeys.rightEyeConfidence.rawValue)

        // Decode contrast values
        self.contrastValue = coder.decodeDouble(forKey: CodingKeys.contrastValue.rawValue)
        self.contrastLevel = coder.decodeObject(of: NSString.self, forKey: CodingKeys.contrastLevel.rawValue) as? String ?? ""
        self.contrastDescription = coder.decodeObject(of: NSString.self, forKey: CodingKeys.contrastDescription.rawValue) as? String ?? ""

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
        var leftEyeColor: UIColor?
        var rightEyeColor: UIColor?
        var averageEyeColor: UIColor?

        if let skinColorData = managedObject.value(forKey: "skinColorData") as? Data {
            skinColor = (try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: skinColorData)) ?? UIColor.clear
        }

        if let hairColorData = managedObject.value(forKey: "hairColorData") as? Data {
            hairColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: hairColorData)
        }

        if let leftEyeColorData = managedObject.value(forKey: "leftEyeColorData") as? Data {
            leftEyeColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: leftEyeColorData)
        }

        if let rightEyeColorData = managedObject.value(forKey: "rightEyeColorData") as? Data {
            rightEyeColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: rightEyeColorData)
        }

        if let averageEyeColorData = managedObject.value(forKey: "averageEyeColorData") as? Data {
            averageEyeColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: averageEyeColorData)
        }

        // Decode Lab values
        var skinLab: (L: CGFloat, a: CGFloat, b: CGFloat)?
        var hairLab: (L: CGFloat, a: CGFloat, b: CGFloat)?
        var leftEyeLab: (L: CGFloat, a: CGFloat, b: CGFloat)?
        var rightEyeLab: (L: CGFloat, a: CGFloat, b: CGFloat)?
        var averageEyeLab: (L: CGFloat, a: CGFloat, b: CGFloat)?

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

        if let leftEyeL = managedObject.value(forKey: "leftEyeColorLabL") as? Double {
            let leftEyeA = managedObject.value(forKey: "leftEyeColorLabA") as? Double ?? 0
            let leftEyeB = managedObject.value(forKey: "leftEyeColorLabB") as? Double ?? 0
            leftEyeLab = (CGFloat(leftEyeL), CGFloat(leftEyeA), CGFloat(leftEyeB))
        }

        if let rightEyeL = managedObject.value(forKey: "rightEyeColorLabL") as? Double {
            let rightEyeA = managedObject.value(forKey: "rightEyeColorLabA") as? Double ?? 0
            let rightEyeB = managedObject.value(forKey: "rightEyeColorLabB") as? Double ?? 0
            rightEyeLab = (CGFloat(rightEyeL), CGFloat(rightEyeA), CGFloat(rightEyeB))
        }

        if let averageEyeL = managedObject.value(forKey: "averageEyeColorLabL") as? Double {
            let averageEyeA = managedObject.value(forKey: "averageEyeColorLabA") as? Double ?? 0
            let averageEyeB = managedObject.value(forKey: "averageEyeColorLabB") as? Double ?? 0
            averageEyeLab = (CGFloat(averageEyeL), CGFloat(averageEyeA), CGFloat(averageEyeB))
        }

        let date = managedObject.value(forKey: "date") as? Date ?? Date()
        let notes = managedObject.value(forKey: "notes") as? String
        let leftEyeConfidence = managedObject.value(forKey: "leftEyeConfidence") as? Float ?? 0.0
        let rightEyeConfidence = managedObject.value(forKey: "rightEyeConfidence") as? Float ?? 0.0

        // Decode contrast values
        let contrastValue = managedObject.value(forKey: "contrastValue") as? Double ?? 0.0
        let contrastLevel = managedObject.value(forKey: "contrastLevel") as? String ?? ""
        let contrastDescription = managedObject.value(forKey: "contrastDescription") as? String ?? ""

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
            leftEyeColor: leftEyeColor,
            leftEyeColorLab: leftEyeLab,
            rightEyeColor: rightEyeColor,
            rightEyeColorLab: rightEyeLab,
            averageEyeColor: averageEyeColor,
            averageEyeColorLab: averageEyeLab,
            leftEyeConfidence: leftEyeConfidence,
            rightEyeConfidence: rightEyeConfidence,
            contrastValue: contrastValue,
            contrastLevel: contrastLevel,
            contrastDescription: contrastDescription,
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

        if let leftEyeColor = leftEyeColor,
           let leftEyeColorData = try? NSKeyedArchiver.archivedData(withRootObject: leftEyeColor, requiringSecureCoding: true) {
            managedObject.setValue(leftEyeColorData, forKey: "leftEyeColorData")
        }

        if let rightEyeColor = rightEyeColor,
           let rightEyeColorData = try? NSKeyedArchiver.archivedData(withRootObject: rightEyeColor, requiringSecureCoding: true) {
            managedObject.setValue(rightEyeColorData, forKey: "rightEyeColorData")
        }

        if let averageEyeColor = averageEyeColor,
           let averageEyeColorData = try? NSKeyedArchiver.archivedData(withRootObject: averageEyeColor, requiringSecureCoding: true) {
            managedObject.setValue(averageEyeColorData, forKey: "averageEyeColorData")
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

        if let lab = leftEyeColorLab {
            managedObject.setValue(Double(lab.L), forKey: "leftEyeColorLabL")
            managedObject.setValue(Double(lab.a), forKey: "leftEyeColorLabA")
            managedObject.setValue(Double(lab.b), forKey: "leftEyeColorLabB")
        }

        if let lab = rightEyeColorLab {
            managedObject.setValue(Double(lab.L), forKey: "rightEyeColorLabL")
            managedObject.setValue(Double(lab.a), forKey: "rightEyeColorLabA")
            managedObject.setValue(Double(lab.b), forKey: "rightEyeColorLabB")
        }

        if let lab = averageEyeColorLab {
            managedObject.setValue(Double(lab.L), forKey: "averageEyeColorLabL")
            managedObject.setValue(Double(lab.a), forKey: "averageEyeColorLabA")
            managedObject.setValue(Double(lab.b), forKey: "averageEyeColorLabB")
        }

        // Save eye confidence scores
        managedObject.setValue(leftEyeConfidence, forKey: "leftEyeConfidence")
        managedObject.setValue(rightEyeConfidence, forKey: "rightEyeConfidence")

        // Save contrast values
        managedObject.setValue(contrastValue, forKey: "contrastValue")
        managedObject.setValue(contrastLevel, forKey: "contrastLevel")
        managedObject.setValue(contrastDescription, forKey: "contrastDescription")

        // Save date
        managedObject.setValue(date, forKey: "date")

        // Save thumbnail
        if let thumbnail = thumbnail, let thumbnailData = thumbnail.pngData() {
            managedObject.setValue(thumbnailData, forKey: "thumbnailData")
        }
    }
}
