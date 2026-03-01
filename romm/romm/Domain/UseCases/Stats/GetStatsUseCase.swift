//
//  GetStatsUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 16.11.25.
//

import Foundation

class GetStatsUseCase {
    private let statsRepository: PStatsRepository

    init(statsRepository: PStatsRepository) {
        self.statsRepository = statsRepository
    }

    func execute() async throws -> Stats {
        return try await statsRepository.getStats()
    }
}
