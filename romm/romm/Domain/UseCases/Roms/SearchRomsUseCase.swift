//
//  SearchRomsUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 26.08.25.
//

import Foundation

class SearchRomsUseCase {
    private let romsRepository: PRomsRepository
    
    init(romsRepository: PRomsRepository) {
        self.romsRepository = romsRepository
    }
    
    func execute(query: String) async throws -> [Rom] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        return try await romsRepository.searchRoms(query: query)
    }
}
