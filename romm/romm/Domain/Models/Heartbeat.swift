//
//  Heartbeat.swift
//  romm
//

import Foundation

struct Heartbeat: Equatable {
    let version: String

    init(version: String) {
        self.version = version
    }
}
