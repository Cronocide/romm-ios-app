//
//  CollectionPickerViewModel.swift
//  romm
//
//  Created by Ilyas Hallak on 28.08.25.
//

import Foundation
import Observation

@Observable
@MainActor
class CollectionPickerViewModel {
    var availableCollections: [Collection] = []
    var isLoadingCollections: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var showSuccessToast: Bool = false
    var showErrorToast: Bool = false
    
    private let logger = Logger.viewModel
    
    private let getCollectionsUseCase: GetCollectionsUseCase
    private let updateCollectionUseCase: UpdateCollectionUseCase
    
    init(factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self.getCollectionsUseCase = factory.makeGetCollectionsUseCase()
        self.updateCollectionUseCase = factory.makeUpdateCollectionUseCase()
    }
    
    func loadCollections() async {
        guard !isLoadingCollections else { return }
        
        isLoadingCollections = true
        errorMessage = nil
        
        do {
            let collections = try await getCollectionsUseCase.execute()
            availableCollections = collections
            isLoadingCollections = false
            logger.info("Loaded \(collections.count) collections for picker")
        } catch {
            isLoadingCollections = false
            errorMessage = error.localizedDescription
            logger.error("Error loading collections: \(error)")
        }
    }
    
    func toggleRomInCollection(romId: Int, collection: Collection) async -> Bool {
        let isRomInCollection = collection.romIds.contains(romId)
        
        if isRomInCollection {
            return await removeRomFromCollection(romId: romId, collection: collection)
        } else {
            return await addRomToCollection(romId: romId, collection: collection)
        }
    }
    
    func addRomToCollection(romId: Int, collection: Collection) async -> Bool {
        logger.info("Adding ROM \(romId) to collection '\(collection.name)'")
        
        do {
            let updatedCollection = try await updateCollectionUseCase.addRomToCollection(
                collectionId: collection.id,
                romId: romId,
                currentCollection: collection
            )
            
            // Update the collection in our local list
            if let index = availableCollections.firstIndex(where: { $0.id == collection.id }) {
                availableCollections[index] = updatedCollection
            }
            
            successMessage = "ROM added to '\(updatedCollection.name)'"
            showSuccessToast = true
            logger.info("✅ Successfully added ROM to collection '\(updatedCollection.name)'")
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            showErrorToast = true
            logger.error("❌ Error adding ROM to collection: \(error)")
            return false
        }
    }
    
    func removeRomFromCollection(romId: Int, collection: Collection) async -> Bool {
        logger.info("Removing ROM \(romId) from collection '\(collection.name)'")
        
        do {
            let updatedCollection = try await updateCollectionUseCase.removeRomFromCollection(
                collectionId: collection.id,
                romId: romId,
                currentCollection: collection
            )
            
            // Update the collection in our local list
            if let index = availableCollections.firstIndex(where: { $0.id == collection.id }) {
                availableCollections[index] = updatedCollection
            }
            
            successMessage = "ROM removed from '\(updatedCollection.name)'"
            showSuccessToast = true
            logger.info("✅ Successfully removed ROM from collection '\(updatedCollection.name)'")
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            showErrorToast = true
            logger.error("❌ Error removing ROM from collection: \(error)")
            return false
        }
    }
    
    func isRomInCollection(romId: Int, collection: Collection) -> Bool {
        return collection.romIds.contains(romId)
    }
    
    func getCollectionsContainingRom(romId: Int) -> [Collection] {
        return availableCollections.filter { $0.romIds.contains(romId) }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
        showSuccessToast = false
        showErrorToast = false
    }
}
