import XCTest
@testable import Evenly

final class EvenlyTests: XCTestCase {
    func testSanity() {
        XCTAssertEqual("Evenly", "Evenly")
    }

    func testLedgerSummaryDecodesIntoLedger() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Trip",
          "owner_id": "22222222-2222-2222-2222-222222222222",
          "currency": "CNY",
          "member_count": 3,
          "expense_count": 2
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LedgerResponse.self, from: json)
        let ledger = Ledger(from: response)

        XCTAssertEqual(ledger.memberCount, 3)
        XCTAssertEqual(ledger.expenseCount, 2)
    }

    func testLegacyLedgerCacheDecodesWithoutSummaryFields() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Trip",
          "ownerId": "owner",
          "memberIds": [],
          "participants": [],
          "expenses": []
        }
        """.data(using: .utf8)!

        let ledger = try JSONDecoder().decode(Ledger.self, from: json)

        XCTAssertEqual(ledger.memberCount, 0)
        XCTAssertEqual(ledger.expenseCount, 0)
    }
}
