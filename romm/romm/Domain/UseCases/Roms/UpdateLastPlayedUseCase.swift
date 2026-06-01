import Foundation

protocol PUpdateLastPlayedUseCase {
    func execute(romId: Int) async throws
}

final class UpdateLastPlayedUseCase: PUpdateLastPlayedUseCase {
    private let romsRepository: PRomsRepository

    init(romsRepository: PRomsRepository) {
        self.romsRepository = romsRepository
    }

    func execute(romId: Int) async throws {
        guard romId > 0 else {
            throw RomError.invalidRomId
        }
        try await romsRepository.updateLastPlayed(romId: romId)
    }
}
