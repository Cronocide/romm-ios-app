import Foundation

enum LibretroCore: String, Codable, Sendable {
    case pcsxRearmed = "pcsx_rearmed"
    // Zukünftig: case ppsspp, case beetlePsx, ...

    var dylibName: String {
        switch self {
        case .pcsxRearmed: return "pcsx_rearmed_libretro_ios"
        }
    }

    var displayName: String {
        switch self {
        case .pcsxRearmed: return "PlayStation (PCSX ReARMed)"
        }
    }

    var allowedExtensions: Set<String> {
        switch self {
        case .pcsxRearmed:
            return ["bin", "cue", "iso", "img", "mdf", "pbp", "chd", "ecm", "m3u", "toc"]
        }
    }
}

enum PlatformSlugToLibretroCore {
    static func map(_ slug: String) -> LibretroCore? {
        let s = slug.lowercased()
        if s == "ps" || s == "ps1" || s == "psx" || s == "playstation"
            || s.contains("playstation 1") || s.contains("playstation-1")
            || s == "sony-playstation" {
            return .pcsxRearmed
        }
        return nil
    }
}
