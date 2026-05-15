import Foundation

protocol PSaveStore {
    func readBattery(romId: Int) throws -> Data?
    func writeBattery(romId: Int, data: Data) throws

    func listStates(romId: Int) throws -> [SaveStateEntry]
    func readState(romId: Int, slot: Int) throws -> Data?
    func writeState(romId: Int, slot: Int, data: Data) throws
    func deleteState(romId: Int, slot: Int) throws
}
