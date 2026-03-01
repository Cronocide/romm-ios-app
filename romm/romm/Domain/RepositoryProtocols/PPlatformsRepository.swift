//
//  PPlatformsRepository.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import Foundation

protocol PPlatformsRepository {
    func getPlatforms() async throws -> [Platform]
    func addPlatform(name: String, slug: String) async throws -> Platform
    func deletePlatform(id: Int) async throws
}