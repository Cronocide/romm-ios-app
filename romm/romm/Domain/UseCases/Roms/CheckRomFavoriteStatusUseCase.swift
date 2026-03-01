//
//  CheckRomFavoriteStatusUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 26.08.25.
//

import Foundation

class CheckRomFavoriteStatusUseCase {
    private let romsRepository: PRomsRepository
    
    init(romsRepository: PRomsRepository) {
        self.romsRepository = romsRepository
    }
    
    func execute(romId: Int) async throws -> Bool {
        return try await romsRepository.isRomFavorite(romId: romId)
    }
}
