import Foundation

protocol PResolveROMFileUseCase {
    func execute(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL
}

final class ResolveROMFileUseCase: PResolveROMFileUseCase {
    private let resolver: PROMFileResolver

    init(resolver: PROMFileResolver = ROMFileResolver()) {
        self.resolver = resolver
    }

    func execute(rom: DownloadedROM, baseURL: URL, gameType: DeltaGameType) throws -> URL {
        try resolver.resolve(rom: rom, baseURL: baseURL, gameType: gameType)
    }
}
