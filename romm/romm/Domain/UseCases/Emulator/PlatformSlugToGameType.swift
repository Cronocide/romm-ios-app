import Foundation

enum PlatformSlugToGameType {
    static func map(_ slug: String) -> DeltaGameType? {
        let s = slug.lowercased()
        if s == "gba" || s.contains("game boy advance") { return .gba }
        if s == "snes" || s == "super-nes" || s.contains("super nintendo") || s.contains("super-nes") { return .snes }
        if s == "genesis-slash-megadrive" || s == "genesis" || s == "megadrive" || s == "mega-drive" || s == "sega-genesis" || s.contains("mega drive") || s.contains("megadrive") || s.contains("genesis") { return .genesis }
        if s == "nes" || s == "famicom" || s == "fds" || s.contains("nintendo entertainment system") || s.contains("famicom") { return .nes }
        if s == "gbc" || s == "gb" || s == "sgb" || s.contains("game boy color") || s.contains("gameboy color") || s == "game-boy" || s == "gameboy" || s.contains("game boy") { return .gbc }
        if s == "n64" || s == "nintendo-64" || s.contains("nintendo 64") || s.contains("n64") { return .n64 }
        if s == "nds" || s == "ds" || s == "dsi" || s.contains("nintendo ds") || s.contains("nintendo-ds") { return .ds }
        return nil
    }
}
