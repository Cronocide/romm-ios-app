//
//  ToggleRomFavoriteUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 26.08.25.
//

import Foundation

class ToggleRomFavoriteUseCase {
    private let romsRepository: PRomsRepository
    
    init(romsRepository: PRomsRepository) {
        self.romsRepository = romsRepository
    }
    
    func execute(romId: Int, isFavorite: Bool) async throws {
        guard romId > 0 else {
            throw RomError.invalidRomId
        }
        
        try await romsRepository.toggleRomFavorite(romId: romId, isFavorite: isFavorite)
    }
}
