//
//  GetFileAttributesUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class GetFileAttributesUseCase {
    private let fileSystemRepository: PFileSystemRepository
    
    init(fileSystemRepository: PFileSystemRepository) {
        self.fileSystemRepository = fileSystemRepository
    }
    
    func execute(at path: String) throws -> [FileAttributeKey: Any] {
        return try fileSystemRepository.fileAttributes(at: path)
    }
    
    func getModificationDate(of path: String) throws -> Date? {
        return try fileSystemRepository.modificationDate(of: path)
    }
    
    func getCreationDate(of path: String) throws -> Date? {
        return try fileSystemRepository.creationDate(of: path)
    }
}