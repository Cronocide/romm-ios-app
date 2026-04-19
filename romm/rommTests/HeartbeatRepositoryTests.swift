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
