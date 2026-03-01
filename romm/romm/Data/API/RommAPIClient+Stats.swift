//
//  RommAPIClient+Stats.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import Foundation

// MARK: - Stats, Saves, States API
extension RommAPIClient {
    func getStats() async throws -> StatsReturn {
        return try await get("api/stats", responseType: StatsReturn.self)
    }

    func getSaves(romId: Int) async throws -> [SaveSchema] {
        return try await get("api/saves?rom_id=\(romId)", responseType: [SaveSchema].self)
    }

    func getStates(romId: Int) async throws -> [StateSchema] {
        return try await get("api/states?rom_id=\(romId)", responseType: [StateSchema].self)
    }
}