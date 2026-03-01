//
//  MoveFileUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class MoveFileUseCase {
    private let fileSystemRepository: PFileSystemRepository
    
    init(fileSystemRepository: PFileSystemRepository) {
        self.fileSystemRepository = fileSystemRepository
    }
    
    func execute(from source: String, to destination: String) throws {
        try fileSystemRepository.moveFile(from: source, to: destination)
    }
}