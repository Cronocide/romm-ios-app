//
//  AuthMethod.swift
//  romm
//
//  Authentication Method Enumeration
//

import Foundation

/// Authentication methods supported by the app
enum AuthMethod: String, Codable, CaseIterable {
    /// Classic username/password authentication (Basic Auth)
    case classic
    
    /// OIDC/OAuth2 authentication (Bearer Token)
    case oidc

    /// Client API Token authentication (prefixed with `rmm_`)
    case clientToken

    /// User-friendly display name
    var displayName: String {
        switch self {
        case .classic:
            return "Username & Password"
        case .oidc:
            return "Browser Login (OIDC)"
        case .clientToken:
            return "API Token"
        }
    }

    /// Short description
    var description: String {
        switch self {
        case .classic:
            return "Traditional login with username and password"
        case .oidc:
            return "Secure browser-based authentication"
        case .clientToken:
            return "Connect with an API token from your server"
        }
    }
    
    /// Icon name for UI
    var iconName: String {
        switch self {
        case .classic:
            return "person.fill"
        case .oidc:
            return "globe"
        case .clientToken:
            return "key.fill"
        }
    }
    
    /// Whether this method requires a browser
    var requiresBrowser: Bool {
        switch self {
        case .classic:
            return false
        case .oidc:
            return true
        case .clientToken:
            return false
        }
    }
    
    /// Whether this method stores credentials locally
    var storesCredentials: Bool {
        switch self {
        case .classic:
            return true // Username stored, password used for Basic Auth
        case .oidc:
            return false // Only tokens stored, no password
        case .clientToken:
            return false // Token stored in Keychain, not as credential
        }
    }
}

// MARK: - Helper Extensions

extension AuthMethod {
    /// Returns a recommendation string based on server capability
    static func recommendation(for capability: HeartbeatRepository.ServerAuthCapability) -> String {
        switch capability {
        case .classicOnly:
            return "This server only supports username/password authentication"
        case .oidcOnly:
            return "This server requires browser-based authentication (OIDC)"
        case .both:
            return "Choose your preferred authentication method"
        case .cloudflareBlocked:
            return "⚠️ Server is protected and requires OIDC configuration"
        case .unreachable:
            return "⚠️ Server is unreachable"
        }
    }
    
    /// Returns available methods based on server capability
    static func availableMethods(for capability: HeartbeatRepository.ServerAuthCapability) -> [AuthMethod] {
        switch capability {
        case .classicOnly:
            return [.classic]
        case .oidcOnly:
            return [.oidc]
        case .both:
            return [.classic, .oidc]
        case .cloudflareBlocked, .unreachable:
            return []
        }
    }
}
