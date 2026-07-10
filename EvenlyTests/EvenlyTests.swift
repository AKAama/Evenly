import XCTest
@testable import Evenly

final class EvenlyTests: XCTestCase {
    private static var retainedStores: [LedgerStore] = []

    func testSanity() {
        XCTAssertEqual("Evenly", "Evenly")
    }

    func testLedgerDrawerOmitsAccountHeader() throws {
        let source = try sourceFile(named: "LedgerDrawerView.swift")

        XCTAssertFalse(source.contains("userHeaderView"))
        XCTAssertFalse(source.contains("RemoteAvatarView("))
    }

    func testLedgerMenuButtonSupportsLongPressAddLedgerShortcut() throws {
        let source = try sourceFile(named: "ContentView.swift")

        XCTAssertTrue(source.contains(".onLongPressGesture(perform: openAddLedgerFromLedgerMenu)"))
    }

    func testExpenseRowsExposeContextMenuActions() throws {
        let source = try sourceFile(named: "ContentView.swift")

        XCTAssertTrue(source.contains(".contextMenu {"))
        XCTAssertTrue(source.contains("Label(\"复制标题\", systemImage: \"doc.on.doc\")"))
        XCTAssertTrue(source.contains("Label(\"查看详情\", systemImage: \"info.circle\")"))
    }

    func testExpenseRowsExposeLeadingSwipeConfirmationAction() throws {
        let source = try sourceFile(named: "ContentView.swift")

        XCTAssertTrue(source.contains(".swipeActions(edge: .leading, allowsFullSwipe: true)"))
        XCTAssertTrue(source.contains("Label(\"确认\", systemImage: \"checkmark.circle.fill\")"))
    }

    func testVoiceExpenseUsesStreamingEndpoint() {
        let ledgerId = "11111111-1111-1111-1111-111111111111"

        XCTAssertEqual(
            APIEndpoints.voiceExpenseSession(ledgerId: ledgerId),
            "/expenses/ledgers/\(ledgerId)/voice-session"
        )
    }

    func testAPIClientBuildsWebSocketURLFromHTTPBaseURL() throws {
        let url = try XCTUnwrap(APIClient.webSocketURL(
            baseURL: "https://evenly.ismyh.cn/api",
            endpoint: "/expenses/ledgers/ledger-1/voice-session"
        ))

        XCTAssertEqual(url.absoluteString, "wss://evenly.ismyh.cn/api/expenses/ledgers/ledger-1/voice-session")
    }

    func testAPIClientUsesDedicatedLongLivedWebSocketSession() throws {
        let source = try sourceFile(named: "APIClient.swift")

        XCTAssertTrue(source.contains("private let webSocketSession: URLSession"))
        XCTAssertTrue(source.contains("webSocketConfig.timeoutIntervalForRequest = 0"))
        XCTAssertTrue(source.contains("return webSocketSession.webSocketTask(with: request)"))
    }

    func testAddExpenseViewUsesStreamingVoiceSessionInsteadOfUploadDraft() throws {
        let source = try sourceFile(named: "AddExpenseView.swift")

        XCTAssertTrue(source.contains("VoiceExpenseStreamingSession"))
        XCTAssertTrue(source.contains("voiceSession.start"))
        XCTAssertFalse(source.contains("requestWithFormData("))
        XCTAssertFalse(source.contains("voiceExpenseDraft("))
    }

    func testVoiceStreamingReusesAudioConverterOutsideTapCallback() throws {
        let source = try sourceFile(named: "AddExpenseView.swift")

        XCTAssertTrue(source.contains("private var audioConverter: AVAudioConverter?"))
        XCTAssertTrue(source.contains("audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat)"))
        XCTAssertFalse(source.contains("let converter = AVAudioConverter(from: inputFormat, to: targetFormat)"))
    }

    func testVoiceStreamingShowsProcessingStatusAfterStop() throws {
        let source = try sourceFile(named: "AddExpenseView.swift")

        XCTAssertTrue(source.contains("@Published private(set) var statusMessage"))
        XCTAssertTrue(source.contains("正在识别并生成草稿..."))
        XCTAssertTrue(source.contains("voiceSession.statusMessage"))
    }

    func testAddExpenseViewShowsVoiceInputExamples() throws {
        let source = try sourceFile(named: "AddExpenseView.swift")

        XCTAssertTrue(source.contains("private var voiceGuidanceView: some View"))
        XCTAssertTrue(source.contains("试试这样说"))
        XCTAssertTrue(source.contains("我和Tristan住宿花了 300，是我付的"))
        XCTAssertTrue(source.contains("晚餐 268，Sylvia付，我、Stella和Tristan平摊"))
        XCTAssertTrue(source.contains("打车 78，Tristan付的，我和Tristan各 39"))
        XCTAssertTrue(source.contains("voiceGuidanceView"))
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

    private func sourceFile(named fileName: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let sourceRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Evenly")

        let directURL = sourceRoot
            .appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: directURL.path) {
            return try String(contentsOf: directURL)
        }

        let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == fileName {
                return try String(contentsOf: url)
            }
        }

