//
//  LaunchEmulatorUseCase.swift
//  romm
//
//  Created by Ilyas Hallak on 21.12.24.
//

import Foundation

enum LaunchDecision {
    case web(rom: Rom)
    case deltaCore(rom: Rom, gameType: DeltaGameType)
}

enum EmulatorLaunchResult {
    case success(LaunchDecision)
    case failure(EmulatorLaunchError)
}

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

protocol PLaunchEmulatorUseCase {
    func execute(rom: Rom) async -> EmulatorLaunchResult
}

final class LaunchEmulatorUseCase: PLaunchEmulatorUseCase {
    private let tokenProvider: PTokenProvider
    private let checkEmulatorSupport: PCheckEmulatorSupportUseCase
    private let enginePreference: PEmulatorEnginePreference
    private let platformSupport: PPlatformEngineSupport
    private let logger = Logger.viewModel

    init(
        tokenProvider: PTokenProvider = TokenProvider(),
        checkEmulatorSupport: PCheckEmulatorSupportUseCase = CheckEmulatorSupportUseCase(),
        enginePreference: PEmulatorEnginePreference = EmulatorEnginePreference(),
        platformSupport: PPlatformEngineSupport = PlatformEngineSupport()
    ) {
        self.tokenProvider = tokenProvider
        self.checkEmulatorSupport = checkEmulatorSupport
        self.enginePreference = enginePreference
        self.platformSupport = platformSupport
    }

    func execute(rom: Rom) async -> EmulatorLaunchResult {
        guard tokenProvider.getServerURL() != nil else {
            return .failure(.noServerConfigured)
        }
        guard let platformSlug = rom.platformSlug else {
            return .failure(.unsupportedPlatform("Unknown"))
        }
        guard checkEmulatorSupport.execute(platformSlug: platformSlug) else {
            return .failure(.unsupportedPlatform(platformSlug))
        }

        let supported = platformSupport.supportedEngines(for: platformSlug)
        let pref = enginePreference.current
        logger.info("LaunchEmulator: platformSlug='\(platformSlug)', preference=\(pref.rawValue), supported=\(supported.map { $0.rawValue })")
        let chosen: EmulatorEngine = {
            switch pref {
            case .web: return supported.contains(.web) ? .web : .deltaCore
            case .deltaCore: return supported.contains(.deltaCore) ? .deltaCore : .web
            case .auto: return platformSupport.preferred(for: platformSlug)
            }
        }()
        logger.info("LaunchEmulator: chosen engine=\(chosen.rawValue)")

        switch chosen {
        case .web:
            return .success(.web(rom: rom))
        case .deltaCore:
            guard let gameType = PlatformSlugToGameType.map(platformSlug) else {
                return .success(.web(rom: rom))
            }
            return .success(.deltaCore(rom: rom, gameType: gameType))
        case .auto:
            return .success(.web(rom: rom))
        }
    }
}
