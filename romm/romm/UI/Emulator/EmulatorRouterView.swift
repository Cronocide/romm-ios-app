//
//  EmulatorRouterView.swift
//  romm
//
//  Created by Ilyas Hallak on 15.05.26.
//

import SwiftUI

struct EmulatorRouterView: View {
    let decision: LaunchDecision

    var body: some View {
        switch decision {
        case .web(let rom):
            EmulatorView(rom: rom)
        case .deltaCore(let rom, let gameType):
            DeltaEmulatorView(rom: rom, gameType: gameType)
        case .libretro(let rom, let core):
            LibretroEmulatorView(rom: rom, core: core)
        }
    }
}
