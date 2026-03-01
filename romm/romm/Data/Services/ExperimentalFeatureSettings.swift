//
//  ExperimentalFeatureSettings.swift
//  romm
//
//  Created by Ilyas Hallak on 27.02.26.
//

import Foundation

class ExperimentalFeatureSettings: ObservableObject {
    static let shared = ExperimentalFeatureSettings()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let emulatorEnabled = "experimental_emulator_enabled"
    }

    @Published var isEmulatorEnabled: Bool {
        didSet {
            userDefaults.set(isEmulatorEnabled, forKey: Keys.emulatorEnabled)
        }
    }

    private init() {
        self.isEmulatorEnabled = userDefaults.bool(forKey: Keys.emulatorEnabled)
    }
}
