//
//  CheckFileExistenceUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class CheckFileExistenceUseCase {
    private let fileSystemRepository: PFileSystemRepository
    
    init(fileSystemRepository: PFileSystemRepository) {
        self.fileSystemRepository = fileSystemRepository
    }
    
    func execute(at path: String) -> Bool {
        return fileSystemRepository.fileExists(at: path)
    }
}