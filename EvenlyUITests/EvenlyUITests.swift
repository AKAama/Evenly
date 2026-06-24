import XCTest

final class EvenlyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsUsableEntryPoint() throws {
        let app = XCUIApplication()
        app.launch()

        let loginTitle = app.staticTexts["Evenly"]
        let ledgerTab = app.tabBars.buttons["账本"]
        let settingsTab = app.tabBars.buttons["设置"]

        XCTAssertTrue(
            loginTitle.waitForExistence(timeout: 5)
                || ledgerTab.waitForExistence(timeout: 2)
                || settingsTab.waitForExistence(timeout: 2)
        )
    }
}
