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
        let romDir = baseURL.appendingPathComponent(rom.localDirectory, isDirectory: true)
        for file in rom.files {
            let ext = (file.fileName as NSString).pathExtension.lowercased()
            if allowed.contains(ext) {
                return romDir.appendingPathComponent(file.fileName)
            }
        }
        throw ROMFileResolverError.noMatchingFile(gameType: gameType)
    }
}
