//
//  ClearServerVersionUseCase.swift
//  romm
//

import Foundation

class ClearServerVersionUseCase {
    private let heartbeatRepository: HeartbeatRepositoryProtocol

    init(heartbeatRepository: HeartbeatRepositoryProtocol) {
        self.heartbeatRepository = heartbeatRepository
    }

    func execute() {
        heartbeatRepository.clearServerVersion()
    }
}
