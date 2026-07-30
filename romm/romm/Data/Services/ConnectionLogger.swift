//
//  ConnectionLogger.swift
//  romm
//
//  Created by Claude on 31.01.26.
//

import Foundation
import SwiftUI

/// Log entry type for connection attempts
enum ConnectionLogType {
    case info
    case success
    case warning
    case error

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    var label: String {
        switch self {
        case .info: return "info"
        case .success: return "ok"
        case .warning: return "warn"
        case .error: return "error"
        }
    }
}

/// A single log entry for connection debugging
struct ConnectionLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: ConnectionLogType
    let details: String?

    init(message: String, type: ConnectionLogType, details: String? = nil) {
        self.timestamp = Date()
        self.message = message
        self.type = type
        self.details = details
    }
}

/// Observable logger for tracking connection attempts
/// Used to provide real-time feedback during login/setup
@MainActor
class ConnectionLogger: ObservableObject {
    static let shared = ConnectionLogger()

    @Published private(set) var logs: [ConnectionLogEntry] = []
    @Published private(set) var isConnecting: Bool = false

    private init() {}

    /// Clear all logs and prepare for a new connection attempt
    func startNewConnection() {
        logs.removeAll()
        isConnecting = true
        log("Starting connection...", type: .info)
    }

    /// Mark connection attempt as finished
    func finishConnection(success: Bool) {
        isConnecting = false
        if success {
            log("Connection successful", type: .success)
        }
    }

    /// Add a log entry
    func log(_ message: String, type: ConnectionLogType, details: String? = nil) {
        let entry = ConnectionLogEntry(message: message, type: type, details: details)
        logs.append(entry)
    }

    /// Clear all logs
    func clear() {
        logs.removeAll()
    }

    // MARK: - Convenience methods for common connection steps

    func logURLValidation(_ url: String) {
        log("Validating URL: \(url)", type: .info)
    }

    func logURLValidationSuccess() {
        log("URL format is valid", type: .success)
    }

    func logURLValidationError(_ error: String) {
        log("Invalid URL: \(error)", type: .error)
    }

    func logHostResolution(_ host: String) {
        log("Resolving host: \(host)", type: .info)
    }

    func logIPTypeDetected(_ ipType: String) {
        log("Network type: \(ipType)", type: .info)
    }

    func logConnecting() {
        log("Connecting to server...", type: .info)
    }

    func logTLSHandshake() {
        log("TLS handshake in progress...", type: .info)
    }

    func logSelfSignedCertAccepted() {
        log("Self-signed certificate accepted (private network)", type: .warning)
    }

    func logAuthenticating() {
        log("Authenticating...", type: .info)
    }

    func logAuthSuccess() {
        log("Authentication successful", type: .success)
    }

    func logAuthFailed(_ reason: String) {
        log("Authentication failed: \(reason)", type: .error)
    }

    func logNetworkError(_ error: Error) {
        let nsError = error as NSError
        var message = "Network error"
        var details: String? = nil

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                message = "Connection timed out"
                details = "The server did not respond in time. Check if the server is reachable."
            case NSURLErrorCannotFindHost:
                message = "Cannot find host"
                details = "DNS resolution failed. Check the server URL."
            case NSURLErrorCannotConnectToHost:
                message = "Cannot connect to host"
                details = "The server refused the connection. Check if the port is correct."
            case NSURLErrorNetworkConnectionLost:
                message = "Connection lost"
                details = "The network connection was interrupted."
            case NSURLErrorSecureConnectionFailed:
                message = "SSL/TLS error"
                details = "Secure connection failed. The server may have an invalid certificate."
            case NSURLErrorServerCertificateUntrusted:
                message = "Certificate not trusted"
                details = "The server's SSL certificate is not trusted."
            case NSURLErrorNotConnectedToInternet:
                message = "No internet connection"
                details = "Please check your network settings."
            default:
                message = "Network error (\(nsError.code))"
                details = nsError.localizedDescription
            }
        } else {
            details = error.localizedDescription
        }

        log(message, type: .error, details: details)
    }

    func logRetryAttempt(_ attempt: Int, maxAttempts: Int) {
        log("Retry attempt \(attempt)/\(maxAttempts)...", type: .warning)
    }
}
