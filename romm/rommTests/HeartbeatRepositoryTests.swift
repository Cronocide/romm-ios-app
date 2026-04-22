//
//  HeartbeatRepositoryTests.swift
//  rommTests
//

import Testing
@testable import romm

struct HeartbeatRepositoryTests {

    // MARK: - isVersionCompatible: development builds

    @Test func developmentVersionIsNotCompatible() {
        let repo = HeartbeatRepository()
        // "development" > maxSupportedServerVersion → belowMax-Check schlägt fehl
        #expect(repo.isVersionCompatible("development") == false)
    }

    // MARK: - isVersionCompatible: normale Releases

    @Test func minSupportedVersionIsCompatible() {
        let repo = HeartbeatRepository()
        #expect(repo.isVersionCompatible("4.1.0") == true)
    }

    @Test func maxSupportedVersionIsCompatible() {
        let repo = HeartbeatRepository()
        #expect(repo.isVersionCompatible("4.8.1") == true)
    }

    @Test func versionBelowMinIsNotCompatible() {
        let repo = HeartbeatRepository()
        #expect(repo.isVersionCompatible("4.0.9") == false)
    }

    @Test func versionAboveMaxIsNotCompatible() {
        let repo = HeartbeatRepository()
        #expect(repo.isVersionCompatible("4.9.0") == false)
    }

    @Test func prereleaseVersionStripsCorrectly() {
        let repo = HeartbeatRepository()
        // "4.8.0-alpha.1" → "4.8.0" → kompatibel
        #expect(repo.isVersionCompatible("4.8.0-alpha.1") == true)
    }
}

struct ConnectionLogFormatterTests {

    @Test func formattedLogContainsAppVersionHeader() {
        let entries: [ConnectionLogEntry] = [
            ConnectionLogEntry(message: "Checking URL", type: .info),
            ConnectionLogEntry(message: "Connection refused", type: .error, details: "ECONNREFUSED"),
        ]
        let result = ConnectionDebugPanel.formatLogsForClipboard(entries, appVersion: "1.2.3")
        #expect(result.hasPrefix("RomM iOS v1.2.3\n\n"))
    }

    @Test func formattedLogContainsEachEntryMessage() {
        let entries: [ConnectionLogEntry] = [
            ConnectionLogEntry(message: "Checking URL", type: .info),
            ConnectionLogEntry(message: "Connection refused", type: .error, details: "ECONNREFUSED"),
        ]
        let result = ConnectionDebugPanel.formatLogsForClipboard(entries, appVersion: "1.0.0")
        #expect(result.contains("Checking URL"))
        #expect(result.contains("Connection refused"))
        #expect(result.contains("ECONNREFUSED"))
    }

    @Test func formattedLogIncludesTimestamp() {
        let entries: [ConnectionLogEntry] = [
            ConnectionLogEntry(message: "Test", type: .info),
        ]
        let result = ConnectionDebugPanel.formatLogsForClipboard(entries, appVersion: "1.0.0")
        // Timestamp format HH:mm:ss — matches digits:digits:digits
        let hasTimestamp = result.range(of: #"\d{2}:\d{2}:\d{2}"#, options: .regularExpression) != nil
        #expect(hasTimestamp)
    }
}
