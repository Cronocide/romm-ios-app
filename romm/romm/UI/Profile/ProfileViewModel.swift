//
//  ProfileViewModel.swift
//  romm
//
//  Created by Ilyas Hallak on 08.08.25.
//

import Foundation
import os

@MainActor
class ProfileViewModel: ObservableObject {
    private let logger = Logger.viewModel
    private let logoutUseCase: LogoutUseCase
    private let clearSetupConfigurationUseCase: PClearSetupConfigurationUseCase
    private let getGroupRomsUseCase: PGetGroupRomsUseCase
    private let saveGroupRomsUseCase: PSaveGroupRomsUseCase

    // The didSet persists the setting. It does not fire for the assignment in
    // init(), which is initialization rather than mutation -- preserved from
    // the @Observable version.
    @Published var groupRomsByMetaId: Bool {
        didSet {
            guard oldValue != groupRomsByMetaId else { return }
            saveGroupRomsUseCase.execute(groupRomsByMetaId)
        }
    }

    init(factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self.logoutUseCase = factory.makeLogoutUseCase()
        self.clearSetupConfigurationUseCase = factory.makeClearSetupConfigurationUseCase()
        self.getGroupRomsUseCase = factory.makeGetGroupRomsUseCase()
        self.saveGroupRomsUseCase = factory.makeSaveGroupRomsUseCase()
        self.groupRomsByMetaId = getGroupRomsUseCase.execute()
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
