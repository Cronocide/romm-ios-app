import Foundation

enum DeltaGameType: String {
    case gba
    // Phase >1: case nes, snes, gbc, n64, ds, genesis
}

enum ROMFileResolverError: Error, Equatable {
    case noMatchingFile(gameType: DeltaGameType)
}

protocol PROMFileResolver {
    func resolve(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL
}

final class ROMFileResolver: PROMFileResolver {

    private let extensions: [DeltaGameType: Set<String>] = [
        .gba: ["gba"]
    ]

    func resolve(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL {
        let allowed = extensions[gameType] ?? []
        let fm = FileManager.default

        let candidateFile = rom.files.first { file in
            allowed.contains((file.fileName as NSString).pathExtension.lowercased())
        }
        guard let file = candidateFile else {
            throw ROMFileResolverError.noMatchingFile(gameType: gameType)
        }

        let primary = baseURL
            .appendingPathComponent(rom.localDirectory, isDirectory: true)
            .appendingPathComponent(file.fileName)
        if fm.fileExists(atPath: primary.path) {
            return primary
        }

        // Fallback: scan platform dirs under baseURL for <romName>/<fileName>
        if let platformDirs = try? fm.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for platformDir in platformDirs {
                let candidate = platformDir
                    .appendingPathComponent(rom.name, isDirectory: true)
                    .appendingPathComponent(file.fileName)
                if fm.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return primary
    }
}
