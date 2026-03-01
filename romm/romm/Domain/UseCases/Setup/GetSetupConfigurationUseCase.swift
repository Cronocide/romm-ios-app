//
//  GetSetupConfigurationUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 07.08.25.
//

import Foundation

protocol PGetSetupConfigurationUseCase {
    func execute() throws -> SetupConfiguration?
}

class GetSetupConfigurationUseCase: PGetSetupConfigurationUseCase {
    private let logger = Logger.general
    private let setupRepository: PSetupRepository
    
    init(setupRepository: PSetupRepository) {
        self.setupRepository = setupRepository
    }
    
    func execute() throws -> SetupConfiguration? {
        logger.info("Getting setup configuration...")
        
        let config = setupRepository.getSetupConfiguration()
        
        if let config = config {
            logger.info("Setup configuration found")
            logger.info("Setup date: \(config.setupDate)")
            logger.info("Version: \(config.version)")
        } else {
            logger.info("No setup configuration found")
        }
        
        return config
    }
}

protocol PCheckSetupStatusUseCase {
    func execute() -> Bool
}

class CheckSetupStatusUseCase: PCheckSetupStatusUseCase {
    private let logger = Logger.general
    private let setupRepository: PSetupRepository
    
    init(setupRepository: PSetupRepository) {
        self.setupRepository = setupRepository
    }
    
    func execute() -> Bool {
        let isSetup = setupRepository.isSetupComplete()
        logger.info("Setup status check: \(isSetup)")
        return isSetup
    }
}

protocol PClearSetupConfigurationUseCase {
    func execute() throws
}

class ClearSetupConfigurationUseCase: PClearSetupConfigurationUseCase {
    private let logger = Logger.general
    private let setupRepository: PSetupRepository
    private let configurationService: ConfigurationService
    
    init(setupRepository: PSetupRepository, configurationService: ConfigurationService) {
        self.setupRepository = setupRepository
        self.configurationService = configurationService
    }
    
    func execute() throws {
        logger.info("Clearing setup configuration...")
        
        try setupRepository.clearSetupConfiguration()
        try configurationService.clearConfiguration()
        
        logger.info("Setup configuration cleared")
    }
}