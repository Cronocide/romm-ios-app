//
//  GetCredentialsUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 27.08.25.
//

import Foundation

class GetCredentialsUseCase {
    private let repository: PSFTPRepository
    
    init(repository: PSFTPRepository) {
        self.repository = repository
    }
    
    func execute(for connectionId: UUID) -> SFTPCredentials? {
        return repository.getCredentials(for: connectionId)
    }
}