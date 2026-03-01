//
//  GetAvailableStorageCapacityUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class GetAvailableStorageCapacityUseCase {
    private let fileSystemRepository: PFileSystemRepository
    
    init(fileSystemRepository: PFileSystemRepository) {
        self.fileSystemRepository = fileSystemRepository
    }
    
    func execute() -> Int64? {
        return fileSystemRepository.availableStorageCapacity()
    }
    
    func executeFormatted() -> String {
        return fileSystemRepository.formattedAvailableCapacity()
    }
}