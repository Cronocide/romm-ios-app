import Foundation

final class UserDefaultsLibretroAspectRatioPreferenceStore: PLibretroAspectRatioPreference {
    private let psxKey = "libretro.aspectRatio.psx"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var psx: LibretroAspectRatio {
        get {
            guard let raw = userDefaults.string(forKey: psxKey),
                  let value = LibretroAspectRatio(rawValue: raw) else {
                return .fourThree
            }
            return value
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: psxKey)
        }
    }
}
