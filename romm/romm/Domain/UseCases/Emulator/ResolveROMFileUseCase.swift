import Foundation

protocol PResolveROMFileUseCase {
    func execute(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL
    func execute(rom: DownloadedROM, baseURL: URL, allowedExtensions: Set<String>) throws -> URL
}

final class ResolveROMFileUseCase: PResolveROMFileUseCase {
    private let resolver: PROMFileResolver

    init(resolver: PROMFileResolver) {
        self.resolver = resolver
    }

    func execute(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL {
        try resolver.resolve(rom: rom, baseURL: baseURL, gameType: gameType)
    }

    func execute(rom: DownloadedROM, baseURL: URL, allowedExtensions: Set<String>) throws -> URL {
        try resolver.resolve(rom: rom, baseURL: baseURL, allowedExtensions: allowedExtensions)
    }
}
