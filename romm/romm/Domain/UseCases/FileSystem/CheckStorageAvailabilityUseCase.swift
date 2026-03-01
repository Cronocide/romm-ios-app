//
//  CheckStorageAvailabilityUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class CheckStorageAvailabilityUseCase {
    private let fileSystemRepository: PFileSystemRepository
    
    init(fileSystemRepository: PFileSystemRepository) {
        self.fileSystemRepository = fileSystemRepository
    }
    
    func execute(requiredBytes: Int64, safetyBufferPercent: Double = 0.2) -> Bool {
        return fileSystemRepository.hasEnoughStorage(requiredBytes: requiredBytes, safetyBufferPercent: safetyBufferPercent)
    }
}