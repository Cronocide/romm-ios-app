//
//  CreateDirectoryUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class CreateDirectoryUseCase {
    private let fileSystemRepository: PFileSystemRepository
    
    init(fileSystemRepository: PFileSystemRepository) {
        self.fileSystemRepository = fileSystemRepository
    }
    
    func execute(at path: String) throws {
        try fileSystemRepository.createDirectory(at: path)
    }
}