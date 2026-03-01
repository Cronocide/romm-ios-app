//
//  GetAllConnectionsUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class GetAllConnectionsUseCase {
    private let repository: PSFTPRepository
    
    init(repository: PSFTPRepository) {
        self.repository = repository
    }
    
    func execute() -> [SFTPConnection] {
        return repository.getAllConnections()
    }
}