import Foundation
import Observation
import SwiftUI
import DeltaCore
import GBADeltaCore
import SNESDeltaCore
import GPGXDeltaCore
import NESDeltaCore
import GBCDeltaCore
import N64DeltaCore
import MelonDSDeltaCore

@Observable
@MainActor
final class DeltaEmulatorViewModel {
    let rom: Rom
    let gameType: DeltaGameType
    var errorMessage: String?
    var session: DeltaCoreSession?
    var isLoading: Bool = true

    private let localROMRepo: PLocalROMRepository
    private let resolver: PROMFileResolver
    private let saveStore: PSaveStore
    private let logger = Logger.viewModel

    init(
        rom: Rom,
        gameType: DeltaGameType,
        localROMRepo: PLocalROMRepository,
        resolver: PROMFileResolver = ROMFileResolver(),
        saveStore: PSaveStore = LocalSaveStore()
    ) {
        self.rom = rom
        self.gameType = gameType
        self.localROMRepo = localROMRepo
        self.resolver = resolver
        self.saveStore = saveStore
    }

    func bootstrap() {
        isLoading = true
        do {
            guard let downloaded = try localROMRepo.getDownloadedROM(byId: rom.id) else {
                errorMessage = "Please download the ROM first."
                isLoading = false
                return
            }
            let base = localROMRepo.romsBaseURL
            let url = try resolver.resolve(rom: downloaded, baseURL: base, gameType: gameType)
            let exists = FileManager.default.fileExists(atPath: url.path)
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
            print("[DeltaEmulatorVM] ROM url=\(url.path) exists=\(exists) size=\(size)")
            if !exists {
                errorMessage = "ROM file not found: \(url.lastPathComponent)"
                isLoading = false
                return
            }
            let deltaType = Self.deltaCoreGameType(for: gameType)
            session = DeltaCoreSession(
                gameURL: url, gameType: deltaType,
                romId: rom.id, saveStore: saveStore
            )
            session?.start()
            // Give the emulator a moment to render the first frame before hiding the loader.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoading = false
                }
            }
        } catch {
            errorMessage = "Could not open ROM file: \(error.localizedDescription)"
            logger.error("DeltaCore launch failed: \(error)")
            isLoading = false
        }
    }

    func teardown() {
        session?.stop()
        session = nil
    }

    private static func deltaCoreGameType(for type: DeltaGameType) -> GameType {
        switch type {
        case .gba: return GBA.core.gameType
        case .snes: return SNES.core.gameType
        case .genesis: return GPGX.core.gameType
        case .nes: return NES.core.gameType
        case .gbc: return GBC.core.gameType
        case .n64: return N64.core.gameType
        case .ds: return MelonDS.core.gameType
        }
    }
}
