//
//  HeartbeatRepository.swift
//  romm
//

import Foundation

class HeartbeatRepository: PHeartbeatRepository {
    private let logger = Logger.data
    private let oidcLogger = Logger.oidc // Separate logger for OIDC detection
    private let apiClient: RommAPIClient
    private let userDefaults: UserDefaults

    // MARK: - Constants

    let minSupportedServerVersion = "4.1.0"
    let maxSupportedServerVersion = "4.8.1"
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
            logger.warning(
                "Server version \(serverVersion) is below minimum \(minSupportedServerVersion)")
            throw HeartbeatError.serverVersionTooLow(
                serverVersion: serverVersion,
                minRequired: minSupportedServerVersion
            )
        }

        // Check if version is above maximum
        if compareVersions(serverVersion, maxSupportedServerVersion) > 0 {
            logger.warning(
                "Server version \(serverVersion) is above maximum \(maxSupportedServerVersion)")
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

    func checkServerVersion(allowIncompatibleVersion: Bool) async throws -> Heartbeat {
        let heartbeat = try await getHeartbeat()
        let serverVersion = heartbeat.version

        // Check if version changed since last known
        if let lastKnown = getLastKnownServerVersion(), lastKnown != serverVersion {
            logger.warning("Server version changed from \(lastKnown) to \(serverVersion)")
            throw HeartbeatError.serverVersionChanged(from: lastKnown, to: serverVersion)
        }

        // If user allowed incompatible versions, only check minimum (not maximum)
        if allowIncompatibleVersion {
            logger.info("Incompatible version login allowed - skipping maximum version check")

            // Only check minimum version (critical incompatibility)
            if compareVersions(serverVersion, minSupportedServerVersion) < 0 {
                logger.warning(
                    "Server version \(serverVersion) is below minimum \(minSupportedServerVersion)")
                throw HeartbeatError.serverVersionTooLow(
                    serverVersion: serverVersion,
                    minRequired: minSupportedServerVersion
                )
            }
        } else {
            // Standard checks for both minimum and maximum
            if compareVersions(serverVersion, minSupportedServerVersion) < 0 {
                logger.warning(
                    "Server version \(serverVersion) is below minimum \(minSupportedServerVersion)")
                throw HeartbeatError.serverVersionTooLow(
                    serverVersion: serverVersion,
                    minRequired: minSupportedServerVersion
                )
            }

            if compareVersions(serverVersion, maxSupportedServerVersion) > 0 {
                logger.warning(
                    "Server version \(serverVersion) is above maximum \(maxSupportedServerVersion)")
                throw HeartbeatError.serverVersionTooHigh(
                    serverVersion: serverVersion,
                    maxSupported: maxSupportedServerVersion
                )
            }
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
        // Strip pre-release suffixes (e.g. "4.8.0-alpha.1" → "4.8.0")
        let base1 = version1.split(separator: "-").first.map(String.init) ?? version1
        let base2 = version2.split(separator: "-").first.map(String.init) ?? version2
        let v1Parts = base1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = base2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Parts.count, v2Parts.count)

        for i in 0..<maxLength {
            let v1 = i < v1Parts.count ? v1Parts[i] : 0
            let v2 = i < v2Parts.count ? v2Parts[i] : 0

            if v1 < v2 { return -1 }
            if v1 > v2 { return 1 }
        }

        return 0
    }

    // MARK: - Server Capability Detection

    enum ServerAuthCapability {
        case classicOnly
        case oidcOnly
        case both
        case cloudflareBlocked
        case unreachable

        var description: String {
            switch self {
            case .classicOnly:
                return "Classic authentication (Username/Password)"
            case .oidcOnly:
                return "OIDC/SSO authentication only"
            case .both:
                return "Both classic and OIDC authentication supported"
            case .cloudflareBlocked:
                return "Server blocked by Cloudflare - no OIDC available"
            case .unreachable:
                return "Server unreachable"
            }
        }

        var requiresOIDC: Bool {
            switch self {
            case .oidcOnly:
                return true
            default:
                return false
            }
        }

        var supportsClassic: Bool {
            switch self {
            case .classicOnly, .both:
                return true
            default:
                return false
            }
        }

        var supportsOIDC: Bool {
            switch self {
            case .oidcOnly, .both:
                return true
            default:
                return false
            }
        }
    }

    func detectAuthCapability(serverURL: String) async -> ServerAuthCapability {
        oidcLogger.info("🔍 Detecting authentication capabilities for: \(serverURL)")

        var hasCloudflare = false
        var classicAuthWorks = false
        var hasOIDC = false
        var heartbeatResponse: HeartbeatResponse?

        // 1. Try heartbeat (will detect Cloudflare and test classic auth)
        do {
            let response = try await apiClient.getHeartbeat(from: serverURL)
            heartbeatResponse = response
            classicAuthWorks = true
            oidcLogger.info("✅ Classic auth works - heartbeat successful")
            
            // Check if OIDC is enabled in heartbeat response
            if response.OIDC.ENABLED {
                hasOIDC = true
                oidcLogger.info("✅ OIDC is enabled in server config (provider: \(response.OIDC.PROVIDER))")
            } else {
                oidcLogger.info("❌ OIDC is disabled in server config")
            }
            
            // Check if classic auth is disabled
            if response.FRONTEND.DISABLE_USERPASS_LOGIN {
                classicAuthWorks = false
                oidcLogger.warning("⚠️ Classic username/password login is disabled on server")
            }
        } catch let error as APIClientError {
            if case .cloudflareProtection = error {
                hasCloudflare = true
                oidcLogger.warning("🔒 Cloudflare protection detected")
            } else {
                oidcLogger.error("Heartbeat failed with error: \(error)")
            }
        } catch {
            oidcLogger.error("Heartbeat failed with unexpected error: \(error)")
        }

        // 2. If we couldn't get heartbeat (e.g. Cloudflare), check OIDC discovery endpoint
        if heartbeatResponse == nil {
            hasOIDC = await apiClient.checkOIDCAvailability(serverURL: serverURL)
            if hasOIDC {
                oidcLogger.info("✅ OIDC discovery endpoint is available")
            } else {
                oidcLogger.info("❌ OIDC discovery endpoint not available")
                
                // If Cloudflare is detected, assume OIDC might be available
                // even if .well-known is not accessible (also behind Cloudflare)
                if hasCloudflare {
                    oidcLogger.warning("⚠️ Cloudflare detected - assuming OIDC might be available with default config")
                    hasOIDC = true // Optimistic assumption for Cloudflare scenarios
                }
            }
        }

        // 3. Determine capability
        let capability: ServerAuthCapability
        if hasCloudflare && hasOIDC {
            capability = .oidcOnly
            oidcLogger.info("🎯 Result: OIDC only (Cloudflare protection active)")
        } else if hasCloudflare && !hasOIDC {
            capability = .cloudflareBlocked
            oidcLogger.warning("⚠️ Result: Server blocked by Cloudflare, no OIDC configured")
        } else if classicAuthWorks && hasOIDC {
            capability = .both
            oidcLogger.info("🎯 Result: Both authentication methods available")
        } else if classicAuthWorks && !hasOIDC {
            capability = .classicOnly
            oidcLogger.info("🎯 Result: Classic authentication only")
        } else if !classicAuthWorks && hasOIDC {
            capability = .oidcOnly
            oidcLogger.info("🎯 Result: OIDC only (classic auth disabled)")
        } else {
            capability = .unreachable
            oidcLogger.error("❌ Result: Server unreachable")
        }

        return capability
    }

    // MARK: - Auth Capabilities (Rich)

    struct AuthCapabilities {
        let classic: Bool
        let oidc: Bool
        let clientTokens: Bool
        let cloudflareBlocked: Bool
        let unreachable: Bool

        init(from legacy: ServerAuthCapability, clientTokens: Bool = false) {
            switch legacy {
            case .classicOnly:
                self.init(classic: true, oidc: false, clientTokens: clientTokens, cloudflareBlocked: false, unreachable: false)
            case .oidcOnly:
                self.init(classic: false, oidc: true, clientTokens: clientTokens, cloudflareBlocked: false, unreachable: false)
            case .both:
                self.init(classic: true, oidc: true, clientTokens: clientTokens, cloudflareBlocked: false, unreachable: false)
            case .cloudflareBlocked:
                self.init(classic: false, oidc: false, clientTokens: false, cloudflareBlocked: true, unreachable: false)
            case .unreachable:
                self.init(classic: false, oidc: false, clientTokens: false, cloudflareBlocked: false, unreachable: true)
            }
        }

        init(classic: Bool, oidc: Bool, clientTokens: Bool, cloudflareBlocked: Bool, unreachable: Bool) {
            self.classic = classic
            self.oidc = oidc
            self.clientTokens = clientTokens
            self.cloudflareBlocked = cloudflareBlocked
            self.unreachable = unreachable
        }

        var description: String {
            if unreachable { return "Server unreachable" }
            if cloudflareBlocked { return "Server blocked by Cloudflare" }
            var methods: [String] = []
            if classic { methods.append("Classic") }
            if oidc { methods.append("OIDC") }
            if clientTokens { methods.append("Client Tokens") }
            return methods.isEmpty ? "No auth methods available" : methods.joined(separator: ", ")
        }

        var supportsClassic: Bool { classic }
        var supportsOIDC: Bool { oidc }
        var supportsClientTokens: Bool { clientTokens }
    }

    /// Minimum server version that supports client API tokens (PR #3114)
    private let minClientTokenVersion = "4.8.0"

    func detectAuthCapabilities(serverURL: String) async -> AuthCapabilities {
        let legacy = await detectAuthCapability(serverURL: serverURL)
        var hasClientTokens = false
        do {
            let response = try await apiClient.getHeartbeat(from: serverURL)
            if let clientTokensConfig = response.CLIENT_TOKENS {
                hasClientTokens = clientTokensConfig.ENABLED
                oidcLogger.info("Client tokens enabled via heartbeat: \(hasClientTokens)")
            } else {
                // Fallback: check server version >= 4.8.0
                let version = response.SYSTEM.VERSION
                let baseVersion = version.split(separator: "-").first.map(String.init) ?? version
                if compareVersions(baseVersion, minClientTokenVersion) >= 0 {
                    hasClientTokens = true
                    oidcLogger.info("Client tokens assumed available (server \(version) >= \(minClientTokenVersion))")
                } else {
                    oidcLogger.info("Server \(version) too old for client tokens")
                }
            }
        } catch {
            oidcLogger.debug("Could not check client token support: \(error)")
        }
        return AuthCapabilities(from: legacy, clientTokens: hasClientTokens)
    }
}
