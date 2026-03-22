//
//  OIDCError.swift
//  romm
//
//  OIDC-specific Error Types
//

import Foundation

/// Errors related to OIDC authentication
enum OIDCError: LocalizedError {
    // MARK: - Discovery Errors
    
    case discoveryFailed(String)
    case discoveryEndpointNotFound
    case invalidDiscoveryResponse
    
    // MARK: - Configuration Errors
    
    case invalidConfiguration(String)
    case missingConfiguration
    case configurationExpired
    
    // MARK: - Authorization Errors
    
    case authorizationFailed(String)
    case authorizationCancelled
    case invalidAuthorizationResponse
    case stateValidationFailed
    
    // MARK: - Token Errors
    
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case noRefreshToken
    case invalidTokenResponse
    case tokenExpired
    
    // MARK: - Network Errors
    
    case networkError(String)
    case serverError(Int, String)
    
    // MARK: - Client Errors
    
    case invalidRedirectURI
    case invalidClientId
    case missingRequiredParameter(String)
    
    // MARK: - Storage Errors
    
    case storageFailed(String)
    case tokenNotFound
    
    // MARK: - PKCE Errors
    
    case pkceGenerationFailed
    case pkceVerificationFailed
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        // Discovery
        case .discoveryFailed(let reason):
            return "OIDC discovery failed: \(reason)"
        case .discoveryEndpointNotFound:
            return "OIDC discovery endpoint not found. Server may not support OIDC."
        case .invalidDiscoveryResponse:
            return "Invalid response from OIDC discovery endpoint"
            
        // Configuration
        case .invalidConfiguration(let reason):
            return "Invalid OIDC configuration: \(reason)"
        case .missingConfiguration:
            return "OIDC configuration not found. Please complete setup."
        case .configurationExpired:
            return "OIDC configuration has expired. Please reconfigure."
            
        // Authorization
        case .authorizationFailed(let reason):
            return "Authorization failed: \(reason)"
        case .authorizationCancelled:
            return "Authorization was cancelled"
        case .invalidAuthorizationResponse:
            return "Invalid response from authorization server"
        case .stateValidationFailed:
            return "State validation failed. Possible security issue."
            
        // Tokens
        case .tokenExchangeFailed(let reason):
            return "Token exchange failed: \(reason)"
        case .tokenRefreshFailed(let reason):
            return "Token refresh failed: \(reason)"
        case .noRefreshToken:
            return "No refresh token available. Please log in again."
        case .invalidTokenResponse:
            return "Invalid response from token endpoint"
        case .tokenExpired:
            return "Token has expired. Please log in again."
            
        // Network
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
            
        // Client
        case .invalidRedirectURI:
            return "Invalid redirect URI. Please check app configuration."
        case .invalidClientId:
            return "Invalid client ID. Please check server configuration."
        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"
            
        // Storage
        case .storageFailed(let reason):
            return "Failed to store OIDC data: \(reason)"
        case .tokenNotFound:
            return "No stored tokens found. Please log in."
            
        // PKCE
        case .pkceGenerationFailed:
            return "Failed to generate PKCE challenge"
        case .pkceVerificationFailed:
            return "PKCE verification failed"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .discoveryFailed, .discoveryEndpointNotFound:
            return "The server does not provide OIDC discovery information"
        case .authorizationCancelled:
            return "You cancelled the login process"
        case .tokenExpired:
            return "Your session has expired"
        case .noRefreshToken:
            return "Cannot refresh session without a refresh token"
        case .networkError:
            return "Check your internet connection"
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .discoveryFailed, .discoveryEndpointNotFound:
            return "Contact your server administrator to enable OIDC support"
        case .authorizationCancelled:
            return "Tap 'Login with Browser' to try again"
        case .tokenExpired, .noRefreshToken, .tokenRefreshFailed:
            return "Please log in again to continue"
        case .networkError:
            return "Check your internet connection and try again"
        case .invalidConfiguration, .configurationExpired:
            return "Please reconfigure your server connection"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
}

// MARK: - User-Friendly Error Messages

extension OIDCError {
    /// Returns a short, user-friendly error message
    var userMessage: String {
        switch self {
        case .discoveryFailed, .discoveryEndpointNotFound:
            return "Server doesn't support OIDC"
        case .authorizationCancelled:
            return "Login cancelled"
        case .tokenExpired:
            return "Session expired"
        case .networkError:
            return "Connection error"
        case .authorizationFailed, .tokenExchangeFailed:
            return "Login failed"
        case .tokenRefreshFailed:
            return "Session refresh failed"
        default:
            return "Authentication error"
        }
    }
    
    /// Returns a detailed message for error logs
    var detailedMessage: String {
        var message = errorDescription ?? "Unknown OIDC error"
        if let reason = failureReason {
            message += "\nReason: \(reason)"
        }
        if let suggestion = recoverySuggestion {
            message += "\nSuggestion: \(suggestion)"
        }
        return message
    }
}

// MARK: - Error Classification

extension OIDCError {
    /// Whether this error should trigger a re-authentication flow
    var requiresReauth: Bool {
        switch self {
        case .tokenExpired, .noRefreshToken, .tokenRefreshFailed, .tokenNotFound:
            return true
        default:
            return false
        }
    }
    
    /// Whether this error is recoverable by retrying
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError:
            return true
        case .tokenRefreshFailed:
            return false // Should trigger re-auth instead
        default:
            return false
        }
    }
    
    /// Whether this error indicates a configuration problem
    var isConfigurationIssue: Bool {
        switch self {
        case .invalidConfiguration, .missingConfiguration, .configurationExpired,
             .invalidClientId, .invalidRedirectURI:
            return true
        default:
            return false
        }
    }
}
