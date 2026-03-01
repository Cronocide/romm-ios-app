//
//  SaveConnectionUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class SaveConnectionUseCase {
    private let repository: PSFTPRepository
    
    init(repository: PSFTPRepository) {
        self.repository = repository
    }
    
    func execute(_ connection: SFTPConnection, credentials: SFTPCredentials) throws {
        try repository.saveConnection(connection, credentials: credentials)
    }
}