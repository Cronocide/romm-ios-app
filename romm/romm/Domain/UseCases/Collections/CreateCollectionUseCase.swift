//
//  CreateCollectionUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class CreateCollectionUseCase {
    private let collectionsRepository: PCollectionsRepository
    
    init(collectionsRepository: PCollectionsRepository) {
        self.collectionsRepository = collectionsRepository
    }
    
    func execute(data: CreateCollectionData) async throws -> Collection {
        guard !data.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CollectionError.invalidCollectionName
        }
        
        return try await collectionsRepository.createCollection(data: data)
    }
}