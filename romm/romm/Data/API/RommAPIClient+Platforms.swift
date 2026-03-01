//
//  RommAPIClient+Platforms.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import Foundation

// MARK: - Platforms API Wrapper
extension RommAPIClient {
    func getPlatforms() async throws -> [PlatformSchema] {
        return try await get("api/platforms", responseType: [PlatformSchema].self)
    }

    func addPlatform(name: String, slug: String) async throws -> PlatformSchema {
        let body = BodyAddPlatformApiPlatformsPost(fsSlug: slug)
        return try await post("api/platforms", body: body, responseType: PlatformSchema.self)
    }

    func deletePlatform(id: Int) async throws -> String {
        let data = try await delete("api/platforms/\(id)")
        return String(data: data, encoding: .utf8) ?? ""
    }
}