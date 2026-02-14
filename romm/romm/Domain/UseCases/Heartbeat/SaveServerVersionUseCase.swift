//
//  SaveServerVersionUseCase.swift
//  romm
//

import Foundation

class SaveServerVersionUseCase {
    private let heartbeatRepository: HeartbeatRepositoryProtocol

    init(heartbeatRepository: HeartbeatRepositoryProtocol) {
        self.heartbeatRepository = heartbeatRepository
    }

    func execute(version: String) {
        heartbeatRepository.saveServerVersion(version)
    }
}
