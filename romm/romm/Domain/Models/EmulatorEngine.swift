import Foundation

enum EmulatorEngine: String, CaseIterable, Codable, Sendable {
    case web
    case deltaCore
    case libretro
    case auto
}
