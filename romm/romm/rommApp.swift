//
//  rommApp.swift
//  romm
//
//  Created by Ilyas Hallak on 06.08.25.
//

import SwiftUI

@main
struct rommApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Initialize Kingfisher cache configuration at app startup
        _ = KingfisherCacheManager.shared
    }

    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}
