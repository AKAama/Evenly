import XCTest
@testable import Evenly

final class EvenlyTests: XCTestCase {
    private static var retainedStores: [LedgerStore] = []

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

    func testExpenseRequestIncludesTemporaryLedgerMemberSplit() throws {
        let payer = Person(name: "Stella", userId: "22222222-2222-2222-2222-222222222222")
        let temporary = Person(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Temporary",
            isTemporary: true
        )
        let expense = Expense(title: "Lunch", amount: 12, payer: payer, participants: [payer, temporary])

        let request = expense.toCreateRequest(
            payerId: payer.userId!,
            ledgerId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        )
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let splits = try XCTUnwrap(object["splits"] as? [[String: Any]])

        XCTAssertEqual(splits.count, 2)
        let temporarySplit = try XCTUnwrap(splits.first {
            $0["user_id"] == nil || $0["user_id"] is NSNull
        })
        XCTAssertEqual(temporarySplit["member_id"] as? String, temporary.id.uuidString)
    }

    func testLedgerResponseWithoutSummaryRequiresHydration() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Trip",
          "owner_id": "22222222-2222-2222-2222-222222222222",
          "currency": "CNY"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LedgerResponse.self, from: json)

        XCTAssertTrue(response.needsSummaryHydration)
    }

    func testExpenseDetailsMapsTemporarySplitByLedgerMemberID() throws {
        let temporaryId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let json = """
        {
          "id": "44444444-4444-4444-4444-444444444444",
          "ledger_id": "11111111-1111-1111-1111-111111111111",
          "payer_id": "22222222-2222-2222-2222-222222222222",
          "created_by": "22222222-2222-2222-2222-222222222222",
          "title": "Lunch",
          "total_amount": "12.00",
          "status": "pending",
          "payer": {
            "id": "22222222-2222-2222-2222-222222222222",
            "email": "stella@example.com",
            "display_name": "Stella"
          },
          "splits": [
            {
              "id": "55555555-5555-5555-5555-555555555555",
              "expense_id": "44444444-4444-4444-4444-444444444444",
              "user_id": null,
              "member_id": "33333333-3333-3333-3333-333333333333",
              "amount": "6.00"
            }
          ],
          "confirmations": []
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ExpenseWithDetails.self, from: json)
        let temporary = Person(id: temporaryId, name: "Temporary", isTemporary: true)

        let expense = Expense(from: response, participants: [temporary])

        XCTAssertEqual(expense.participants, [temporary])
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

    @MainActor
    func testApplyingLedgerUpdateImmediatelyExposesNewMemberByID() {
        let ledgerId = UUID()
        let store = LedgerStore()
        Self.retainedStores.append(store)
        store.applyUpdatedLedger(Ledger(id: ledgerId, title: "Trip", ownerId: "owner"))
        let stella = Person(name: "Stella", userId: "user-1")

        store.applyUpdatedLedger(
            Ledger(id: ledgerId, title: "Trip", ownerId: "owner", participants: [stella])
        )

        XCTAssertEqual(store.ledger(id: ledgerId)?.participants, [stella])
        XCTAssertEqual(store.ledger(id: ledgerId)?.memberCount, 1)
    }

    func testPersonIdentityRemainsStableWhenUserMetadataChanges() {
        let memberId = UUID()
        let stale = Person(id: memberId, name: "Stella")
        let registered = Person(id: memberId, name: "Stella", userId: "user-1")

        XCTAssertEqual(stale, registered)
        XCTAssertEqual(Set([stale, registered]).count, 1)
    }

    func testLedgerResolvesRegisteredPayerFromMemberID() {
        let memberId = UUID()
        let stalePayer = Person(id: memberId, name: "Stella")
        let registered = Person(id: memberId, name: "Stella", userId: "user-1")
        let ledger = Ledger(
            title: "Trip",
            ownerId: "user-1",
            participants: [registered]
        )

        XCTAssertEqual(ledger.registeredUserId(for: stalePayer), "user-1")
    }
}
