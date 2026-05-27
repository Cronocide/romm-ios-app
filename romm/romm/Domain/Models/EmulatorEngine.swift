import Foundation

enum EmulatorEngine: String, CaseIterable, Codable, Sendable {
    case web
    case native
    case auto
}
