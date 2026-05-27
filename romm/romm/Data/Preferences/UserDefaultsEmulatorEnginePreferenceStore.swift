import Foundation

final class UserDefaultsEmulatorEnginePreferenceStore: PEmulatorEnginePreference {
    private let key = "emulator.engine.preference"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var current: EmulatorEngine {
        get {
            guard let raw = userDefaults.string(forKey: key) else { return .web }
            if let engine = EmulatorEngine(rawValue: raw) { return engine }
            // Legacy: "deltaCore" used to be the raw value before rename to "native".
            if raw == "deltaCore" { return .native }
            return .web
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: key)
        }
    }
}
