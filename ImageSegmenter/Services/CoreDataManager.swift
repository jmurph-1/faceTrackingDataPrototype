import Foundation
import CoreData
import UIKit

/// Service for managing Core Data operations
class CoreDataManager {

    static let shared = CoreDataManager()

    private init() {}

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SeasonAnalysis")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()

    // MARK: - Core Data operations

    /// Save changes to the context
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    /// Save an AnalysisResult to Core Data
    /// - Parameter result: The analysis result to save
    /// - Returns: Success or failure
    func saveAnalysisResult(_ result: AnalysisResult) -> Bool {
        let context = persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: "AnalysisResultEntity", in: context)!
        let managedObject = NSManagedObject(entity: entity, insertInto: context)

        // Set attributes
        managedObject.setValue(result.season.rawValue, forKey: "season")
        managedObject.setValue(result.confidence, forKey: "confidence")
        managedObject.setValue(result.deltaEToNextClosest, forKey: "deltaE")
        managedObject.setValue(result.nextClosestSeason.rawValue, forKey: "nextClosestSeason")
        managedObject.setValue(result.date, forKey: "date")
        managedObject.setValue(result.notes, forKey: "notes")

        // Convert colors to data
        if let skinColorData = try? NSKeyedArchiver.archivedData(withRootObject: result.skinColor, requiringSecureCoding: true) {
            managedObject.setValue(skinColorData, forKey: "skinColorData")
        }

        if let hairColor = result.hairColor, let hairColorData = try? NSKeyedArchiver.archivedData(withRootObject: hairColor, requiringSecureCoding: true) {
            managedObject.setValue(hairColorData, forKey: "hairColorData")
        }

        // Set Lab values
        if let lab = result.skinColorLab {
            managedObject.setValue(lab.L, forKey: "skinColorLabL")
            managedObject.setValue(lab.a, forKey: "skinColorLabA")
            managedObject.setValue(lab.b, forKey: "skinColorLabB")
        }

        if let lab = result.hairColorLab {
            managedObject.setValue(lab.L, forKey: "hairColorLabL")
            managedObject.setValue(lab.a, forKey: "hairColorLabA")
            managedObject.setValue(lab.b, forKey: "hairColorLabB")
        }

        // Save thumbnail
        if let thumbnail = result.thumbnail, let thumbnailData = thumbnail.pngData() {
            managedObject.setValue(thumbnailData, forKey: "thumbnailData")
        }

        // Save context
        do {
            try context.save()
            return true
        } catch {
            print("Failed to save analysis result: \(error)")
            return false
        }
    }

    /// Fetch all analysis results
    /// - Returns: Array of analysis results sorted by date (newest first)
    func fetchAllAnalysisResults() -> [AnalysisResult] {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "AnalysisResultEntity")

        // Sort by date (newest first)
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let managedObjects = try context.fetch(fetchRequest)
            return managedObjects.compactMap { AnalysisResult(from: $0) }
        } catch {
            print("Failed to fetch analysis results: \(error)")
            return []
        }
    }

    /// Delete an analysis result
    /// - Parameter result: The analysis result to delete
    /// - Returns: Success or failure
    func deleteAnalysisResult(with date: Date) -> Bool {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "AnalysisResultEntity")

        // Find the result with the matching date
        fetchRequest.predicate = NSPredicate(format: "date == %@", date as NSDate)

        do {
            let results = try context.fetch(fetchRequest)
            if let objectToDelete = results.first {
                context.delete(objectToDelete)
                try context.save()
                return true
            }
            return false
        } catch {
            print("Failed to delete analysis result: \(error)")
            return false
        }
    }
}
