import Foundation

protocol PBIOSSyncUseCase {
    func systemDirectory() -> URL
    func loadStatuses(for core: LibretroCore) async throws -> [BIOSFileStatus]
    func download(status: BIOSFileStatus, into systemDir: URL) async throws
    /// Gibt fehlende, harte Anforderungen zurück (für Launch-Warnung).
    func missingMandatory(for core: LibretroCore) async -> [LibretroBIOSFile]
}

final class BIOSSyncUseCase: PBIOSSyncUseCase {
    private let apiClient: PRommAPIClient
    private let fileManager: FileManager
    private let logger = Logger.viewModel

    init(apiClient: PRommAPIClient = RommAPIClient.shared,
         fileManager: FileManager = .default) {
        self.apiClient = apiClient
        self.fileManager = fileManager
    }

    func systemDirectory() -> URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("LibretroSystem", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func loadStatuses(for core: LibretroCore) async throws -> [BIOSFileStatus] {
        let required = LibretroBIOSRequirement.files(for: core)
        let serverFirmware = try await loadServerFirmware(for: core)
        let dir = systemDirectory()

        return required.map { req in
            let localURL = dir.appendingPathComponent(req.fileName)
            let local: BIOSFileStatus.LocalState
            if fileManager.fileExists(atPath: localURL.path) {
                let md5 = BIOSFileHashing.md5(of: localURL) ?? ""
                let size = BIOSFileHashing.fileSize(of: localURL) ?? 0
                local = .present(md5: md5, sizeBytes: size)
            } else {
                local = .missing
            }

            let server: BIOSFileStatus.ServerState
            if let match = serverFirmware.first(where: {
                $0.fileName.caseInsensitiveCompare(req.fileName) == .orderedSame
            }) {
                server = .available(
                    firmwareId: match.id,
                    sizeBytes: match.fileSizeBytes,
                    md5: match.md5Hash,
                    isVerified: match.isVerified
                )
            } else if serverFirmware.isEmpty {
                server = .unknown
            } else {
                server = .missing
            }

            return BIOSFileStatus(requirement: req, local: local, server: server)
        }
    }

    func download(status: BIOSFileStatus, into systemDir: URL) async throws {
        guard case .available(let id, _, _, _) = status.server else {
            throw NSError(domain: "BIOSSync", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Server hat keine Datei für \(status.requirement.fileName)."
            ])
        }
        let data = try await apiClient.downloadFirmwareContent(id: id, fileName: status.requirement.fileName)
        let target = systemDir.appendingPathComponent(status.requirement.fileName)
        try data.write(to: target, options: .atomic)
        logger.info("BIOS gespeichert: \(target.path) (\(data.count) bytes)")
    }

    func missingMandatory(for core: LibretroCore) async -> [LibretroBIOSFile] {
        // Wenn "at least one of" Regel gilt: prüfe ob mindestens eine vorliegt.
        let dir = systemDirectory()
        if let anyOf = LibretroBIOSRequirement.atLeastOneOfFileNames(for: core) {
            let hasAny = anyOf.contains { name in
                fileManager.fileExists(atPath: dir.appendingPathComponent(name).path)
            }
            if hasAny { return [] }
        }
        let required = LibretroBIOSRequirement.files(for: core).filter { $0.required }
        return required.filter { req in
            !fileManager.fileExists(atPath: dir.appendingPathComponent(req.fileName).path)
        }
    }

    private func loadServerFirmware(for core: LibretroCore) async throws -> [FirmwareSchema] {
        let platforms = try await apiClient.getPlatforms()
        let slugs = Set(LibretroBIOSRequirement.platformSlugs(for: core).map { $0.lowercased() })
        let matches = platforms.filter { slugs.contains($0.slug.lowercased()) }
        if matches.isEmpty { return [] }
        // Prefer embedded firmware (one round-trip); fallback zum dedizierten Endpoint.
        var firmware: [FirmwareSchema] = []
        for platform in matches {
            if let embedded = platform.firmware, !embedded.isEmpty {
                firmware.append(contentsOf: embedded)
            } else {
                let fetched = try await apiClient.getPlatformFirmware(platformId: platform.id)
                firmware.append(contentsOf: fetched)
            }
        }
        return firmware
    }
}
