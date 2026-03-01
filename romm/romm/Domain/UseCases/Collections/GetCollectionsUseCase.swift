//
//  GetCollectionsUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class GetCollectionsUseCase {
    private let collectionsRepository: PCollectionsRepository
    
    init(collectionsRepository: PCollectionsRepository) {
        self.collectionsRepository = collectionsRepository
    }
    
    func execute(limit: Int? = nil, offset: Int? = nil) async throws -> [Collection] {
        return try await collectionsRepository.getCollections(limit: limit, offset: offset)
    }
}