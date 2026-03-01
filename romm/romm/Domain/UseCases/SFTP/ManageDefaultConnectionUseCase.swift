//
//  ManageDefaultConnectionUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class ManageDefaultConnectionUseCase {
    private let repository: PSFTPRepository
    
    init(repository: PSFTPRepository) {
        self.repository = repository
    }
    
    func getDefaultConnection() -> SFTPConnection? {
        return repository.getDefaultConnection()
    }
    
    func setDefaultConnection(_ connection: SFTPConnection) throws {
        try repository.setDefaultConnection(connection)
    }
}
