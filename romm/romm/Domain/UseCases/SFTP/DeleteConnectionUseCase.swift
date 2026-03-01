//
//  DeleteConnectionUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class DeleteConnectionUseCase {
    private let repository: PSFTPRepository
    
    init(repository: PSFTPRepository) {
        self.repository = repository
    }
    
    func execute(_ connection: SFTPConnection) throws {
        try repository.deleteConnection(connection)
    }
}