//
//  PCollectionsRepository.swift
//  romm
//
//  Created by Ilyas Hallak on 10.08.25.
//

import Foundation

protocol PCollectionsRepository {
    func getCollections(limit: Int?, offset: Int?) async throws -> [Collection]
    func getVirtualCollections(type: String, limit: Int?) async throws -> [VirtualCollection]
    func getCollection(id: Int) async throws -> Collection
    func getVirtualCollection(id: String) async throws -> VirtualCollection
    func createCollection(data: CreateCollectionData) async throws -> Collection
    func updateCollection(id: Int, name: String, description: String, isPublic: Bool, romIds: [Int]) async throws -> Collection
    func deleteCollection(id: Int) async throws
}

// Convenience extension for backward compatibility
extension PCollectionsRepository {
    func getCollections() async throws -> [Collection] {
        return try await getCollections(limit: nil, offset: nil)
    }
}