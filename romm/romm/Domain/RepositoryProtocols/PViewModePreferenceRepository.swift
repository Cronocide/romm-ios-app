import Foundation

protocol PViewModePreferenceRepository {
    func get() -> ViewMode
    func set(_ viewMode: ViewMode)
}
