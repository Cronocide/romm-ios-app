//
//  GetRomsUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 26.08.25.
//

import Foundation

class GetRomsUseCase {
    private let romsRepository: PRomsRepository
    
    init(romsRepository: PRomsRepository) {
        self.romsRepository = romsRepository
    }
    
    func execute(platformId: Int? = nil, searchTerm: String? = nil, limit: Int = 50, offset: Int = 0, char: String? = nil, orderBy: String? = nil, orderDir: String? = nil, collectionId: Int? = nil) async throws -> PaginatedRomsResponse {
        return try await romsRepository.getRoms(platformId: platformId, searchTerm: searchTerm, limit: limit, offset: offset, char: char, orderBy: orderBy, orderDir: orderDir, collectionId: collectionId)
    }
}

class GetRomsWithFiltersUseCase {
    private let romsRepository: PRomsRepository
    
    init(romsRepository: PRomsRepository) {
        self.romsRepository = romsRepository
    }
    
    func execute(
        platformId: Int? = nil, 
        searchTerm: String? = nil, 
        limit: Int = 50, 
        offset: Int = 0, 
        char: String? = nil, 
        orderBy: String? = nil, 
        orderDir: String? = nil, 
        collectionId: Int? = nil,
        filters: RomFilters = .empty
    ) async throws -> PaginatedRomsResponse {
        return try await romsRepository.getRomsWithFilters(
            platformId: platformId, 
            searchTerm: searchTerm, 
            limit: limit, 
            offset: offset, 
            char: char, 
            orderBy: orderBy, 
            orderDir: orderDir, 
            collectionId: collectionId,
            filters: filters
        )
    }
}
