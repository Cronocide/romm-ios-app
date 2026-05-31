import Foundation

enum LibretroAspectRatio: String, CaseIterable, Identifiable {
    case fourThree = "4_3"
    case sixteenNine = "16_9"
    case fill = "fill"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fourThree:   return "4:3"
        case .sixteenNine: return "16:9"
        case .fill:        return "Full width"
        }
    }

    /// width / height. `nil` means fill the available area without constraint.
    var ratio: CGFloat? {
        switch self {
        case .fourThree:   return 4.0 / 3.0
        case .sixteenNine: return 16.0 / 9.0
        case .fill:        return nil
        }
    }
}

enum LibretroAspectRatioPreference {
    static let psxKey = "libretro.aspectRatio.psx"

    static var psx: LibretroAspectRatio {
        get {
            guard let raw = UserDefaults.standard.string(forKey: psxKey),
                  let value = LibretroAspectRatio(rawValue: raw) else {
                return .fourThree
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: psxKey)
        }
    }
}
