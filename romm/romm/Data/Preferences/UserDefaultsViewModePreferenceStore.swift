import Foundation

final class UserDefaultsViewModePreferenceStore: PViewModePreferenceRepository {
    private let key = "selectedViewMode"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func get() -> ViewMode {
        if let raw = userDefaults.string(forKey: key), let mode = ViewMode(rawValue: raw) {
            return mode
        }
        return .smallCard
    }

    func set(_ viewMode: ViewMode) {
        userDefaults.set(viewMode.rawValue, forKey: key)
    }
}
