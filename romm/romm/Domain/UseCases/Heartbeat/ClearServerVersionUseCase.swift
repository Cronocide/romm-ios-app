//
//  ClearServerVersionUseCase.swift
//  romm
//

import Foundation

class ClearServerVersionUseCase {
    private let heartbeatRepository: PHeartbeatRepository

    init(heartbeatRepository: PHeartbeatRepository) {
        self.heartbeatRepository = heartbeatRepository
    }

    func execute() {
        heartbeatRepository.clearServerVersion()
    }
}
