//
//  HeartbeatRepository.swift
//  romm
//

import Foundation

class HeartbeatRepository: HeartbeatRepositoryProtocol {
    private let logger = Logger.data
    private let apiClient: RommAPIClient
    private let userDefaults: UserDefaults

    // MARK: - Constants

    let minSupportedServerVersion = "4.1.0"
    let maxSupportedServerVersion = "4.5.0"
    let versionCheckThrottleSeconds: TimeInterval = 30

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lastKnownServerVersion = "heartbeat.lastKnownServerVersion"
        static let lastVersionCheckTime = "heartbeat.lastVersionCheckTime"
    }

    // MARK: - Init

    init(
        apiClient: RommAPIClient = RommAPIClient.shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.apiClient = apiClient
        self.userDefaults = userDefaults
    }

    // MARK: - Fetch Heartbeat

    func getHeartbeat() async throws -> Heartbeat {
        logger.info("Getting heartbeat from API...")

        do {
            let response = try await apiClient.getHeartbeat()
            let heartbeat = Heartbeat(version: response.SYSTEM.VERSION)
            logger.info("Retrieved server version: \(heartbeat.version)")
            return heartbeat
        } catch {
            logger.error("Error getting heartbeat: \(error)")
            throw HeartbeatError.networkError(error)
        }
    }

    func getHeartbeat(from serverURL: String) async throws -> Heartbeat {
        logger.info("Getting heartbeat from URL: \(serverURL)")

        do {
            let response = try await apiClient.getHeartbeat(from: serverURL)
            let heartbeat = Heartbeat(version: response.SYSTEM.VERSION)
            logger.info("Retrieved server version from URL: \(heartbeat.version)")
            return heartbeat
        } catch {
            logger.error("Error getting heartbeat from URL: \(error)")
            throw HeartbeatError.networkError(error)
        }
    }

    // MARK: - Check Server Version

    func checkServerVersion() async throws -> Heartbeat {
        let heartbeat = try await getHeartbeat()
        let serverVersion = heartbeat.version

        // Check if version changed since last known
        if let lastKnown = getLastKnownServerVersion(), lastKnown != serverVersion {
            logger.warning("Server version changed from \(lastKnown) to \(serverVersion)")
            throw HeartbeatError.serverVersionChanged(from: lastKnown, to: serverVersion)
        }

        // Check if version is below minimum
        if compareVersions(serverVersion, minSupportedServerVersion) < 0 {
            logger.warning("Server version \(serverVersion) is below minimum \(minSupportedServerVersion)")
            throw HeartbeatError.serverVersionTooLow(
                serverVersion: serverVersion,
                minRequired: minSupportedServerVersion
            )
        }

        // Check if version is above maximum
        if compareVersions(serverVersion, maxSupportedServerVersion) > 0 {
            logger.warning("Server version \(serverVersion) is above maximum \(maxSupportedServerVersion)")
            throw HeartbeatError.serverVersionTooHigh(
                serverVersion: serverVersion,
                maxSupported: maxSupportedServerVersion
            )
        }

        // Update stored version
        saveServerVersion(serverVersion)
        logger.info("Server version check passed: \(serverVersion)")

        return heartbeat
    }

    // MARK: - Storage

    func getLastKnownServerVersion() -> String? {
        userDefaults.string(forKey: Keys.lastKnownServerVersion)
    }

    func getLastVersionCheckTime() -> Date? {
        userDefaults.object(forKey: Keys.lastVersionCheckTime) as? Date
    }

    func saveServerVersion(_ version: String) {
        userDefaults.set(version, forKey: Keys.lastKnownServerVersion)
        userDefaults.set(Date(), forKey: Keys.lastVersionCheckTime)
        logger.debug("Saved server version: \(version)")
    }

    func clearServerVersion() {
        userDefaults.removeObject(forKey: Keys.lastKnownServerVersion)
        userDefaults.removeObject(forKey: Keys.lastVersionCheckTime)
        logger.debug("Cleared stored server version")
    }

    // MARK: - Throttling

    func shouldThrottleVersionCheck() -> Bool {
        guard let lastCheck = getLastVersionCheckTime() else {
            return false
        }
        let elapsed = Date().timeIntervalSince(lastCheck)
        return elapsed < versionCheckThrottleSeconds
    }

    // MARK: - Version Comparison

    func isVersionCompatible(_ version: String) -> Bool {
        let aboveMin = compareVersions(version, minSupportedServerVersion) >= 0
        let belowMax = compareVersions(version, maxSupportedServerVersion) <= 0
        return aboveMin && belowMax
    }

    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let v1Parts = version1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = version2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Parts.count, v2Parts.count)

        for i in 0..<maxLength {
            let v1 = i < v1Parts.count ? v1Parts[i] : 0
            let v2 = i < v2Parts.count ? v2Parts[i] : 0

            if v1 < v2 { return -1 }
            if v1 > v2 { return 1 }
        }

        return 0
    }
}
