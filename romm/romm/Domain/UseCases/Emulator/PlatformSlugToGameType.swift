import Foundation

enum PlatformSlugToGameType {
    static func map(_ slug: String) -> DeltaGameType? {
        switch slug.lowercased() {
        case "gba", "game boy advance": return .gba
        default: return nil
        }
    }
}
