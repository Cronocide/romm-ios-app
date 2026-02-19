//
//  rommUITests.swift
//  rommUITests
//
//  Created by Ilyas Hallak on 06.08.25.
//

import XCTest

final class rommUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTakeScreenshots() throws {
        let loginApp = XCUIApplication()
        setupSnapshot(loginApp)
        loginApp.launchArguments += [
            "-ui_testing_force_setup",
            "-ui_testing_show_login"
        ]
        loginApp.launch()

        XCTAssertTrue(loginApp.buttons["Login"].waitForExistence(timeout: 10))
        snapshot("01_Login", timeWaitingForIdle: 0)
        loginApp.terminate()

        let settingsApp = XCUIApplication()
        setupSnapshot(settingsApp)
        settingsApp.launchArguments += [
            "-ui_testing_force_authenticated"
        ]
        settingsApp.launch()

        let settingsTab = settingsApp.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()
        XCTAssertTrue(settingsApp.navigationBars["Settings"].waitForExistence(timeout: 10))
        snapshot("02_Settings", timeWaitingForIdle: 0)
    }
}
