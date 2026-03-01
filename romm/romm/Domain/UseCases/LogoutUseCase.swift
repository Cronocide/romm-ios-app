//
//  AuthUseCases.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import Foundation

class LogoutUseCase {
    private let authRepository: PAuthRepository
    
    init(authRepository: PAuthRepository) {
        self.authRepository = authRepository
    }
    
    func execute() async throws {
        try await authRepository.logout()
    }
}

