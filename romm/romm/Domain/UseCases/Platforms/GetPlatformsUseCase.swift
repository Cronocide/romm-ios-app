//
//  GetPlatformsUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class GetPlatformsUseCase {
    private let platformsRepository: PPlatformsRepository
    
    init(platformsRepository: PPlatformsRepository) {
        self.platformsRepository = platformsRepository
    }
    
    func execute() async throws -> [Platform] {
        return try await platformsRepository.getPlatforms()
    }
}