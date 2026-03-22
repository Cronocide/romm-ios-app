//
//  OIDCConfiguration.swift
//  romm
//
//  OIDC/OAuth2 Configuration Model
//

import Foundation

/// OIDC Configuration for authentication
struct OIDCConfiguration: Codable, Equatable {
    /// The OIDC issuer URL (e.g., https://auth.example.com)
    let issuerURL: String
    
    /// Authorization endpoint URL
    let authorizationEndpoint: String
    
    /// Token endpoint URL
    let tokenEndpoint: String
    
    /// Client ID for this application
    let clientId: String
    
    /// Redirect URI for callback (e.g., romm://callback)
    let redirectURI: String
    
    /// Requested scopes (default: openid, profile, email)
    let scopes: [String]
    
    /// End session endpoint (optional, for logout)
    let endSessionEndpoint: String?
    
    /// Server URL this config belongs to
    let serverURL: String
    
    /// When this configuration was created/updated
    let createdAt: Date
    
    // MARK: - Initialization
    
    init(
        issuerURL: String,
        authorizationEndpoint: String,
        tokenEndpoint: String,
        clientId: String,
        redirectURI: String,
        scopes: [String] = ["openid", "profile", "email"],
        endSessionEndpoint: String? = nil,
        serverURL: String,
        createdAt: Date = Date()
    ) {
        self.issuerURL = issuerURL
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.endSessionEndpoint = endSessionEndpoint
        self.serverURL = serverURL
        self.createdAt = createdAt
    }
    
    // MARK: - Validation
    
    /// Validates the configuration
    func validate() throws {
        guard URL(string: issuerURL) != nil else {
            throw OIDCError.invalidConfiguration("Invalid issuer URL: \(issuerURL)")
        }
        
        guard URL(string: authorizationEndpoint) != nil else {
            throw OIDCError.invalidConfiguration("Invalid authorization endpoint: \(authorizationEndpoint)")
        }
        
        guard URL(string: tokenEndpoint) != nil else {
            throw OIDCError.invalidConfiguration("Invalid token endpoint: \(tokenEndpoint)")
        }
        
        guard URL(string: redirectURI) != nil else {
            throw OIDCError.invalidConfiguration("Invalid redirect URI: \(redirectURI)")
        }
        
        guard !clientId.isEmpty else {
            throw OIDCError.invalidConfiguration("Client ID cannot be empty")
        }
        
        guard !scopes.isEmpty else {
            throw OIDCError.invalidConfiguration("At least one scope is required")
        }
        
        guard scopes.contains("openid") else {
            throw OIDCError.invalidConfiguration("'openid' scope is required for OIDC")
        }
    }
    
    /// Creates a default configuration for a server URL
    /// - Parameter serverURL: The RomM server URL
    /// - Returns: A default OIDC configuration
    static func `default`(for serverURL: String) -> OIDCConfiguration {
        return OIDCConfiguration(
            issuerURL: "\(serverURL)/auth",
            authorizationEndpoint: "\(serverURL)/auth/authorize",
            tokenEndpoint: "\(serverURL)/auth/token",
            clientId: "romm-ios-app",
            redirectURI: "romm://callback",
            scopes: ["openid", "profile", "email"],
            serverURL: serverURL
        )
    }
}

// MARK: - Well-Known Discovery Response

/// Response from .well-known/openid-configuration endpoint
struct OIDCDiscoveryResponse: Codable {
    let issuer: String
    let authorizationEndpoint: String
    let tokenEndpoint: String
    let endSessionEndpoint: String?
    let userinfoEndpoint: String?
    let jwksUri: String?
    let scopesSupported: [String]?
    let responseTypesSupported: [String]?
    let grantTypesSupported: [String]?
    
    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case endSessionEndpoint = "end_session_endpoint"
        case userinfoEndpoint = "userinfo_endpoint"
        case jwksUri = "jwks_uri"
        case scopesSupported = "scopes_supported"
        case responseTypesSupported = "response_types_supported"
        case grantTypesSupported = "grant_types_supported"
    }
    
    /// Converts discovery response to OIDCConfiguration
    func toConfiguration(clientId: String, redirectURI: String, serverURL: String) -> OIDCConfiguration {
        return OIDCConfiguration(
            issuerURL: issuer,
            authorizationEndpoint: authorizationEndpoint,
            tokenEndpoint: tokenEndpoint,
            clientId: clientId,
            redirectURI: redirectURI,
            scopes: scopesSupported ?? ["openid", "profile", "email"],
            endSessionEndpoint: endSessionEndpoint,
            serverURL: serverURL
        )
    }
}

// MARK: - Helper Extensions

extension OIDCConfiguration {
    /// Returns a user-friendly description of the configuration
    var description: String {
        """
        OIDC Configuration:
        - Issuer: \(issuerURL)
        - Client ID: \(clientId)
        - Redirect URI: \(redirectURI)
        - Scopes: \(scopes.joined(separator: ", "))
        """
    }
    
    /// Check if configuration is expired (older than 24 hours)
    var isExpired: Bool {
        let expirationDate = createdAt.addingTimeInterval(24 * 60 * 60) // 24 hours
        return Date() > expirationDate
    }
}
