//
//  CheckServerVersionUseCase.swift
//  romm
//

import Foundation

class CheckServerVersionUseCase {
    private let heartbeatRepository: PHeartbeatRepository

    init(heartbeatRepository: PHeartbeatRepository) {
        self.heartbeatRepository = heartbeatRepository
    }

    /// Check server version with throttling. Returns heartbeat if check passes.
    /// Throws HeartbeatError.serverVersionChanged or HeartbeatError.serverVersionIncompatible
    func execute(allowIncompatibleVersion: Bool = false) async throws -> Heartbeat {
        // Throttle check
        if heartbeatRepository.shouldThrottleVersionCheck() {
            // Return cached version if throttled
            if let lastVersion = heartbeatRepository.getLastKnownServerVersion() {
                return Heartbeat(version: lastVersion)
            }
        }

        return try await heartbeatRepository.checkServerVersion(allowIncompatibleVersion: allowIncompatibleVersion)
    }

    /// Check if throttling should be applied
    func shouldThrottle() -> Bool {
        heartbeatRepository.shouldThrottleVersionCheck()
    }

    /// Minimum supported server version
    var minSupportedServerVersion: String {
        heartbeatRepository.minSupportedServerVersion
    }

    /// Maximum supported server version
    var maxSupportedServerVersion: String {
        heartbeatRepository.maxSupportedServerVersion
    }

    /// Check if a server version is compatible
    func isVersionCompatible(_ version: String) -> Bool {
        heartbeatRepository.isVersionCompatible(version)
    }
}
