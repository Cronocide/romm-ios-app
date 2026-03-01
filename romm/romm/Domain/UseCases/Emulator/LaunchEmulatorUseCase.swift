//
//  LaunchEmulatorUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 21.12.24.
//

import Foundation

/// Result of emulator pre-flight checks
enum EmulatorLaunchResult {
    case success
    case failure(EmulatorLaunchError)
}

/// Possible errors when launching the emulator
enum EmulatorLaunchError: LocalizedError {
    case noServerConfigured
    case unsupportedPlatform(String)
    case romNotAvailable
    case serverUnreachable
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noServerConfigured:
            return "No server configured. Please set up your ROMM server in Settings."
        case .unsupportedPlatform(let platform):
            return "Platform '\(platform)' is not supported for emulation."
        case .romNotAvailable:
            return "ROM file is not available. Please download it first or check your server connection."
        case .serverUnreachable:
            return "Cannot reach ROMM server. Please check your connection."
        case .unknown(let message):
            return message
        }
    }
}

/// Use case to perform pre-flight checks before launching the emulator
protocol PLaunchEmulatorUseCase {
    func execute(rom: Rom) async -> EmulatorLaunchResult
}

class LaunchEmulatorUseCase: PLaunchEmulatorUseCase {
    private let tokenProvider: PTokenProvider
    private let checkEmulatorSupport: PCheckEmulatorSupportUseCase
    private let logger = Logger.viewModel

    init(
        tokenProvider: PTokenProvider = TokenProvider(),
        checkEmulatorSupport: PCheckEmulatorSupportUseCase = CheckEmulatorSupportUseCase()
    ) {
        self.tokenProvider = tokenProvider
        self.checkEmulatorSupport = checkEmulatorSupport
    }

    /// Perform pre-flight checks before launching the emulator
    /// - Parameter rom: The ROM to launch
    /// - Returns: Success or failure with specific error
    func execute(rom: Rom) async -> EmulatorLaunchResult {
        logger.info("Pre-flight checks for ROM: \(rom.name) (ID: \(rom.id))")

        // Check 1: Server configured
        guard tokenProvider.getServerURL() != nil else {
            logger.error("No server configured")
            return .failure(.noServerConfigured)
        }

        // Check 2: Platform supported
        guard let platformSlug = rom.platformSlug else {
            logger.error("ROM has no platform information")
            return .failure(.unsupportedPlatform("Unknown"))
        }

        guard checkEmulatorSupport.execute(platformSlug: platformSlug) else {
            logger.error("Platform not supported: \(platformSlug)")
            return .failure(.unsupportedPlatform(platformSlug))
        }

        // Check 3: ROM file name available (needed for server URL construction)
        // Note: We don't check local file existence here as ROM might be on server
        if rom.fileName == nil {
            logger.warning("ROM has no fileName - will use ROM name as fallback")
        }

        // All checks passed
        logger.info("Pre-flight checks passed for ROM: \(rom.name)")
        return .success
    }
}
