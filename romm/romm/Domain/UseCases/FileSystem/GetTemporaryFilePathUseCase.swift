//
//  GetTemporaryFilePathUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class GetTemporaryFilePathUseCase {
    private let fileSystemRepository: PFileSystemRepository
    
    init(fileSystemRepository: PFileSystemRepository) {
        self.fileSystemRepository = fileSystemRepository
    }
    
    func execute(for fileName: String) -> String {
        return fileSystemRepository.temporaryFilePath(for: fileName)
    }
}