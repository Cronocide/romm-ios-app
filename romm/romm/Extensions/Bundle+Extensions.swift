//
//  Bundle+Extensions.swift
//  romm
//
//  Created by Ilyas Hallak on 13.08.25.
//

import Foundation

extension Bundle {
    /// Returns true if the app is running in Debug mode
    var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
