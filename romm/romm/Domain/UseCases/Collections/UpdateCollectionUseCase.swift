//
//  UpdateCollectionUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 28.08.25.
//

import Foundation

class UpdateCollectionUseCase {
    private let collectionsRepository: PCollectionsRepository
    
    init(collectionsRepository: PCollectionsRepository) {
        self.collectionsRepository = collectionsRepository
    }
    
    func execute(
        collectionId: Int,
        name: String,
        description: String,
        isPublic: Bool,
        romIds: [Int]
    ) async throws -> Collection {
        return try await collectionsRepository.updateCollection(
            id: collectionId,
            name: name,
            description: description,
            isPublic: isPublic,
            romIds: romIds
        )
    }
    
    func addRomToCollection(
        collectionId: Int,
        romId: Int,
        currentCollection: Collection
    ) async throws -> Collection {
        // Add the ROM ID to the existing ROM IDs
        var newRomIds = currentCollection.romIds
        if !newRomIds.contains(romId) {
            newRomIds.insert(romId)
        }
        
        return try await collectionsRepository.updateCollection(
            id: collectionId,
            name: currentCollection.name,
            description: currentCollection.description,
            isPublic: currentCollection.isPublic,
            romIds: Array(newRomIds)
        )
    }
    
    func removeRomFromCollection(
        collectionId: Int,
        romId: Int,
        currentCollection: Collection
    ) async throws -> Collection {
        // Remove the ROM ID from existing ROM IDs
        var newRomIds = currentCollection.romIds
        newRomIds.remove(romId)
        
        return try await collectionsRepository.updateCollection(
            id: collectionId,
            name: currentCollection.name,
            description: currentCollection.description,
            isPublic: currentCollection.isPublic,
            romIds: Array(newRomIds)
        )
    }
}
