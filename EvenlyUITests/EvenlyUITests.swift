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

    func testLoginUsesBrandLogoAndDismissesKeyboardOnSubmit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetAuth"]
        app.launch()

        XCTAssertTrue(app.images["login-logo"].waitForExistence(timeout: 5))

        let email = app.textFields["login-email"]
        let password = app.secureTextFields["login-password"]
        email.tap()
        email.typeText("aj@qq.com")
        password.tap()
        password.typeText("admin123")
        XCTAssertTrue(app.keyboards.element.exists)

        app.buttons["登录"].tap()

        let keyboardDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [keyboardDismissed], timeout: 2), .completed)
    }
}
