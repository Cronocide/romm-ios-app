//
//  SaveServerVersionUseCase.swift
//  romm
//

import Foundation

class SaveServerVersionUseCase {
    private let heartbeatRepository: PHeartbeatRepository

    init(heartbeatRepository: PHeartbeatRepository) {
        self.heartbeatRepository = heartbeatRepository
    }

    func execute(version: String) {
        heartbeatRepository.saveServerVersion(version)
    }
}
