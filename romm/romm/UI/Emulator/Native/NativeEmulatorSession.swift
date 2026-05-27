import Foundation
import UIKit
import DeltaCore
import GBADeltaCore

/// GameViewController subclass that forces the on-screen controller skin to
/// reload after a rotation. DeltaCore only loads the skin image on initial
/// layout, so without this the portrait skin stays active in landscape and the
/// controller renders as a centered portrait-aspect block.
final class RommGameViewController: GameViewController {
    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.controllerView?.updateControllerSkin()
        }
    }
}

@MainActor
final class DeltaCoreSession: NSObject, GameViewControllerDelegate {

    private let gameURL: URL
    private let gameType: GameType
    private let saveStore: PSaveStore
    private let romId: Int

    var onMenuRequested: (() -> Void)?

    let viewController: GameViewController

    // MARK: - GameViewControllerDelegate

    func gameViewController(_ gameViewController: GameViewController, handleMenuInputFrom gameController: GameController) {
        onMenuRequested?()
    }

    private var emulatorCore: EmulatorCore? {
        viewController.emulatorCore
    }

    init(gameURL: URL, gameType: GameType, romId: Int, saveStore: PSaveStore) {
        self.gameURL = gameURL
        self.gameType = gameType
        self.romId = romId
        self.saveStore = saveStore

        let vc = RommGameViewController()
        vc.loadViewIfNeeded()
        let game = Game(fileURL: gameURL, type: gameType)
        vc.game = game
        vc.controllerView?.playerIndex = 0
        self.viewController = vc
        super.init()
        vc.delegate = self
    }

    // MARK: - Slot info

    func hasState(slot: Int) -> Bool {
        (try? saveStore.readState(romId: romId, slot: slot)) != nil
    }

    func stateModifiedAt(slot: Int) -> Date? {
        saveStore.stateModifiedAt(romId: romId, slot: slot)
    }

    func thumbnail(slot: Int) -> UIImage? {
        guard let data = try? saveStore.readThumbnail(romId: romId, slot: slot) else { return nil }
        return UIImage(data: data)
    }

    func hasUndoSave(slot: Int) -> Bool { saveStore.hasUndoSave(romId: romId, slot: slot) }
    func hasUndoLoad() -> Bool { saveStore.hasUndoLoad(romId: romId) }

    func undoLoadThumbnail() -> UIImage? {
        guard let data = try? saveStore.readUndoLoadThumbnail(romId: romId) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Lifecycle

    func start() {
        loadBatteryIfAvailable()
        viewController.startEmulation()
        attachExternalControllers()
        observeControllerConnections()
    }

    func pause() { viewController.pauseEmulation() }
    func resume() { viewController.resumeEmulation() }

    func stop() {
        flushBattery()
        detachExternalControllers()
        NotificationCenter.default.removeObserver(self)
        emulatorCore?.stop()
    }

    // MARK: - External Controllers

    private func attachExternalControllers() {
        guard let core = emulatorCore else { return }
        var nextIndex = 0
        for controller in ExternalGameControllerManager.shared.connectedControllers {
            controller.playerIndex = nextIndex
            controller.addReceiver(core)
            controller.addReceiver(viewController)
            nextIndex += 1
        }
        updateOnScreenControlsVisibility()
    }

    private func detachExternalControllers() {
        guard let core = emulatorCore else { return }
        for controller in ExternalGameControllerManager.shared.connectedControllers {
            controller.removeReceiver(core)
            controller.removeReceiver(viewController)
        }
    }

    private func observeControllerConnections() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(externalControllerDidConnect(_:)),
            name: .externalGameControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(externalControllerDidDisconnect(_:)),
            name: .externalGameControllerDidDisconnect,
            object: nil
        )
    }

    @objc private func externalControllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GameController,
              let core = emulatorCore else { return }
        let usedIndexes = Set(ExternalGameControllerManager.shared.connectedControllers.compactMap { $0.playerIndex })
        var nextIndex = 0
        while usedIndexes.contains(nextIndex) { nextIndex += 1 }
        controller.playerIndex = nextIndex
        controller.addReceiver(core)
        controller.addReceiver(viewController)
        updateOnScreenControlsVisibility()
    }

    @objc private func externalControllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GameController,
              let core = emulatorCore else { return }
        controller.removeReceiver(core)
        controller.removeReceiver(viewController)
        updateOnScreenControlsVisibility()
    }

    private func updateOnScreenControlsVisibility() {
        let hasExternal = !ExternalGameControllerManager.shared.connectedControllers.isEmpty
        viewController.controllerView?.isHidden = hasExternal
    }

    // MARK: - Save / Load

    func saveState(slot: Int) throws {
        guard let core = emulatorCore else { return }
        try saveStore.backupSlotForUndoSave(romId: romId, slot: slot)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("state-\(UUID().uuidString).dltastate")
        core.saveSaveState(to: tmp)
        let data = try Data(contentsOf: tmp)
        try saveStore.writeState(romId: romId, slot: slot, data: data)
        if let thumb = currentThumbnailPNG() {
            try saveStore.writeThumbnail(romId: romId, slot: slot, data: thumb)
        }
        try? FileManager.default.removeItem(at: tmp)
    }

    func loadState(slot: Int) throws {
        guard let core = emulatorCore else { return }
        guard let data = try saveStore.readState(romId: romId, slot: slot) else { return }
        try captureUndoLoadSnapshot(core: core)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("state-\(UUID().uuidString).dltastate")
        try data.write(to: tmp)
        try core.load(SaveState(fileURL: tmp, gameType: gameType))
        try? FileManager.default.removeItem(at: tmp)
    }

    func undoSave(slot: Int) throws {
        _ = try saveStore.restoreSlotFromUndoSave(romId: romId, slot: slot)
    }

    func undoLoad() throws {
        guard let core = emulatorCore else { return }
        guard let data = try saveStore.readUndoLoadState(romId: romId) else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("state-\(UUID().uuidString).dltastate")
        try data.write(to: tmp)
        try core.load(SaveState(fileURL: tmp, gameType: gameType))
        try? FileManager.default.removeItem(at: tmp)
        try saveStore.clearUndoLoad(romId: romId)
    }

    // MARK: - Helpers

    private func currentThumbnailPNG() -> Data? {
        guard let image = emulatorCore?.videoManager.snapshot() else { return nil }
        return image.pngData()
    }

    private func captureUndoLoadSnapshot(core: EmulatorCore) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("undoload-\(UUID().uuidString).dltastate")
        core.saveSaveState(to: tmp)
        let data = try Data(contentsOf: tmp)
        let thumb = currentThumbnailPNG()
        try saveStore.writeUndoLoadSnapshot(romId: romId, stateData: data, thumbnailData: thumb)
        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - Battery

    private func loadBatteryIfAvailable() {
        guard let data = try? saveStore.readBattery(romId: romId) else { return }
        let savURL = Game(fileURL: gameURL, type: gameType).gameSaveURL
        try? data.write(to: savURL)
    }

    private func flushBattery() {
        emulatorCore?.save()
        let savURL = Game(fileURL: gameURL, type: gameType).gameSaveURL
        if let data = try? Data(contentsOf: savURL) {
            try? saveStore.writeBattery(romId: romId, data: data)
        }
    }
}
