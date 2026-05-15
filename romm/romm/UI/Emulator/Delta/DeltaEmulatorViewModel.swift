import Foundation
import Observation
import DeltaCore
import GBADeltaCore

@Observable
@MainActor
final class DeltaEmulatorViewModel {
    let rom: Rom
    let gameType: DeltaGameType
    var errorMessage: String?
    var session: DeltaCoreSession?

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
        do {
            guard let downloaded = try localROMRepo.getDownloadedROM(byId: rom.id) else {
                errorMessage = "ROM bitte zuerst herunterladen."
                return
            }
            let base = localROMRepo.romsBaseURL
            let url = try resolver.resolve(rom: downloaded, baseURL: base, gameType: gameType)
            let exists = FileManager.default.fileExists(atPath: url.path)
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
            print("[DeltaEmulatorVM] ROM url=\(url.path) exists=\(exists) size=\(size)")
            if !exists {
                errorMessage = "ROM-Datei nicht gefunden: \(url.lastPathComponent)"
                return
            }
            let deltaType = Self.deltaCoreGameType(for: gameType)
            session = DeltaCoreSession(
                gameURL: url, gameType: deltaType,
                romId: rom.id, saveStore: saveStore
            )
            session?.start()
        } catch {
            errorMessage = "Konnte ROM-Datei nicht öffnen: \(error.localizedDescription)"
            logger.error("DeltaCore launch failed: \(error)")
        }
    }

    func teardown() {
        session?.stop()
        session = nil
    }

    private static func deltaCoreGameType(for type: DeltaGameType) -> GameType {
        switch type {
        case .gba: return GBA.core.gameType
        }
    }
}