        throw CocoaError(.fileNoSuchFile)
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
            "username": "stella",
            "display_name": "Stella",
            "username_is_generated": false
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
            UserResponse(id: "user-1", email: "stella@example.com", username: "stella", displayName: "Stella", avatarUrl: nil, createdAt: nil, usernameIsGenerated: false),
            UserResponse(id: "user-2", email: "tristan@example.com", username: "tristan", displayName: "Tristan", avatarUrl: nil, createdAt: nil, usernameIsGenerated: false)
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

    // Regression: backend member ids are lowercase UUID strings, but
    // `UUID(uuidString:).uuidString` is always uppercase. Comparisons that mix
    // the two forms silently fail for any id containing hex letters (the prior
    // tests only used all-digit ids like 33333333-… and hid the bug).
    func testExpenseDecodeKeepsTemporaryParticipantWithLetterHexUUID() throws {
        // Lowercase member id with hex letters, exactly as the backend serializes it.
        let temporaryMemberId = "abcdef12-1234-1234-1234-1234567890ab"
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
            "username": "stella",
            "display_name": "Stella",
            "username_is_generated": false
          },
          "splits": [
            {
              "id": "55555555-5555-5555-5555-555555555555",
              "expense_id": "44444444-4444-4444-4444-444444444444",
              "user_id": null,
              "member_id": "\(temporaryMemberId)",
              "amount": "6.00"
            }
          ],
          "confirmations": []
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ExpenseWithDetails.self, from: json)
        let temporary = Person(
            id: UUID(uuidString: temporaryMemberId)!,
            name: "Temporary",
            isTemporary: true
        )

        let expense = Expense(from: response, participants: [temporary])

        XCTAssertEqual(expense.participants, [temporary])
    }

    func testRegisteredUserIdResolvesMemberWithLetterHexUUID() throws {
        let ownerId = "22222222-2222-2222-2222-222222222222"
        let ownerMemberId = "abcdef12-1234-1234-1234-1234567890ab"
        let memberJSON = """
        {
          "id": "\(ownerMemberId)",
          "user_id": "\(ownerId)",
          "nickname": "Stella",
          "is_temporary": false
        }
        """.data(using: .utf8)!
        let owner = try JSONDecoder().decode(MemberResponse.self, from: memberJSON)
        let ledger = Ledger(
            title: "Trip",
            ownerId: ownerId,
            participants: [Person(from: owner)],
            members: [owner]
        )
        // Person.id is the uppercase UUID form; the lookup must still match the
        // lowercase member id and resolve the registered payer's user id.
        let payer = ledger.participants.first!

        XCTAssertEqual(ledger.registeredUserId(for: payer), ownerId)
    }

    @MainActor
    func testExpensePayerSurvivesStoredAsyncClosureBoundary() async {
        let payer = Person(
            id: UUID(uuidString: "1c726a4f-c2df-4734-b6f6-f043e52bf4f1")!,
            name: "Stella",
            userId: "a9a58c1b-17a4-43ce-b2b6-f2ba5b61a3c6"
        )
        var receivedPayer: Person?
        let view = AddExpenseView(participants: [payer]) { expense in
            receivedPayer = expense.payer
            return .success(())
        }
        let expense = Expense(
            title: "Regression",
            amount: 12.34,
            payer: payer,
            participants: [payer]
        )

        _ = await view.onSave(expense)

        XCTAssertEqual(receivedPayer?.id, payer.id)
        XCTAssertEqual(receivedPayer?.userId, payer.userId)
    }

    func testExpenseResponseDecodesSynchronizedCategoryIcon() throws {
        let json = """
        {
          "id": "44444444-4444-4444-4444-444444444444",
          "ledger_id": "11111111-1111-1111-1111-111111111111",
          "payer_id": "22222222-2222-2222-2222-222222222222",
          "created_by": "22222222-2222-2222-2222-222222222222",
          "title": "午餐",
          "total_amount": "28.00",
          "status": "confirmed",
          "category": "餐饮",
          "icon_type": "emoji",
          "icon_value": "🍜"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ExpenseResponse.self, from: json)

        XCTAssertEqual(response.category, "餐饮")
        XCTAssertEqual(response.iconType, "emoji")
        XCTAssertEqual(response.iconValue, "🍜")
    }

    func testExpenseCategoryCatalogMapsPresetToCategoryAndIcon() throws {
        let preset = try XCTUnwrap(ExpenseCategoryCatalog.preset(named: "午餐"))

        XCTAssertEqual(preset.category, "餐饮")
        XCTAssertEqual(preset.icon.type, .sfSymbol)
        XCTAssertEqual(preset.icon.value, "sun.max.fill")
        XCTAssertTrue(ExpenseCategoryCatalog.emojiIcons.contains { $0.value == "🍜" })
    }

    func testExpenseCreateEncodesCategoryAndEmojiIcon() throws {
        let payer = Person(name: "Owner", userId: "22222222-2222-2222-2222-222222222222")
        let expense = Expense(
            title: "午餐",
            amount: 28,
            payer: payer,
            participants: [payer],
            category: "餐饮",
            icon: ExpenseIcon(type: .emoji, value: "🍜")
        )

        let data = try JSONEncoder().encode(expense.toCreateRequest(payerId: payer.userId!, ledgerId: UUID()))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["category"] as? String, "餐饮")
        XCTAssertEqual(json["icon_type"] as? String, "emoji")
        XCTAssertEqual(json["icon_value"] as? String, "🍜")
    }
}
