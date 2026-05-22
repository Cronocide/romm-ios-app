import Foundation
import ZIPFoundation

enum DeltaGameType: String {
    case gba
    case snes
    case genesis
    case nes
    case gbc
    case n64
    case ds
}

enum ROMFileResolverError: Error, Equatable {
    case noMatchingFile(gameType: DeltaGameType)
    case noMatchingExtension
}

protocol PROMFileResolver {
    func resolve(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL
    func resolve(rom: DownloadedROM, baseURL: URL, allowedExtensions: Set<String>) throws -> URL
}

final class ROMFileResolver: PROMFileResolver {

    private let extensions: [DeltaGameType: Set<String>] = [
        .gba: ["gba"],
        .snes: ["smc", "sfc", "fig", "swc", "snes", "mgd"],
        .genesis: ["md", "gen", "smd", "bin", "sg", "sms"],
        .nes: ["nes", "fds", "unf", "unif"],
        .gbc: ["gbc", "gb", "cgb", "sgb"],
        .n64: ["n64", "z64", "v64", "rom"],
        .ds: ["nds", "dsi", "ids", "srl"]
    ]

    func resolve(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL {
        let allowed = extensions[gameType] ?? []
        do {
            return try resolveInternal(rom: rom, baseURL: baseURL, allowed: allowed)
        } catch ROMFileResolverError.noMatchingExtension {
            throw ROMFileResolverError.noMatchingFile(gameType: gameType)
        }
    }

    func resolve(rom: DownloadedROM, baseURL: URL, allowedExtensions: Set<String>) throws -> URL {
        return try resolveInternal(rom: rom, baseURL: baseURL, allowed: allowedExtensions)
    }

    private func resolveInternal(rom: DownloadedROM, baseURL: URL, allowed: Set<String>) throws -> URL {
        let available = rom.files.map { $0.fileName }
        print("[ROMFileResolver] allowed=\(allowed) files=\(available)")

        if let direct = rom.files.first(where: { allowed.contains(($0.fileName as NSString).pathExtension.lowercased()) }) {
            return try locate(file: direct.fileName, rom: rom, baseURL: baseURL)
        }

        if let zipFile = rom.files.first(where: { ($0.fileName as NSString).pathExtension.lowercased() == "zip" }) {
            let zipURL = try locate(file: zipFile.fileName, rom: rom, baseURL: baseURL)
            return try extractROM(from: zipURL, allowed: allowed)
        }

        throw ROMFileResolverError.noMatchingExtension
    }

    private func locate(file fileName: String, rom: DownloadedROM, baseURL: URL) throws -> URL {
        let fm = FileManager.default
        let primary = baseURL
            .appendingPathComponent(rom.localDirectory, isDirectory: true)
            .appendingPathComponent(fileName)
        if fm.fileExists(atPath: primary.path) {
            return primary
        }
        if let platformDirs = try? fm.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for platformDir in platformDirs {
                let candidate = platformDir
                    .appendingPathComponent(rom.name, isDirectory: true)
                    .appendingPathComponent(fileName)
                if fm.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        return primary
    }

    private func extractROM(from zipURL: URL, allowed: Set<String>) throws -> URL {
        let fm = FileManager.default
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UnzippedROMs", isDirectory: true)
            .appendingPathComponent(zipURL.deletingPathExtension().lastPathComponent, isDirectory: true)

        if fm.fileExists(atPath: cacheDir.path),
           let existing = firstROM(in: cacheDir, allowed: allowed) {
            print("[ROMFileResolver] cached unzip hit: \(existing.path)")
            return existing
        }

        try? fm.removeItem(at: cacheDir)
        try fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let archive = try Archive(url: zipURL, accessMode: .read)
        for entry in archive where allowed.contains((entry.path as NSString).pathExtension.lowercased()) {
            let dest = cacheDir.appendingPathComponent((entry.path as NSString).lastPathComponent)
            _ = try archive.extract(entry, to: dest)
            print("[ROMFileResolver] extracted \(entry.path) -> \(dest.path)")
            return dest
        }

        throw ROMFileResolverError.noMatchingExtension
    }

    private func firstROM(in dir: URL, allowed: Set<String>) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return nil }
        return contents.first { allowed.contains($0.pathExtension.lowercased()) }
    }

}
