import Testing
import Foundation
@testable import romm

struct LocalSaveStoreRepositoryTests {

    private func makeStore() -> (LocalSaveStoreRepository, URL) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalSaveStoreRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return (LocalSaveStoreRepository(rootDirectory: tmp), tmp)
    }

    @Test func batteryRoundtrip() throws {
        let (store, _) = makeStore()
        let payload = Data([0xCA, 0xFE])
        try store.writeBattery(romId: 42, data: payload)
        #expect(try store.readBattery(romId: 42) == payload)
    }

    @Test func batteryReturnsNilWhenMissing() throws {
        let (store, _) = makeStore()
        #expect(try store.readBattery(romId: 99) == nil)
    }

    @Test func stateRoundtripAndList() throws {
        let (store, _) = makeStore()
        try store.writeState(romId: 1, slot: 1, data: Data([0x01]))
        try store.writeState(romId: 1, slot: 2, data: Data([0x02]))
        let entries = try store.listStates(romId: 1)
        #expect(entries.map(\.slot).sorted() == [1, 2])
        #expect(try store.readState(romId: 1, slot: 1) == Data([0x01]))
    }

    @Test func deleteState() throws {
        let (store, _) = makeStore()
        try store.writeState(romId: 1, slot: 1, data: Data([0x01]))
        try store.deleteState(romId: 1, slot: 1)
        #expect(try store.readState(romId: 1, slot: 1) == nil)
    }
}
