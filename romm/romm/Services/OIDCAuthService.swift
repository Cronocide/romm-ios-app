//
//  OIDCAuthService.swift
//  romm
//
//  OIDC Authentication Service using AppAuth
//

import Foundation
import AuthenticationServices

/// OIDC Authentication Service
/// Handles discovery, authorization, token exchange, and token refresh
@MainActor
class OIDCAuthService {
    
    // MARK: - Properties
    
    private let logger = Logger.oidc
    private let urlSession: URLSession
    
    // MARK: - Configuration
    
    /// Default client ID for RomM iOS app
    static let defaultClientId = "romm-ios-app"
    
    /// Default redirect URI (must match Info.plist URL scheme)
    static let defaultRedirectURI = "romm://callback"
    
    /// Default scopes
    static let defaultScopes = ["openid", "profile", "email"]
    
    // MARK: - Initialization
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    // MARK: - Discovery
    
    /// Discovers OIDC configuration from server's well-known endpoint
    /// - Parameter serverURL: The RomM server URL
    /// - Returns: OIDC configuration
    func discoverConfiguration(serverURL: String) async throws -> OIDCConfiguration {
        logger.info("🔍 Starting OIDC discovery for: \(serverURL)")
        
        let cleanURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let wellKnownURL = "\(cleanURL)/.well-known/openid-configuration"
        
        guard let url = URL(string: wellKnownURL) else {
            logger.error("❌ Invalid well-known URL: \(wellKnownURL)")
            throw OIDCError.invalidConfiguration("Invalid server URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        logger.debug("📡 Requesting: \(wellKnownURL)")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OIDCError.discoveryFailed("Invalid response type")
            }
            
            logger.debug("📊 Discovery response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("❌ Discovery failed with status \(httpResponse.statusCode): \(message)")
                
                if httpResponse.statusCode == 404 {
                    throw OIDCError.discoveryEndpointNotFound
                }
                
                throw OIDCError.discoveryFailed("HTTP \(httpResponse.statusCode)")
            }
            
            // Parse discovery response
            let decoder = JSONDecoder()
            let discoveryResponse = try decoder.decode(OIDCDiscoveryResponse.self, from: data)
            
            logger.info("✅ Discovery successful")
            logger.debug("Issuer: \(discoveryResponse.issuer)")
            logger.debug("Auth endpoint: \(discoveryResponse.authorizationEndpoint)")
            logger.debug("Token endpoint: \(discoveryResponse.tokenEndpoint)")
            
            // Convert to OIDCConfiguration
            let config = discoveryResponse.toConfiguration(
                clientId: Self.defaultClientId,
                redirectURI: Self.defaultRedirectURI,
                serverURL: cleanURL
            )
            
            // Validate configuration
            try config.validate()
            
            logger.info("✅ OIDC configuration validated successfully")
            
            return config
            
        } catch let decodingError as DecodingError {
            logger.error("❌ Failed to decode discovery response: \(decodingError)")
            throw OIDCError.invalidDiscoveryResponse
        } catch let error as OIDCError {
            throw error
        } catch {
            logger.error("❌ Discovery network error: \(error)")
            throw OIDCError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Authorization Flow
    
    /// Starts the OIDC authorization flow
    /// - Parameters:
    ///   - configuration: OIDC configuration
    ///   - presentationContext: Window for presenting the auth session
    /// - Returns: Authorization code and state
    func authorize(
        configuration: OIDCConfiguration,
        presentationContext: ASPresentationAnchor
    ) async throws -> (code: String, state: String) {
        logger.info("🚀 Starting authorization flow")
        
        // Generate state for CSRF protection
        let state = generateRandomString(length: 32)
        
        // Generate PKCE challenge
        let codeVerifier = generateRandomString(length: 64)
        let codeChallenge = try generateCodeChallenge(from: codeVerifier)
        
        // Store code verifier for later use in token exchange
        UserDefaults.standard.set(codeVerifier, forKey: "oidc_code_verifier")
        
        // Build authorization URL
        var components = URLComponents(string: configuration.authorizationEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let authURL = components?.url else {
            logger.error("❌ Failed to build authorization URL")
            throw OIDCError.invalidConfiguration("Cannot build authorization URL")
        }
        
        logger.debug("🔗 Authorization URL: \(authURL.absoluteString)")
        
        // Present authorization in browser
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "romm"
            ) { callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    
                    // User cancelled
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        self.logger.warning("⚠️ User cancelled authorization")
                        continuation.resume(throwing: OIDCError.authorizationCancelled)
                        return
                    }
                    
                    self.logger.error("❌ Authorization error: \(error)")
                    continuation.resume(throwing: OIDCError.authorizationFailed(error.localizedDescription))
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    self.logger.error("❌ No callback URL received")
                    continuation.resume(throwing: OIDCError.invalidAuthorizationResponse)
                    return
                }
                
                self.logger.debug("✅ Received callback: \(callbackURL.absoluteString)")
                
                // Parse callback URL
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let queryItems = components.queryItems else {
                    self.logger.error("❌ Cannot parse callback URL")
                    continuation.resume(throwing: OIDCError.invalidAuthorizationResponse)
                    return
                }
                
                // Extract code and state
                guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    // Check for error response
                    if let errorCode = queryItems.first(where: { $0.name == "error" })?.value {
                        let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value
                        self.logger.error("❌ Authorization error: \(errorCode) - \(errorDescription ?? "no description")")
                        continuation.resume(throwing: OIDCError.authorizationFailed(errorDescription ?? errorCode))
                        return
                    }
                    
                    self.logger.error("❌ No authorization code in callback")
                    continuation.resume(throwing: OIDCError.invalidAuthorizationResponse)
                    return
                }
                
                guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value else {
                    self.logger.error("❌ No state in callback")
                    continuation.resume(throwing: OIDCError.invalidAuthorizationResponse)
                    return
                }
                
                // Verify state
                guard returnedState == state else {
                    self.logger.error("❌ State mismatch - possible CSRF attack")
                    continuation.resume(throwing: OIDCError.stateValidationFailed)
                    return
                }
                
                self.logger.info("✅ Authorization successful - code received")
                continuation.resume(returning: (code: code, state: state))
            }
            
