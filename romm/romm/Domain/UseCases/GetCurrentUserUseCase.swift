//
//  GetCurrentUserUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 08.08.25.
//

import Foundation

class GetCurrentUserUseCase {
    private let authRepository: PAuthRepository
    
    init(authRepository: PAuthRepository) {
        self.authRepository = authRepository
    }
    
    func execute() async throws -> User? {
        return try await authRepository.getCurrentUser()
    }
}
