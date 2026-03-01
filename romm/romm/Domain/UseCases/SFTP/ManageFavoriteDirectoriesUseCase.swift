//
//  ManageFavoriteDirectoriesUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class ManageFavoriteDirectoriesUseCase {
    private let repository: PSFTPRepository
    
    init(repository: PSFTPRepository) {
        self.repository = repository
    }
    
    func getFavoriteDirectories(for connectionId: UUID) -> [String] {
        return repository.getFavoriteDirectories(for: connectionId)
    }
    
    func addFavoriteDirectory(_ path: String, for connectionId: UUID) throws {
        print("🔍 ManageFavoriteDirectories UseCase: Adding favorite directory - path: \(path), connectionId: \(connectionId)")
        try repository.addFavoriteDirectory(path, for: connectionId)
        print("🔍 ManageFavoriteDirectories UseCase: Successfully added favorite directory")
    }
    
    func removeFavoriteDirectory(_ path: String, for connectionId: UUID) throws {
        try repository.removeFavoriteDirectory(path, for: connectionId)
    }
}