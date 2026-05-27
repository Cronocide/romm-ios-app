//
//  EmulatorEngineTests.swift
//  rommTests
//

import Testing
@testable import romm

struct EmulatorEngineTests {
    @Test func rawValuesArePersisted() {
        #expect(EmulatorEngine.web.rawValue == "web")
        #expect(EmulatorEngine.deltaCore.rawValue == "deltaCore")
        #expect(EmulatorEngine.auto.rawValue == "auto")
    }

    @Test func allCasesContainsAllEngines() {
        #expect(EmulatorEngine.allCases.count == 3)
    }
}
