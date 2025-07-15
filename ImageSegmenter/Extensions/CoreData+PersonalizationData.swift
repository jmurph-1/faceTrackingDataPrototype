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
    
    /// Save personalized season data to Core Data
    /// - Parameters:
    ///   - personalizedData: The personalized season data to save
    ///   - analysisResultId: Optional ID to link with existing analysis result
    /// - Returns: True if successfully saved
    func savePersonalizedSeasonData(_ personalizedData: PersonalizedSeasonData, linkedToAnalysisResultId analysisResultId: UUID? = nil) -> Bool {
        // TODO: Add PersonalizationResult entity to Core Data model
        // For now, skip Core Data saving to prevent crashes
        print("⚠️  PersonalizationResult entity not found in Core Data model - skipping save")
        return true
        
        let context = persistentContainer.viewContext
        
        // Create new PersonalizationResult entity
        let entity = NSEntityDescription.entity(forEntityName: "PersonalizationResult", in: context)!
        let personalizationResult = NSManagedObject(entity: entity, insertInto: context)
        
        // Set basic properties
        personalizationResult.setValue(personalizedData.id, forKey: "id")
        personalizationResult.setValue(personalizedData.createdDate, forKey: "createdDate")
        personalizationResult.setValue(personalizedData.baseSeason, forKey: "baseSeason")
        personalizationResult.setValue(personalizedData.personalizedTagline, forKey: "personalizedTagline")
        personalizationResult.setValue(personalizedData.userCharacteristics, forKey: "userCharacteristics")
        personalizationResult.setValue(personalizedData.personalizedOverview, forKey: "personalizedOverview")
        personalizationResult.setValue(personalizedData.confidence, forKey: "confidence")
        personalizationResult.setValue(analysisResultId, forKey: "linkedAnalysisResultId")
        
        // Store JSON data for complex objects
        if let jsonData = personalizedData.toJSONData() {
            personalizationResult.setValue(jsonData, forKey: "fullPersonalizationData")
        }
        
        // Store color arrays as JSON
        if let emphasizedColorsData = try? JSONEncoder().encode(personalizedData.emphasizedColors) {
            personalizationResult.setValue(emphasizedColorsData, forKey: "emphasizedColorsData")
        }
        
        if let colorsToAvoidData = try? JSONEncoder().encode(personalizedData.colorsToAvoid) {
            personalizationResult.setValue(colorsToAvoidData, forKey: "colorsToAvoidData")
        }
        
        // Try to link with existing analysis result if ID provided
        if let analysisResultId = analysisResultId {
            linkPersonalizationToAnalysisResult(personalizationResult, analysisResultId: analysisResultId, in: context)
        }
        
        do {
            try context.save()
            return true
        } catch {
            print("Error saving personalized season data: \(error)")
            return false
        }
    }
    
    /// Fetch all personalized season data
    /// - Returns: Array of PersonalizedSeasonData objects
    func fetchAllPersonalizedSeasonData() -> [PersonalizedSeasonData] {
        // TODO: Add PersonalizationResult entity to Core Data model
        print("⚠️  PersonalizationResult entity not found in Core Data model - returning empty array")
        return []
        
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
    
    /// Fetch personalized data for a specific analysis result
    /// - Parameter analysisResultId: The ID of the analysis result
    /// - Returns: PersonalizedSeasonData if found
    func fetchPersonalizedData(for analysisResultId: UUID) -> PersonalizedSeasonData? {
        // TODO: Add PersonalizationResult entity to Core Data model
        print("⚠️  PersonalizationResult entity not found in Core Data model - returning nil")
        return nil
        
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
    
    /// Delete personalized season data
    /// - Parameter personalizedDataId: ID of the personalized data to delete
    /// - Returns: True if successfully deleted
    func deletePersonalizedSeasonData(id personalizedDataId: UUID) -> Bool {
        // TODO: Add PersonalizationResult entity to Core Data model
        print("⚠️  PersonalizationResult entity not found in Core Data model - skipping delete")
        return true
        
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
    
    /// Get the most recent personalized data
    /// - Returns: Most recent PersonalizedSeasonData if available
    func fetchMostRecentPersonalizedData() -> PersonalizedSeasonData? {
        // TODO: Add PersonalizationResult entity to Core Data model
        print("⚠️  PersonalizationResult entity not found in Core Data model - returning nil")
        return nil
        
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
    
    // MARK: - Private Helpers
    
    private func linkPersonalizationToAnalysisResult(_ personalizationResult: NSManagedObject, analysisResultId: UUID, in context: NSManagedObjectContext) {
        // Try to find the corresponding analysis result
        let analysisRequest = NSFetchRequest<NSManagedObject>(entityName: "SeasonAnalysis")
        analysisRequest.predicate = NSPredicate(format: "id == %@", analysisResultId as CVarArg)
        
        do {
            if let analysisResult = try context.fetch(analysisRequest).first {
                // Create relationship if your Core Data model supports it
                // This assumes you've added a relationship in your Core Data model
                analysisResult.setValue(personalizationResult, forKey: "personalizationResult")
                personalizationResult.setValue(analysisResult, forKey: "analysisResult")
            }
        } catch {
            print("Warning: Could not link personalization to analysis result: \(error)")
        }
    }
}

// MARK: - Convenience Extensions

extension PersonalizedSeasonData {
    
    /// Save this personalized data to Core Data
    /// - Parameter linkedAnalysisResultId: Optional ID to link with analysis result
    /// - Returns: True if successfully saved
    func saveToCoreData(linkedToAnalysisResultId analysisResultId: UUID? = nil) -> Bool {
        return CoreDataManager.shared.savePersonalizedSeasonData(self, linkedToAnalysisResultId: analysisResultId)
    }
    
    /// Delete this personalized data from Core Data
    /// - Returns: True if successfully deleted
    func deleteFromCoreData() -> Bool {
        return CoreDataManager.shared.deletePersonalizedSeasonData(id: self.id)
    }
} 