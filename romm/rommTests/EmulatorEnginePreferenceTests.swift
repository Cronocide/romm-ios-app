import Testing
import Foundation
@testable import romm

struct EmulatorEnginePreferenceTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultIsWeb() {
        let defaults = makeDefaults()
        let pref = EmulatorEnginePreference(userDefaults: defaults)
        #expect(pref.current == .web)
    }

    @Test func persistsAcrossInstances() {
        let defaults = makeDefaults()
        let pref1 = EmulatorEnginePreference(userDefaults: defaults)
        pref1.current = .native
        let pref2 = EmulatorEnginePreference(userDefaults: defaults)
        #expect(pref2.current == .native)
    }

    @Test func unknownRawValueFallsBackToWeb() {
        let defaults = makeDefaults()
        defaults.set("xxx", forKey: "emulator.engine.preference")
        let pref = EmulatorEnginePreference(userDefaults: defaults)
        #expect(pref.current == .web)
    }
}
