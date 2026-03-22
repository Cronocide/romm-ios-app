//
//  OIDCTokens.swift
//  romm
//
//  OIDC Token Storage Model
//

import Foundation

/// OIDC Tokens (Access, Refresh, ID tokens)
struct OIDCTokens: Codable, Equatable {
    /// Access token for API requests
    let accessToken: String
    
    /// Refresh token for obtaining new access tokens
    let refreshToken: String?
    
    /// ID token containing user identity information
    let idToken: String?
    
    /// Token type (usually "Bearer")
    let tokenType: String
    
    /// When the access token expires
    let expiresAt: Date
    
    /// Scopes granted with this token
    let scopes: [String]?
    
    /// When these tokens were obtained
    let issuedAt: Date
    
    // MARK: - Initialization
    
    init(
        accessToken: String,
        refreshToken: String? = nil,
        idToken: String? = nil,
        tokenType: String = "Bearer",
        expiresIn: TimeInterval? = nil,
        expiresAt: Date? = nil,
        scopes: [String]? = nil,
        issuedAt: Date = Date()
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.tokenType = tokenType
        self.scopes = scopes
        self.issuedAt = issuedAt
        
        // Calculate expiration
        if let expiresAt = expiresAt {
            self.expiresAt = expiresAt
        } else if let expiresIn = expiresIn {
            self.expiresAt = issuedAt.addingTimeInterval(expiresIn)
        } else {
            // Default to 1 hour if not specified
            self.expiresAt = issuedAt.addingTimeInterval(3600)
        }
    }
    
    // MARK: - Token Status
    
    /// Check if the access token is expired
    var isExpired: Bool {
        return Date() >= expiresAt
    }
    
    /// Check if the access token will expire soon (within 5 minutes)
    var willExpireSoon: Bool {
        let fiveMinutesFromNow = Date().addingTimeInterval(5 * 60)
        return fiveMinutesFromNow >= expiresAt
    }
    
    /// Time remaining until expiration
    var timeUntilExpiration: TimeInterval {
        return expiresAt.timeIntervalSince(Date())
    }
    
    /// Check if refresh is possible (has refresh token and not expired)
    var canRefresh: Bool {
        return refreshToken != nil && !isExpired
    }
    
    /// Check if tokens are valid and usable
    var isValid: Bool {
        return !accessToken.isEmpty && !isExpired
    }
    
    // MARK: - Authorization Header
    
    /// Returns the Authorization header value (e.g., "Bearer abc123")
    var authorizationHeader: String {
        return "\(tokenType) \(accessToken)"
    }
    
    // MARK: - User Info from ID Token
    
    /// Extracts user information from ID token (JWT)
    /// Note: This is a simple base64 decode, not cryptographically verified
    func extractUserInfo() -> [String: Any]? {
        guard let idToken = idToken else { return nil }
        
        // Split JWT into parts (header.payload.signature)
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        // Decode payload (second part)
        let payloadString = String(parts[1])
        
        // Add padding if needed for base64
        var payload = payloadString.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = 4 - payload.count % 4
        if paddingLength < 4 {
            payload += String(repeating: "=", count: paddingLength)
        }
        
        // Decode base64
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return json
    }
    
    /// Extract username/email from ID token
    var username: String? {
        guard let userInfo = extractUserInfo() else { return nil }
        return userInfo["preferred_username"] as? String ?? 
               userInfo["email"] as? String ?? 
               userInfo["sub"] as? String
    }
    
    /// Extract email from ID token
    var email: String? {
        guard let userInfo = extractUserInfo() else { return nil }
        return userInfo["email"] as? String
    }
}

// MARK: - Token Response from Server

/// Response from token endpoint
struct OIDCTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let tokenType: String
    let expiresIn: Int?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
    
    /// Converts token response to OIDCTokens
    func toTokens() -> OIDCTokens {
        let scopes = scope?.split(separator: " ").map(String.init)
        return OIDCTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            tokenType: tokenType,
            expiresIn: expiresIn.map(TimeInterval.init),
            scopes: scopes
        )
    }
}

// MARK: - Helper Extensions

extension OIDCTokens {
    /// Returns a user-friendly description (without exposing full tokens)
    var description: String {
        let accessPreview = String(accessToken.prefix(10))
        let hasRefresh = refreshToken != nil ? "Yes" : "No"
        let hasId = idToken != nil ? "Yes" : "No"
        let status = isExpired ? "Expired" : "Valid"
        
        return """
        OIDC Tokens:
        - Access Token: \(accessPreview)...
        - Refresh Token: \(hasRefresh)
        - ID Token: \(hasId)
        - Type: \(tokenType)
        - Status: \(status)
        - Expires: \(expiresAt)
        """
    }
    
    /// Returns formatted time until expiration
    var expirationDescription: String {
        if isExpired {
            return "Expired"
        }
        
        let interval = timeUntilExpiration
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "Expires in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "Expires in \(minutes)m"
        } else {
            return "Expires soon"
        }
    }
}
