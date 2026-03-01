//
//  AddPlatformUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class AddPlatformUseCase {
    private let platformsRepository: PPlatformsRepository
    
    init(platformsRepository: PPlatformsRepository) {
        self.platformsRepository = platformsRepository
    }
    
    func execute(name: String, slug: String) async throws -> Platform {
        guard !name.isEmpty, !slug.isEmpty else {
            throw PlatformError.invalidInput
        }
        
        return try await platformsRepository.addPlatform(name: name, slug: slug)
    }
}