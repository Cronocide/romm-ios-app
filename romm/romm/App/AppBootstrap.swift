import Foundation
import DeltaCore
import GBADeltaCore
import SNESDeltaCore
import GPGXDeltaCore
import NESDeltaCore
import GBCDeltaCore
import N64DeltaCore
import MelonDSDeltaCore

enum AppBootstrap {
    static func run() {
        registerNativeCores()
        ExternalGameControllerManager.shared.startMonitoring()
    }

    private static func registerNativeCores() {
        Delta.register(GBA.core)
        Delta.register(SNES.core)
        Delta.register(GPGX.core)
        Delta.register(NES.core)
        Delta.register(GBC.core)
        Delta.register(N64.core)
        Delta.register(MelonDS.core)
    }
}
