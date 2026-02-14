//
//  HeartbeatError.swift
//  romm
//

import Foundation

enum HeartbeatError: LocalizedError {
    case serverVersionChanged(from: String, to: String)
    case serverVersionTooLow(serverVersion: String, minRequired: String)
    case serverVersionTooHigh(serverVersion: String, maxSupported: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .serverVersionChanged(let from, let to):
            return "Server was updated (from \(from) to \(to)). Please login again."
        case .serverVersionTooLow(let serverVersion, let minRequired):
            return "Server version \(serverVersion) is too old. Minimum required: \(minRequired)"
        case .serverVersionTooHigh(let serverVersion, let maxSupported):
            return "Server version \(serverVersion) is too new. Maximum supported: \(maxSupported). Please update the app."
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
