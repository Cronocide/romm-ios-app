//
//  ProfileViewModel.swift
//  romm
//
//  Created by Ilyas Hallak on 08.08.25.
//

import Foundation
import os
import Observation

@Observable
@MainActor
class ProfileViewModel {
    private let logger = Logger.viewModel
    private let logoutUseCase: LogoutUseCase
    private let clearSetupConfigurationUseCase: PClearSetupConfigurationUseCase
    
    init(factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self.logoutUseCase = factory.makeLogoutUseCase()
        self.clearSetupConfigurationUseCase = factory.makeClearSetupConfigurationUseCase()
    }
    
    func logout() {
        logger.info("Logging out...")
        
        Task {
            do {
                try await logoutUseCase.execute()
                logger.info("Logout complete")
            } catch {
                logger.error("Logout failed: \(error)")
            }
        }
    }
    
    func restartSetup() {
        logger.info("Restarting setup...")

        do {
            try clearSetupConfigurationUseCase.execute()
            logger.info("Setup restart complete")

            // Notify AppViewModel to transition to setup state
            NotificationCenter.default.post(name: .restartSetupRequested, object: nil)
        } catch {
            logger.error("Failed to restart setup: \(error)")
        }
    }
}

// MARK: - Notification Names
extension NSNotification.Name {
    static let restartSetupRequested = NSNotification.Name("RestartSetupRequested")
    static let sessionExpired = NSNotification.Name("SessionExpired")
}
