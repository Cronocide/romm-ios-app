//
//  ClientTokenInfo.swift
//  romm
//

import Foundation

struct ClientTokenInfo: Codable {
    let tokenId: Int
    let name: String
    let scopes: [String]
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }
}
