//
//  PStatsRepository.swift
//  romm
//
//  Created by Ilyas Hallak on 16.11.25.
//

import Foundation

protocol PStatsRepository {
    func getStats() async throws -> Stats
}
