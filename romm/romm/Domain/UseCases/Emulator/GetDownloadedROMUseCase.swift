import Foundation

struct ResolvedDownloadedROM {
    let rom: DownloadedROM
    let baseURL: URL
}

enum GetDownloadedROMError: Error, LocalizedError {
    case notDownloaded

    var errorDescription: String? {
        switch self {
        case .notDownloaded: return "Please download the ROM first."
        }
    }
}

protocol PGetDownloadedROMUseCase {
    func execute(romId: Int) throws -> ResolvedDownloadedROM
}

final class GetDownloadedROMUseCase: PGetDownloadedROMUseCase {
    private let localROMRepository: PLocalROMRepository

    init(localROMRepository: PLocalROMRepository) {
        self.localROMRepository = localROMRepository
    }

    func execute(romId: Int) throws -> ResolvedDownloadedROM {
        guard let downloaded = try localROMRepository.getDownloadedROM(byId: romId) else {
            throw GetDownloadedROMError.notDownloaded
        }
        return ResolvedDownloadedROM(rom: downloaded, baseURL: localROMRepository.romsBaseURL)
    }
}
