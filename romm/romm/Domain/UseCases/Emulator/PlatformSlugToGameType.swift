import Foundation

enum PlatformSlugToGameType {
    static func map(_ slug: String) -> DeltaGameType? {
        let s = slug.lowercased()
        if s == "gba" || s.contains("game boy advance") { return .gba }
        return nil
    }
}
