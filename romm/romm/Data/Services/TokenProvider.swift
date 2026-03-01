//
//  TokenProvider.swift
//  romm
//
//  Created by Ilyas Hallak on 07.08.25.
//

import Foundation

// MARK: - Token Provider Protocol
protocol PTokenProvider {
    func getAuthToken() -> String?
    func getServerURL() -> String?
    func getUsername() -> String?
    func getPassword() -> String?
    func isConfigured() -> Bool
}

// MARK: - Token Provider Implementation
class TokenProvider: PTokenProvider {
    
    private let setupRepository: PSetupRepository
    private let configurationService: ConfigurationService
    private let logger = Logger.auth
    
    init(setupRepository: PSetupRepository = SetupRepository(),
         configurationService: ConfigurationService = DefaultConfigurationService.shared) {
        self.setupRepository = setupRepository
        self.configurationService = configurationService
    }
    
    func getAuthToken() -> String? {
        logger.debug("Getting auth token...")
        
        // Try to get token from setup repository first (preferred)
        if let setupConfig = setupRepository.getSetupConfiguration() {
            logger.info("Setup config found - Server: \(setupConfig.serverURL)")
            logger.debug("Setup config found - Username: \(setupConfig.username)")
            logger.debug("Setup config found - Setup Date: \(setupConfig.setupDate)")
            logger.debug("Setup config has refresh token: \(setupConfig.refreshToken != nil)")
            
            if let token = setupConfig.token, !token.isEmpty {
                logger.info("Token found in setup repository (length: \(token.count))")
                logger.debug("Token preview: \(String(token.prefix(20)))...")
                return token
            } else {
                logger.warning("Setup config exists but token is nil/empty")
            }
        } else {
            logger.debug("No setup configuration found")
        }
        
        // Fallback to configuration service
        if let config = configurationService.getConfiguration() {
            logger.info("Fallback config found - Server: \(config.serverURL)")
            
            if let token = config.token, !token.isEmpty {
                logger.info("Token found in configuration service (length: \(token.count))")
                logger.debug("Token preview: \(String(token.prefix(20)))...")
                return token
            } else {
                logger.warning("Fallback config exists but token is nil/empty")
            }
        } else {
            logger.debug("No fallback configuration found")
        }
        
        logger.error("No auth token found anywhere")
        return nil
    }
    
    func getServerURL() -> String? {
        logger.debug("Getting server URL...")
        
        // Try to get from setup repository first (preferred)
        if let setupConfig = setupRepository.getSetupConfiguration() {
            logger.info("Server URL found in setup repository: \(setupConfig.serverURL)")
            return setupConfig.serverURL
        }
        
        // Fallback to configuration service
        if let config = configurationService.getConfiguration() {
            logger.info("Server URL found in configuration service: \(config.serverURL)")
            return config.serverURL
        }
        
        logger.warning("No server URL found")
        return nil
    }
    
    func getUsername() -> String? {
        logger.debug("Getting username...")
        
        // Try to get from setup repository first (preferred)
        if let setupConfig = setupRepository.getSetupConfiguration() {
            logger.info("Username found in setup repository: \(setupConfig.username)")
            return setupConfig.username
        }
        
        // Fallback to configuration service
        if let config = configurationService.getConfiguration() {
            let username = config.username
            logger.info("Username found in configuration service: \(username)")
            return username
        }
        
        logger.warning("No username found")
        return nil
    }
    
    func getPassword() -> String? {
        logger.debug("Getting password...")
        
        // Try to get from setup repository first (preferred)
        if let setupConfig = setupRepository.getSetupConfiguration() {
            if let password = setupConfig.password {
                logger.info("Password found in setup repository")
                return password
            }
        }
        
        // Fallback to configuration service
        if let config = configurationService.getConfiguration() {
            if let password = config.password {
                logger.info("Password found in configuration service")
                return password
            }
        }
        
        logger.warning("No password found")
        return nil
    }
    
    func isConfigured() -> Bool {
        let hasUsername = getUsername() != nil
        let hasPassword = getPassword() != nil
        let hasServerURL = getServerURL() != nil
        let configured = hasUsername && hasPassword && hasServerURL
        
        logger.info("Configuration check - Username: \(hasUsername), Password: \(hasPassword), Server: \(hasServerURL), Configured: \(configured)")
        return configured
    }
}

// MARK: - Mock Token Provider for Testing
class MockTokenProvider: PTokenProvider {
    var mockToken: String?
    var mockServerURL: String?
    var mockUsername: String?
    var mockPassword: String?
    var mockConfigured: Bool = false
    
    init(token: String? = nil, serverURL: String? = nil, username: String? = nil, password: String? = nil, configured: Bool = false) {
        self.mockToken = token
        self.mockServerURL = serverURL
        self.mockUsername = username
        self.mockPassword = password
        self.mockConfigured = configured
    }
    
    func getAuthToken() -> String? {
        return mockToken
    }
    
    func getServerURL() -> String? {
        return mockServerURL
    }
    
    func getUsername() -> String? {
        return mockUsername
    }
    
    func getPassword() -> String? {
        return mockPassword
    }
    
    func isConfigured() -> Bool {
        return mockConfigured
    }
}
