import Foundation

enum LibretroAspectRatio: String, CaseIterable, Identifiable {
    case fourThree = "4_3"
    case sixteenNine = "16_9"
    case fill = "fill"

    var id: String { rawValue }
}
