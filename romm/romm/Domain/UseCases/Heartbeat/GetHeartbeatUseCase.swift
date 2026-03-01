//
//  GetHeartbeatUseCase.swift
//  romm
//

import Foundation

class GetHeartbeatUseCase {
    private let heartbeatRepository: PHeartbeatRepository

    init(heartbeatRepository: PHeartbeatRepository) {
        self.heartbeatRepository = heartbeatRepository
    }

    ///
    func execute(from serverURL: String? = nil) async throws -> Heartbeat {
        if let serverURL {
            return try await heartbeatRepository.getHeartbeat(from: serverURL)
        }
        return try await heartbeatRepository.getHeartbeat()
    }
}
