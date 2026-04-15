//
//  AppDelegate.swift
//  romm
//
//  Created by Codex on 15.02.26.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.currentMask
    }

    // Handle URL callbacks (client token pairing)
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        Logger.auth.info("App received URL: \(url.absoluteString)")

        guard url.scheme == "romm" else {
            Logger.auth.warning("Unknown URL scheme: \(url.scheme ?? "none")")
            return false
        }

        switch url.host {
        case "pair":
            Logger.auth.info("Pairing deep link received")
            let service = ClientTokenAuthService()
            if let code = service.handleDeepLink(url: url) {
                NotificationCenter.default.post(
                    name: .clientTokenPairingCode,
                    object: nil,
                    userInfo: ["code": code]
                )
            }
            return true

        default:
            Logger.auth.warning("Unknown URL host: \(url.host ?? "none")")
            return false
        }
    }
}

extension Notification.Name {
    static let clientTokenPairingCode = Notification.Name("clientTokenPairingCode")
}
