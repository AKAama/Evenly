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

    func testExpenseRequestEncodesDateAsCalendarDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!
        let payer = Person(name: "Stella", userId: "22222222-2222-2222-2222-222222222222")
        let expense = Expense(
            title: "Lunch",
            amount: 12,
            payer: payer,
            participants: [payer],
            expenseDate: date
        )

        let request = expense.toCreateRequest(
            payerId: payer.userId!,
            ledgerId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        )
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["expense_date"] as? String, "2026-06-28")
    }

    func testAPIErrorUsesFastAPIDetail() {
        let data = #"{"detail":"Payer must be a registered ledger member"}"#.data(using: .utf8)!

        let error = APIError.server(statusCode: 400, data: data)

        XCTAssertEqual(error.localizedDescription, "Payer must be a registered ledger member")
    }

    func testLocalLedgerParticipantBecomesTemporaryPerson() {
        let participant = AddLedgerView.ParticipantInfo(name: "Stella", status: .local)

        XCTAssertTrue(participant.person.isTemporary)
        XCTAssertNil(participant.person.userId)
    }

    func testMemberSearchFiltersAlreadySelectedUsers() {
        let selected = AddLedgerView.ParticipantInfo(
            name: "Stella",
            status: .found(userId: "user-1", name: "Stella")
        )
        let results = [
            UserResponse(id: "user-1", email: "stella@example.com", displayName: "Stella", avatarUrl: nil, createdAt: nil),
            UserResponse(id: "user-2", email: "tristan@example.com", displayName: "Tristan", avatarUrl: nil, createdAt: nil)
        ]

        let filtered = AddLedgerView.filteredSearchResults(results, excluding: [selected])

        XCTAssertEqual(filtered.map(\.id), ["user-2"])
    }
}
