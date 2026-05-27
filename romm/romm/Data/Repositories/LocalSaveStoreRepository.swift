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
        let thumb = thumbURL(romId: romId, slot: slot)
        if fileManager.fileExists(atPath: thumb.path) {
            try fileManager.removeItem(at: thumb)
        }
    }

    func stateModifiedAt(romId: Int, slot: Int) -> Date? {
        let url = stateURL(romId: romId, slot: slot)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return attrs?.contentModificationDate
    }

    // MARK: - Thumbnail

    func readThumbnail(romId: Int, slot: Int) throws -> Data? {
        let url = thumbURL(romId: romId, slot: slot)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func writeThumbnail(romId: Int, slot: Int, data: Data) throws {
        try ensureDir(romId: romId)
        try fileManager.createDirectory(at: statesDir(romId: romId), withIntermediateDirectories: true)
        try data.write(to: thumbURL(romId: romId, slot: slot), options: .atomic)
    }

    // MARK: - Undo Save

    func backupSlotForUndoSave(romId: Int, slot: Int) throws {
        try ensureDir(romId: romId)
        try fileManager.createDirectory(at: statesDir(romId: romId), withIntermediateDirectories: true)
        try copyOverwrite(from: stateURL(romId: romId, slot: slot),
                          to: undoSaveStateURL(romId: romId, slot: slot))
        try copyOverwrite(from: thumbURL(romId: romId, slot: slot),
                          to: undoSaveThumbURL(romId: romId, slot: slot))
    }

    func restoreSlotFromUndoSave(romId: Int, slot: Int) throws -> Bool {
        let stateSrc = undoSaveStateURL(romId: romId, slot: slot)
        guard fileManager.fileExists(atPath: stateSrc.path) else {
            // No prior state existed — restoring means deleting current slot.
            try deleteState(romId: romId, slot: slot)
            // Drop the empty undo marker if any.
            removeIfExists(undoSaveStateURL(romId: romId, slot: slot))
            removeIfExists(undoSaveThumbURL(romId: romId, slot: slot))
            return true
        }
        try copyOverwrite(from: stateSrc, to: stateURL(romId: romId, slot: slot))
        try copyOverwrite(from: undoSaveThumbURL(romId: romId, slot: slot),
                          to: thumbURL(romId: romId, slot: slot))
        removeIfExists(stateSrc)
        removeIfExists(undoSaveThumbURL(romId: romId, slot: slot))
        return true
    }

    func hasUndoSave(romId: Int, slot: Int) -> Bool {
        fileManager.fileExists(atPath: undoSaveStateURL(romId: romId, slot: slot).path)
    }

    // MARK: - Undo Load

    func writeUndoLoadSnapshot(romId: Int, stateData: Data, thumbnailData: Data?) throws {
        try ensureDir(romId: romId)
        try fileManager.createDirectory(at: statesDir(romId: romId), withIntermediateDirectories: true)
        try stateData.write(to: undoLoadStateURL(romId: romId), options: .atomic)
        if let thumbnailData {
            try thumbnailData.write(to: undoLoadThumbURL(romId: romId), options: .atomic)
        } else {
            removeIfExists(undoLoadThumbURL(romId: romId))
        }
    }

    func readUndoLoadState(romId: Int) throws -> Data? {
        let url = undoLoadStateURL(romId: romId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func readUndoLoadThumbnail(romId: Int) throws -> Data? {
        let url = undoLoadThumbURL(romId: romId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func hasUndoLoad(romId: Int) -> Bool {
        fileManager.fileExists(atPath: undoLoadStateURL(romId: romId).path)
    }

    func clearUndoLoad(romId: Int) throws {
        removeIfExists(undoLoadStateURL(romId: romId))
        removeIfExists(undoLoadThumbURL(romId: romId))
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
    private func thumbURL(romId: Int, slot: Int) -> URL {
        statesDir(romId: romId).appendingPathComponent("\(slot).png")
    }
    private func undoSaveStateURL(romId: Int, slot: Int) -> URL {
        statesDir(romId: romId).appendingPathComponent("\(slot).dltastate.undo")
    }
    private func undoSaveThumbURL(romId: Int, slot: Int) -> URL {
        statesDir(romId: romId).appendingPathComponent("\(slot).png.undo")
    }
    private func undoLoadStateURL(romId: Int) -> URL {
        statesDir(romId: romId).appendingPathComponent("undo-load.dltastate")
    }
    private func undoLoadThumbURL(romId: Int) -> URL {
        statesDir(romId: romId).appendingPathComponent("undo-load.png")
    }
    private func ensureDir(romId: Int) throws {
        try fileManager.createDirectory(at: romDir(romId: romId), withIntermediateDirectories: true)
    }

    private func copyOverwrite(from src: URL, to dst: URL) throws {
        guard fileManager.fileExists(atPath: src.path) else {
            removeIfExists(dst)
            return
        }
        removeIfExists(dst)
        try fileManager.copyItem(at: src, to: dst)
    }

    private func removeIfExists(_ url: URL) {
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
}
