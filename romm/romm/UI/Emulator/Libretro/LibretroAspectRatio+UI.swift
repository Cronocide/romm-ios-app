import CoreGraphics
import Foundation

extension LibretroAspectRatio {
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
