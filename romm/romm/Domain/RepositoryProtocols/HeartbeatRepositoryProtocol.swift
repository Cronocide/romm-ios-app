//
//  HeartbeatRepositoryProtocol.swift
//  romm
//

import Foundation

protocol HeartbeatRepositoryProtocol {
    /// Minimum supported server version
    var minSupportedServerVersion: String { get }

    /// Maximum supported server version
    var maxSupportedServerVersion: String { get }

    /// Throttle interval for version checks in seconds
    var versionCheckThrottleSeconds: TimeInterval { get }

    /// Fetch heartbeat from server
    func getHeartbeat() async throws -> Heartbeat

    /// Fetch heartbeat from a specific URL (for setup before login)
    func getHeartbeat(from serverURL: String) async throws -> Heartbeat

    /// Check server version, throws HeartbeatError if incompatible or changed
    func checkServerVersion() async throws -> Heartbeat

    /// Get last known server version from storage
    func getLastKnownServerVersion() -> String?

    /// Get last version check time from storage
    func getLastVersionCheckTime() -> Date?

    /// Save server version to storage
    func saveServerVersion(_ version: String)

    /// Clear stored server version
    func clearServerVersion()

    /// Check if version check should be throttled
    func shouldThrottleVersionCheck() -> Bool

    /// Compare two semantic versions. Returns true if version >= minVersion
    func isVersionCompatible(_ version: String) -> Bool
}
