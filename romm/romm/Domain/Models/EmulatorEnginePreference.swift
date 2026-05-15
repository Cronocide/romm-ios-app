import Foundation

protocol PEmulatorEnginePreference: AnyObject {
    var current: EmulatorEngine { get set }
}

final class EmulatorEnginePreference: PEmulatorEnginePreference {
    private let key = "emulator.engine.preference"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var current: EmulatorEngine {
        get {
            guard let raw = userDefaults.string(forKey: key),
                  let engine = EmulatorEngine(rawValue: raw) else {
                return .web
            }
            return engine
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: key)
        }
    }
}
