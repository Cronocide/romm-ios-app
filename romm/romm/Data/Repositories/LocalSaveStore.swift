import Foundation

final class LocalSaveStore: PSaveStore {
    private let rootDirectory: URL
    private let fileManager = FileManager.default

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    convenience init() {
        let docs = try! FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        self.init(rootDirectory: docs.appendingPathComponent("Saves", isDirectory: true))
    }

    // MARK: - Battery

    func readBattery(romId: Int) throws -> Data? {
        let url = batteryURL(romId: romId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func writeBattery(romId: Int, data: Data) throws {
        try ensureDir(romId: romId)
        try data.write(to: batteryURL(romId: romId), options: .atomic)
    }

    // MARK: - State

    func listStates(romId: Int) throws -> [SaveStateEntry] {
        let dir = statesDir(romId: romId)
        guard fileManager.fileExists(atPath: dir.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        return urls.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension == "dltastate", let slot = Int(name) else { return nil }
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            return SaveStateEntry(slot: slot, modifiedAt: attrs?.contentModificationDate ?? Date())
        }
    }

    func readState(romId: Int, slot: Int) throws -> Data? {
        let url = stateURL(romId: romId, slot: slot)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func writeState(romId: Int, slot: Int, data: Data) throws {
        try ensureDir(romId: romId)
        let dir = statesDir(romId: romId)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: stateURL(romId: romId, slot: slot), options: .atomic)
    }

    func deleteState(romId: Int, slot: Int) throws {
        let url = stateURL(romId: romId, slot: slot)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Paths

    private func romDir(romId: Int) -> URL {
        rootDirectory.appendingPathComponent("\(romId)", isDirectory: true)
    }
    private func statesDir(romId: Int) -> URL {
        romDir(romId: romId).appendingPathComponent("states", isDirectory: true)
    }
    private func batteryURL(romId: Int) -> URL {
        romDir(romId: romId).appendingPathComponent("battery.sav")
    }
    private func stateURL(romId: Int, slot: Int) -> URL {
        statesDir(romId: romId).appendingPathComponent("\(slot).dltastate")
    }
    private func ensureDir(romId: Int) throws {
        try fileManager.createDirectory(at: romDir(romId: romId), withIntermediateDirectories: true)
    }
}
