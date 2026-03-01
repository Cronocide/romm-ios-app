//
//  SaveSetupConfigurationUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 07.08.25.
//

import Foundation
import os

protocol PSaveSetupConfigurationUseCase {
    func execute(
        serverURL: String,
        username: String,
        password: String,
        allowIncompatibleVersionLogin: Bool
    ) async throws -> SetupConfiguration
}

class SaveSetupConfigurationUseCase: PSaveSetupConfigurationUseCase {
    private let logger = Logger.general
    private let setupRepository: PSetupRepository
    
    init(setupRepository: PSetupRepository) {
        self.setupRepository = setupRepository
    }
    
    func execute(
        serverURL: String,
        username: String,
        password: String,
        allowIncompatibleVersionLogin: Bool
    ) async throws -> SetupConfiguration {
        logger.info("Starting setup configuration save...")
        
        // Validate input
        guard !serverURL.isEmpty, !username.isEmpty, !password.isEmpty else {
            throw SetupUseCaseError.invalidInput
        }
        
        guard isValidURL(serverURL) else {
            throw SetupUseCaseError.invalidURL
        }
        
        do {
            // Repository handles API validation and storage
            let setupConfig = try await setupRepository.saveAndValidateConfiguration(
                serverURL: serverURL,
                username: username,
                password: password,
                allowIncompatibleVersionLogin: allowIncompatibleVersionLogin
            )
            
            logger.info("Setup configuration saved successfully")
            return setupConfig
            
        } catch {
            logger.error("Failed to save setup configuration: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme?.hasPrefix("http") == true && url.host != nil
    }
    
    private func getCurrentAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
