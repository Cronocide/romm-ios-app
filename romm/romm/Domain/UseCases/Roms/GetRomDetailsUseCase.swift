//
//  GetRomDetailsUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 26.08.25.
//

import Foundation

class GetRomDetailsUseCase {
    private let romsRepository: PRomsRepository
    
    init(romsRepository: PRomsRepository) {
        self.romsRepository = romsRepository
    }
    
    func execute(romId: Int) async throws -> RomDetails {
        guard romId > 0 else {
            throw RomError.invalidRomId
        }
        
        return try await romsRepository.getRomDetails(id: romId)
    }
}
