import XCTest
@testable import Evenly

@MainActor
final class AppUpdateManagerTests: XCTestCase {
    func testNumericVersionComparison() {
        XCTAssertTrue(AppUpdateManager.isNewer("1.10", than: "1.9"))
        XCTAssertTrue(AppUpdateManager.isNewer("2.0", than: "1.99.99"))
        XCTAssertFalse(AppUpdateManager.isNewer("1.2.0", than: "1.2"))
        XCTAssertFalse(AppUpdateManager.isNewer("1.1", than: "1.2"))
        for invalid in ["", "1..2", "1.2-beta", "1.2.3.4"] {
            XCTAssertFalse(AppUpdateManager.isNewer(invalid, than: "1.0"))
        }
    }

    func testChecksAreThrottledAndSnoozeSurvivesRestart() async {
        let suite = "AppUpdateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var date = Date(timeIntervalSince1970: 1_000_000)
        var calls = 0
        var release = makeRelease("1.10")
        let manager = AppUpdateManager(defaults: defaults, currentVersion: "1.9", now: { date }) {
            calls += 1
            return release
        }
        await manager.checkIfNeeded()
        XCTAssertEqual(manager.pendingRelease?.latestVersion, "1.10")
        await manager.checkIfNeeded()
        XCTAssertEqual(calls, 1)
        manager.snooze()
        await manager.checkIfNeeded()
        XCTAssertNil(manager.pendingRelease)
        let restarted = AppUpdateManager(defaults: defaults, currentVersion: "1.9", now: { date }) { release }
        await restarted.checkIfNeeded()
        XCTAssertNil(restarted.pendingRelease)
        date = date.addingTimeInterval(3 * 24 * 60 * 60)
        await restarted.checkIfNeeded()
        XCTAssertNotNil(restarted.pendingRelease)
        restarted.snooze()
        release = makeRelease("1.11")
        date = date.addingTimeInterval(6 * 60 * 60)
        await restarted.checkIfNeeded()
        XCTAssertEqual(restarted.pendingRelease?.latestVersion, "1.11")
    }

    func testInstalledVersionAndDisabledReleaseDoNotPrompt() async {
        for version in ["", "1.0", "0.9"] {
            let manager = AppUpdateManager(currentVersion: "1.0") { self.makeRelease(version) }
            await manager.checkIfNeeded()
            XCTAssertNil(manager.pendingRelease)
        }
    }

    func testNetworkFailureRetriesWithoutPrompt() async {
        var date = Date(timeIntervalSince1970: 1_000_000)
        var calls = 0
        let manager = AppUpdateManager(currentVersion: "1.0", now: { date }) {
            calls += 1
            throw URLError(.notConnectedToInternet)
        }
        await manager.checkIfNeeded()
        await manager.checkIfNeeded()
        XCTAssertEqual(calls, 1)
        XCTAssertNil(manager.pendingRelease)
        date = date.addingTimeInterval(15 * 60)
        await manager.checkIfNeeded()
        XCTAssertEqual(calls, 2)
    }

    func testUnexpectedStoreURLDoesNotPrompt() async {
        let manager = AppUpdateManager(currentVersion: "1.0") {
            IOSUpdateRelease(latestVersion: "2.0", message: "", appStoreURL: "https://example.com", remindAfterDays: 3)
        }
        await manager.checkIfNeeded()
        XCTAssertNil(manager.pendingRelease)
    }

    private func makeRelease(_ version: String) -> IOSUpdateRelease {
        IOSUpdateRelease(latestVersion: version, message: "更新说明", appStoreURL: IOSUpdateRelease.storeURL.absoluteString, remindAfterDays: 3)
    }
}
