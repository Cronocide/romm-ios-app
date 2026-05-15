import Foundation

enum SaveKind: Equatable {
    case battery
    case state(slot: Int)
}

struct SaveStateEntry: Equatable, Identifiable {
    let slot: Int
    let modifiedAt: Date
    var id: Int { slot }
}
