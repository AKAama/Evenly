import XCTest
@testable import Evenly

@MainActor
final class ChangelogTests: XCTestCase {
    func testBundledChangelogCanBeReadAndHasCompleteEntries() throws {
        let entries = try ChangelogEntry.load()

        XCTAssertFalse(entries.isEmpty)
        XCTAssertNotNil(entries.first?.version)
        XCTAssertEqual(entries.first?.version,
                       Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        for entry in entries {
            XCTAssertFalse(entry.id.isEmpty)
            XCTAssertFalse(entry.date.isEmpty)
            XCTAssertFalse(entry.title.isEmpty)
            XCTAssertFalse(entry.items.isEmpty)
            XCTAssertTrue(entry.items.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            if let version = entry.version {
                XCTAssertNotNil(version.range(of: #"^\d+\.\d+(\.\d+)?$"#, options: .regularExpression))
            }
        }
    }
}
