import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class LibretroEmulatorViewModel {
    let rom: Rom
    let core: LibretroCore
    var errorMessage: String?
    var session: LibretroSession?
    var isLoading: Bool = true
    var onMenuRequested: (() -> Void)?

    private let localROMRepo: PLocalROMRepository
    private let resolver: PROMFileResolver
    private let saveStore: PSaveStore
    private let biosSync: PBIOSSyncUseCase
    private let logger = Logger.viewModel

    init(
        rom: Rom,
        core: LibretroCore,
        localROMRepo: PLocalROMRepository,
        resolver: PROMFileResolver = ROMFileResolver(),
        saveStore: PSaveStore = LocalSaveStoreRepository(),
        biosSync: PBIOSSyncUseCase = BIOSSyncUseCase()
    ) {
        self.rom = rom
        self.core = core
        self.localROMRepo = localROMRepo
        self.resolver = resolver
        self.saveStore = saveStore
        self.biosSync = biosSync
    }

    func bootstrap() {
        isLoading = true
        Task { @MainActor in
            let missing = await biosSync.missingMandatory(for: core)
            if !missing.isEmpty {
                let names = missing.map { $0.fileName }.joined(separator: ", ")
                errorMessage = "BIOS fehlt für \(core.displayName): \(names). In Einstellungen → BIOS Files herunterladen."
                isLoading = false
                return
            }
            self.bootstrapAfterBIOSCheck()
        }
    }

    private func bootstrapAfterBIOSCheck() {
        do {
            guard let downloaded = try localROMRepo.getDownloadedROM(byId: rom.id) else {
                errorMessage = "Please download the ROM first."
                isLoading = false
                return
            }
            let base = localROMRepo.romsBaseURL
            let url = try resolver.resolve(
                rom: downloaded,
                baseURL: base,
                allowedExtensions: core.allowedExtensions
            )
            let exists = FileManager.default.fileExists(atPath: url.path)
            print("[LibretroVM] ROM url=\(url.path) exists=\(exists)")
            if !exists {
                errorMessage = "ROM file not found: \(url.lastPathComponent)"
                isLoading = false
                return
            }
            let s = LibretroSession(gameURL: url, core: core, romId: rom.id, saveStore: saveStore)
            s.onMenuRequested = { [weak self] in self?.onMenuRequested?() }
            session = s
            s.start()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoading = false
                }
            }
        } catch {
            errorMessage = "Could not open ROM file: \(error.localizedDescription)"
            logger.error("Libretro launch failed: \(error)")
            isLoading = false
        }
    }

    func teardown() {
        session?.stop()
        session = nil
    }
}
