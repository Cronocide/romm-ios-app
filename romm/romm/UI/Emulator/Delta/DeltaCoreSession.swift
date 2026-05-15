import Foundation
import UIKit
import DeltaCore
import GBADeltaCore

@MainActor
final class DeltaCoreSession {

    private let gameURL: URL
    private let gameType: GameType
    private let saveStore: PSaveStore
    private let romId: Int

    let viewController: GameViewController

    // Captured after setting vc.game, since setting game triggers emulatorCore creation.
    private var emulatorCore: EmulatorCore? {
        viewController.emulatorCore
    }

    init(gameURL: URL, gameType: GameType, romId: Int, saveStore: PSaveStore) {
        self.gameURL = gameURL
        self.gameType = gameType
        self.romId = romId
        self.saveStore = saveStore

        let vc = GameViewController()
        let game = Game(fileURL: gameURL, type: gameType)
        vc.game = game
        self.viewController = vc
    }

    // MARK: - Lifecycle

    func start() {
        loadBatteryIfAvailable()
        viewController.startEmulation()
    }

    func pause() {
        viewController.pauseEmulation()
    }

    func resume() {
        viewController.resumeEmulation()
    }

    func stop() {
        flushBattery()
        emulatorCore?.stop()
    }

    // MARK: - Save States

    func saveState(slot: Int) throws {
        guard let core = emulatorCore else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("state-\(UUID().uuidString).dltastate")
        core.saveSaveState(to: tmp)
        let data = try Data(contentsOf: tmp)
        try saveStore.writeState(romId: romId, slot: slot, data: data)
        try? FileManager.default.removeItem(at: tmp)
    }

    func loadState(slot: Int) throws {
        guard let core = emulatorCore else { return }
        guard let data = try saveStore.readState(romId: romId, slot: slot) else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("state-\(UUID().uuidString).dltastate")
        try data.write(to: tmp)
        try core.load(SaveState(fileURL: tmp, gameType: gameType))
        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - Battery
    //
    // DeltaCore manages the battery save automatically via `EmulatorCore.save()` writing to
    // `game.gameSaveURL` (a .sav file next to the ROM). There is no `GameSave` type or
    // `emulatorCore.gameSave` property in the live API.
    //
    // Strategy: before start(), seed game.gameSaveURL from our store so DeltaCore picks it up
    // on load. After stop(), read game.gameSaveURL back into our store.

    private func loadBatteryIfAvailable() {
        guard let data = try? saveStore.readBattery(romId: romId) else { return }
        let savURL = Game(fileURL: gameURL, type: gameType).gameSaveURL
        try? data.write(to: savURL)
    }

    private func flushBattery() {
        // Trigger DeltaCore's internal battery flush to gameSaveURL, then copy to our store.
        emulatorCore?.save()
        let savURL = Game(fileURL: gameURL, type: gameType).gameSaveURL
        if let data = try? Data(contentsOf: savURL) {
            try? saveStore.writeBattery(romId: romId, data: data)
        }
    }
}
