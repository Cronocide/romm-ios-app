//
//  PHeartbeatRepository.swift
//  romm
//

import Foundation

protocol PHeartbeatRepository {
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

    /// Check server version with option to allow incompatible versions
    /// - Parameter allowIncompatibleVersion: If true, skips maximum version check
    func checkServerVersion(allowIncompatibleVersion: Bool) async throws -> Heartbeat

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

    /// Detect authentication capabilities including client token support
    func detectAuthCapabilities(serverURL: String) async -> HeartbeatRepository.AuthCapabilities
}
