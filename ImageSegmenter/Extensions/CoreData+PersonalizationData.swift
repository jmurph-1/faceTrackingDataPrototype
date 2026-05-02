//
//  CoreData+PersonalizationData.swift
//  ImageSegmenter
//
//  Created by John Murphy on 5/28/25.
//

import Foundation
import CoreData

// MARK: - Core Data Extensions for Personalization

extension CoreDataManager {

    func savePersonalizedSeasonData(_ personalizedData: PersonalizedSeasonData, linkedToAnalysisResultId analysisResultId: UUID? = nil) -> Bool {
        let context = persistentContainer.viewContext

        let entity = NSEntityDescription.entity(forEntityName: "PersonalizationResult", in: context)!
        let personalizationResult = NSManagedObject(entity: entity, insertInto: context)

        personalizationResult.setValue(personalizedData.id, forKey: "id")
        personalizationResult.setValue(personalizedData.createdDate, forKey: "createdDate")
        personalizationResult.setValue(personalizedData.baseSeason, forKey: "baseSeason")
        personalizationResult.setValue(personalizedData.personalizedTagline, forKey: "personalizedTagline")
        personalizationResult.setValue(personalizedData.userCharacteristics, forKey: "userCharacteristics")
        personalizationResult.setValue(personalizedData.personalizedOverview, forKey: "personalizedOverview")
        personalizationResult.setValue(personalizedData.confidence, forKey: "confidence")
        personalizationResult.setValue(analysisResultId, forKey: "linkedAnalysisResultId")

        if let jsonData = personalizedData.toJSONData() {
            personalizationResult.setValue(jsonData, forKey: "fullPersonalizationData")
        }

        if let emphasizedColorsData = try? JSONEncoder().encode(personalizedData.emphasizedColors) {
            personalizationResult.setValue(emphasizedColorsData, forKey: "emphasizedColorsData")
        }

        if let colorsToAvoidData = try? JSONEncoder().encode(personalizedData.colorsToAvoid) {
            personalizationResult.setValue(colorsToAvoidData, forKey: "colorsToAvoidData")
        }

        do {
            try context.save()
            return true
        } catch {
            print("Error saving personalized season data: \(error)")
            return false
        }
    }

    func fetchAllPersonalizedSeasonData() -> [PersonalizedSeasonData] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "PersonalizationResult")
        request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]

        do {
            let results = try context.fetch(request)
            return results.compactMap { managedObject in
                guard let jsonData = managedObject.value(forKey: "fullPersonalizationData") as? Data else {
                    return nil
                }
                return PersonalizedSeasonData.fromJSONData(jsonData)
            }
        } catch {
            print("Error fetching personalized season data: \(error)")
            return []
        }
    }

    func fetchPersonalizedData(for analysisResultId: UUID) -> PersonalizedSeasonData? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "PersonalizationResult")
        request.predicate = NSPredicate(format: "linkedAnalysisResultId == %@", analysisResultId as CVarArg)
        request.fetchLimit = 1

        do {
            let results = try context.fetch(request)
            guard let managedObject = results.first,
                  let jsonData = managedObject.value(forKey: "fullPersonalizationData") as? Data else {
                return nil
            }
            return PersonalizedSeasonData.fromJSONData(jsonData)
        } catch {
            print("Error fetching personalized data for analysis result: \(error)")
            return nil
        }
    }

    func fetchPersonalizedData(forId id: UUID) -> PersonalizedSeasonData? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "PersonalizationResult")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            let results = try context.fetch(request)
            guard let managedObject = results.first,
                  let jsonData = managedObject.value(forKey: "fullPersonalizationData") as? Data else {
                return nil
            }
            return PersonalizedSeasonData.fromJSONData(jsonData)
        } catch {
            print("Error fetching personalized data by id: \(error)")
            return nil
        }
    }

    func deletePersonalizedSeasonData(id personalizedDataId: UUID) -> Bool {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "PersonalizationResult")
        request.predicate = NSPredicate(format: "id == %@", personalizedDataId as CVarArg)

        do {
            let results = try context.fetch(request)
            for result in results {
                context.delete(result)
            }
            try context.save()
            return true
        } catch {
            print("Error deleting personalized season data: \(error)")
            return false
        }
    }

    func fetchMostRecentPersonalizedData() -> PersonalizedSeasonData? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "PersonalizationResult")
        request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        request.fetchLimit = 1

        do {
            let results = try context.fetch(request)
            guard let managedObject = results.first,
                  let jsonData = managedObject.value(forKey: "fullPersonalizationData") as? Data else {
                return nil
            }
            return PersonalizedSeasonData.fromJSONData(jsonData)
        } catch {
            print("Error fetching most recent personalized data: \(error)")
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension PersonalizedSeasonData {

    func saveToCoreData(linkedToAnalysisResultId analysisResultId: UUID? = nil) -> Bool {
        return CoreDataManager.shared.savePersonalizedSeasonData(self, linkedToAnalysisResultId: analysisResultId)
    }

    func deleteFromCoreData() -> Bool {
        return CoreDataManager.shared.deletePersonalizedSeasonData(id: self.id)
    }
}
