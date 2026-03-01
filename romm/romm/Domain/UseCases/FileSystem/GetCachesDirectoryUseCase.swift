//
//  GetCachesDirectoryUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class GetCachesDirectoryUseCase {
    private let fileSystemRepository: PFileSystemRepository
    
    init(fileSystemRepository: PFileSystemRepository) {
        self.fileSystemRepository = fileSystemRepository
    }
    
    func execute() -> String {
        return fileSystemRepository.cachesDirectory()
    }
}