            session.presentationContextProvider = PresentationContextProvider(window: presentationContext)
            session.prefersEphemeralWebBrowserSession = false // Allow SSO
            
            if !session.start() {
                self.logger.error("❌ Failed to start authentication session")
                continuation.resume(throwing: OIDCError.authorizationFailed("Cannot start authentication session"))
            }
        }
    }
    
    // MARK: - Token Exchange
    
    /// Exchanges authorization code for tokens
    /// - Parameters:
    ///   - code: Authorization code from authorize()
    ///   - configuration: OIDC configuration
    /// - Returns: OIDC tokens
    func exchangeCodeForTokens(
        code: String,
        configuration: OIDCConfiguration
    ) async throws -> OIDCTokens {
        logger.info("🔄 Exchanging authorization code for tokens")
        
        // Get code verifier from storage
        guard let codeVerifier = UserDefaults.standard.string(forKey: "oidc_code_verifier") else {
            logger.error("❌ Code verifier not found")
            throw OIDCError.pkceVerificationFailed
        }
        
        // Build token request
        guard let url = URL(string: configuration.tokenEndpoint) else {
            throw OIDCError.invalidConfiguration("Invalid token endpoint")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Build form data
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        
        request.httpBody = components.query?.data(using: .utf8)
        
        logger.debug("📡 Token exchange request to: \(url.absoluteString)")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OIDCError.tokenExchangeFailed("Invalid response type")
            }
            
            logger.debug("📊 Token response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("❌ Token exchange failed: \(message)")
                throw OIDCError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(message)")
            }
            
            // Parse token response
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(OIDCTokenResponse.self, from: data)
            
            // Clean up code verifier
            UserDefaults.standard.removeObject(forKey: "oidc_code_verifier")
            
            logger.info("✅ Token exchange successful")
            logger.debug("Token type: \(tokenResponse.tokenType)")
            logger.debug("Has refresh token: \(tokenResponse.refreshToken != nil)")
            logger.debug("Expires in: \(tokenResponse.expiresIn ?? 0) seconds")
            
            return tokenResponse.toTokens()
            
        } catch let decodingError as DecodingError {
            logger.error("❌ Failed to decode token response: \(decodingError)")
            throw OIDCError.invalidTokenResponse
        } catch let error as OIDCError {
            throw error
        } catch {
            logger.error("❌ Token exchange network error: \(error)")
            throw OIDCError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Token Refresh
    
    /// Refreshes access token using refresh token
    /// - Parameters:
    ///   - refreshToken: The refresh token
    ///   - configuration: OIDC configuration
    /// - Returns: New OIDC tokens
    func refreshTokens(
        refreshToken: String,
        configuration: OIDCConfiguration
    ) async throws -> OIDCTokens {
        logger.info("🔄 Refreshing access token")
        
        guard let url = URL(string: configuration.tokenEndpoint) else {
            throw OIDCError.invalidConfiguration("Invalid token endpoint")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Build form data
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: configuration.clientId)
        ]
        
        request.httpBody = components.query?.data(using: .utf8)
        
        logger.debug("📡 Token refresh request to: \(url.absoluteString)")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OIDCError.tokenRefreshFailed("Invalid response type")
            }
            
            logger.debug("📊 Refresh response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("❌ Token refresh failed: \(message)")
                
                if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                    // Invalid refresh token - need to re-authenticate
                    throw OIDCError.tokenRefreshFailed("Refresh token invalid or expired")
                }
                
                throw OIDCError.tokenRefreshFailed("HTTP \(httpResponse.statusCode): \(message)")
            }
            
            // Parse token response
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(OIDCTokenResponse.self, from: data)
            
            logger.info("✅ Token refresh successful")
            logger.debug("New token expires in: \(tokenResponse.expiresIn ?? 0) seconds")
            
            return tokenResponse.toTokens()
            
        } catch let decodingError as DecodingError {
            logger.error("❌ Failed to decode refresh response: \(decodingError)")
            throw OIDCError.invalidTokenResponse
        } catch let error as OIDCError {
            throw error
        } catch {
            logger.error("❌ Token refresh network error: \(error)")
            throw OIDCError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generates a cryptographically secure random string
    private func generateRandomString(length: Int) -> String {
        let charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var result = ""
        var randomBytes = [UInt8](repeating: 0, count: length)
        
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        guard status == errSecSuccess else {
            // Fallback to UUID if SecRandom fails
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        
        for byte in randomBytes {
            let index = Int(byte) % charset.count
            result.append(charset[charset.index(charset.startIndex, offsetBy: index)])
        }
        
        return result
    }
    
    /// Generates PKCE code challenge from verifier
    private func generateCodeChallenge(from verifier: String) throws -> String {
        guard let data = verifier.data(using: .utf8) else {
            throw OIDCError.pkceGenerationFailed
        }
        
        // SHA256 hash
        let hash = SHA256.hash(data: data)
        
        // Base64 URL-encode
        let base64 = Data(hash).base64EncodedString()
        let urlSafe = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return urlSafe
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

/// Provides presentation context for ASWebAuthenticationSession
private class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private weak var window: ASPresentationAnchor?
    
    init(window: ASPresentationAnchor) {
        self.window = window
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return window ?? ASPresentationAnchor()
    }
}

// MARK: - SHA256 Helper

import CryptoKit

extension SHA256 {
    static func hash(data: Data) -> SHA256Digest {
        return SHA256.hash(data: data)
    }
}
