# Evenly iOS Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复登录、账本摘要、成员、账单、结算和头像相关的 11 项 iOS 问题，并用后端与 iOS 自动化测试验证。

**Architecture:** 后端列表接口提供聚合摘要和稳定错误；iOS 以 `LedgerStore` 与 `AuthManager` 为单一状态源。搜索、防抖、请求编码和筛选规则尽量提取为可单元测试的纯逻辑，SwiftUI 页面只负责渲染和触发动作。

**Tech Stack:** FastAPI、SQLAlchemy、pytest、SwiftUI、PhotosUI、XCTest、XCUITest、Xcode 17。

---

## File Map

- Modify `../evenly-backend-service/app/schemas/ledger.py`: 账本摘要响应字段。
- Modify `../evenly-backend-service/app/routers/ledgers.py`: 聚合成员数和账单数。
- Modify `../evenly-backend-service/app/routers/users.py`: 头像上传日志和稳定错误。
- Modify `../evenly-backend-service/tests/test_backend_rules.py`: 后端回归测试。
- Modify `Evenly/API/APIModels.swift`: 摘要字段、日期请求编码。
- Modify `Evenly/API/APIClient.swift`: 解析后端 `detail`。
- Modify `Evenly/Ledger.swift`: 摘要状态和临时成员映射。
- Modify `Evenly/LedgerStore.swift`: 实时合并、摘要同步和按用户 ID 添加成员。
- Modify `Evenly/LedgerListView.swift`: 始终显示摘要计数。
- Modify `Evenly/LedgerDrawerView.swift`: 摘要计数和远程头像。
- Modify `Evenly/LoginView.swift`: 新图标和统一键盘焦点。
- Create `Evenly/Assets.xcassets/LoginLogo.imageset/Contents.json`: 登录图标资源映射。
- Create `Evenly/Assets.xcassets/LoginLogo.imageset/LoginLogo.png`: 新 App Icon 的普通图片副本。
- Modify `Evenly/AddLedgerView.swift`: 防抖模糊搜索、候选选择、临时成员。
- Modify `Evenly/AddMemberView.swift`: 从 store 读取实时账本并立即刷新。
- Modify `Evenly/AddExpenseView.swift`: 默认日期与具体错误。
- Modify `Evenly/Expense.swift`: `yyyy-MM-dd` 请求转换。
- Modify `Evenly/ContentView.swift`: 隐藏已结清的“我的结算”。
- Modify `Evenly/SettlementDetailView.swift`: 只保留结算方案。
- Create `Evenly/RemoteAvatarView.swift`: 统一远程头像和回退显示。
- Modify `Evenly/SettingsView.swift`: 本地头像预览和上传状态。
- Modify `Evenly/AuthManager.swift`: 头像状态更新和主线程回调。
- Modify `EvenlyTests/EvenlyTests.swift`: 模型和纯逻辑单元测试。
- Modify `EvenlyUITests/EvenlyUITests.swift`: 登录与关键页面 UI 回归。

### Task 1: Backend ledger summaries

**Files:**
- Modify: `../evenly-backend-service/app/schemas/ledger.py`
- Modify: `../evenly-backend-service/app/routers/ledgers.py`
- Test: `../evenly-backend-service/tests/test_backend_rules.py`

- [ ] **Step 1: Write failing summary test**

Add a test that creates a ledger with one owner, one registered member, one temporary member and one expense, calls `get_ledgers`, and asserts:

```python
assert result[0].member_count == 3
assert result[0].expense_count == 1
```

- [ ] **Step 2: Verify the test fails**

Run:

```bash
uv run pytest tests/test_backend_rules.py -k ledger_summary -v
```

Expected: FAIL because `LedgerResponse` has no count fields.

- [ ] **Step 3: Add response fields and grouped counts**

Add to `LedgerResponse`:

```python
member_count: int = 0
expense_count: int = 0
```

Change `get_ledgers` to return `LedgerResponse` instances built from aggregate count subqueries. Use distinct IDs so joining members and expenses cannot multiply counts.

- [ ] **Step 4: Run backend tests**

```bash
uv run pytest tests/test_backend_rules.py -k 'ledger_summary or ledger' -v
```

Expected: all selected tests PASS.

### Task 2: iOS ledger summaries and single-source updates

**Files:**
- Modify: `Evenly/API/APIModels.swift`
- Modify: `Evenly/Ledger.swift`
- Modify: `Evenly/LedgerStore.swift`
- Modify: `Evenly/LedgerListView.swift`
- Modify: `Evenly/LedgerDrawerView.swift`
- Test: `EvenlyTests/EvenlyTests.swift`

- [ ] **Step 1: Write failing decoding and merge tests**

Decode a ledger JSON containing `member_count` and `expense_count`, then assert model values. Add a second test that replaces participants and expenses and checks summary synchronization.

```swift
XCTAssertEqual(ledger.memberCount, 3)
XCTAssertEqual(ledger.expenseCount, 2)
```

- [ ] **Step 2: Verify tests fail**

```bash
xcodebuild test -project Evenly.xcodeproj -scheme Evenly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:EvenlyTests
```

Expected: compile failure because summary properties do not exist.

- [ ] **Step 3: Implement summary mapping**

Add optional-compatible API fields:

```swift
let memberCount: Int?
let expenseCount: Int?
```

Map them into nonoptional `Ledger.memberCount` and `Ledger.expenseCount`. Add a store helper that replaces a ledger and derives counts from loaded arrays when available.

- [ ] **Step 4: Render summary values**

Change both ledger rows to always display:

```swift
Label("\(ledger.memberCount)", systemImage: "person.2")
Label("\(ledger.expenseCount)", systemImage: "list.bullet")
```

- [ ] **Step 5: Run iOS unit tests**

Run the Task 2 test command. Expected: PASS.

### Task 3: Expense date and useful API errors

**Files:**
- Modify: `Evenly/API/APIModels.swift`
- Modify: `Evenly/API/APIClient.swift`
- Modify: `Evenly/Expense.swift`
- Modify: `Evenly/AddExpenseView.swift`
- Modify: `Evenly/LedgerDetailView.swift`
- Test: `EvenlyTests/EvenlyTests.swift`

- [ ] **Step 1: Write failing request and error tests**

Assert an expense request encodes:

```json
"expense_date": "2026-06-28"
```

Assert `{"detail":"Payer must be a registered ledger member"}` becomes a localized API error containing that detail.

- [ ] **Step 2: Verify tests fail**

Run `EvenlyTests`; expected failure because the date is omitted and server errors only retain status codes.

- [ ] **Step 3: Implement deterministic date encoding**

Change `ExpenseCreate.expenseDate` to a `String`, format `expense.expenseDate ?? Date()` with an `en_US_POSIX` Gregorian `DateFormatter` using `yyyy-MM-dd`, and always include it.

- [ ] **Step 4: Preserve backend error detail**

Replace `serverError(Int)` with a case carrying status and optional detail. Decode FastAPI error bodies through:

```swift
private struct ErrorEnvelope: Decodable { let detail: String? }
```

Pass the actual error into `AddExpenseView` instead of reducing the result to `Bool`.

- [ ] **Step 5: Run iOS tests**

Expected: request and error tests PASS.

### Task 4: Login logo and keyboard behavior

**Files:**
- Create: `Evenly/Assets.xcassets/LoginLogo.imageset/Contents.json`
- Create: `Evenly/Assets.xcassets/LoginLogo.imageset/LoginLogo.png`
- Modify: `Evenly/LoginView.swift`
- Modify: `EvenlyUITests/EvenlyUITests.swift`

- [ ] **Step 1: Add login UI assertions**

Give the logo and fields stable accessibility identifiers and assert the logo exists, email submit moves focus to password, and password submit removes keyboard focus.

- [ ] **Step 2: Verify the UI test fails**

Run the login-only UI test. Expected: FAIL because the logo identifier and deterministic focus flow do not exist.

- [ ] **Step 3: Add the normal image asset**

Copy the opaque 1024px App Icon to `LoginLogo.png` and add a universal 1x image-set `Contents.json`.

- [ ] **Step 4: Implement one focus state**

Use:

```swift
enum LoginField: Hashable { case email, password }
@FocusState private var focusedField: LoginField?
```

Set `.submitLabel(.next)` and `.submitLabel(.go)`, clear focus before login, scroll after `Task.yield()`, add a keyboard “完成” button, and attach the blank-area gesture to the full content shape.

- [ ] **Step 5: Run login UI test and build**

Expected: test PASS and simulator build succeeds.

### Task 5: Debounced member search and temporary member creation

**Files:**
- Modify: `Evenly/AddLedgerView.swift`
- Modify: `Evenly/Ledger.swift`
- Modify: `Evenly/LedgerStore.swift`
- Test: `EvenlyTests/EvenlyTests.swift`
- Test: `EvenlyUITests/EvenlyUITests.swift`

- [ ] **Step 1: Write failing pure-logic tests**

Test that registered results already in participants are filtered out and that local participants convert to:

```swift
Person(name: "Stella", userId: nil, isTemporary: true)
```

- [ ] **Step 2: Verify tests fail**

Expected: temporary-member assertion fails because `isTemporary` is currently false.

- [ ] **Step 3: Implement cancellable search**

Use `.task(id: participantInput)` to trim input, require two characters, sleep 300ms, call search with limit 5, and check cancellation before assigning results. Render candidates directly below the field.

- [ ] **Step 4: Implement selection and temporary option**

Selecting a user appends `.found`; no results render “将「query」添加为临时成员”. Selecting it appends a temporary participant. Remove the exact-email-only add button flow.

- [ ] **Step 5: Save server response**

On create success, use the returned `LedgerWithMembers` already applied by `LedgerStore`; do not call `onSave` with the stale local ledger.

- [ ] **Step 6: Run unit and UI tests**

Expected: fuzzy candidate, duplicate filtering and temporary member tests PASS.

### Task 6: Live member management

**Files:**
- Modify: `Evenly/AddMemberView.swift`
- Modify: `Evenly/LedgerStore.swift`
- Modify: call sites in `Evenly/ContentView.swift`
- Test: `EvenlyTests/EvenlyTests.swift`

- [ ] **Step 1: Write failing store update test**

Apply a ledger containing a newly added member and assert the ledger selected by ID immediately exposes that member and updated count.

- [ ] **Step 2: Verify the test fails**

Expected: the current view contract cannot observe a ledger by ID.

- [ ] **Step 3: Replace the snapshot contract**

Change `AddMemberView` to accept `ledgerId`, derive:

```swift
private var ledger: Ledger? {
    ledgerStore.ledgers.first { $0.id == ledgerId }
}
```

Render members and counts from this value. Add registered users by ID without repeating an exact-email search.

- [ ] **Step 4: Verify immediate add/delete behavior**

Run unit tests and the member UI test. Expected: member appears or disappears without reopening the sheet.

### Task 7: Settlement simplification

**Files:**
- Modify: `Evenly/ContentView.swift`
- Modify: `Evenly/SettlementDetailView.swift`
- Test: `EvenlyTests/EvenlyTests.swift`

- [ ] **Step 1: Write failing settlement visibility test**

Extract a pure helper and assert an empty related-suggestion array returns `false` for section visibility.

- [ ] **Step 2: Verify test fails**

Expected: helper does not exist.

- [ ] **Step 3: Hide empty section and remove balances**

Only construct the “我的结算” section when related suggestions are nonempty. Remove `balanceResults` from `SettlementDetailView` and its call site; retain only the backend-provided settlement suggestions.

- [ ] **Step 4: Run settlement tests**

Expected: section visibility tests PASS and project compiles without the removed parameter.

### Task 8: Avatar upload and display

**Files:**
- Create: `Evenly/RemoteAvatarView.swift`
- Modify: `Evenly/SettingsView.swift`
- Modify: `Evenly/LedgerDrawerView.swift`
- Modify: `Evenly/AddMemberView.swift`
- Modify: `Evenly/AuthManager.swift`
- Modify: `../evenly-backend-service/app/routers/users.py`
- Test: `EvenlyTests/EvenlyTests.swift`
- Test: `../evenly-backend-service/tests/test_backend_rules.py`

- [ ] **Step 1: Write failing avatar state and backend error tests**

Assert a changed avatar URL updates the profile state. Mock COS upload failure in the backend and assert a stable 502 response with a safe detail message.

- [ ] **Step 2: Verify tests fail**

Expected: iOS display state has no remote-image path and COS exceptions are not normalized.

- [ ] **Step 3: Build shared remote avatar**

Implement `RemoteAvatarView(url:size:fallbackText:)` with `AsyncImage`, circular crop, progress state and initial fallback.

- [ ] **Step 4: Add local preview and square JPEG**

Store selected `UIImage` in `SettingsView`, center-crop to 512×512, show it immediately, upload, then clear it only after the new profile URL is published. Restore the previous remote avatar on failure.

- [ ] **Step 5: Normalize backend failures and add logs**

Wrap COS upload in `try/except`, log safe metadata, and raise HTTP 502 with `detail="Avatar storage upload failed"`.

- [ ] **Step 6: Run avatar tests**

Expected: iOS and backend avatar tests PASS.

### Task 9: Full verification

**Files:**
- Modify only files required by failures proven during this task.

- [ ] **Step 1: Run backend suite**

```bash
uv run pytest -v
```

Expected: all tests PASS.

- [ ] **Step 2: Run iOS unit tests**

```bash
xcodebuild test -project Evenly.xcodeproj -scheme Evenly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:EvenlyTests
```

Expected: all tests PASS.

- [ ] **Step 3: Run iOS UI tests**

```bash
xcodebuild test -project Evenly.xcodeproj -scheme Evenly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:EvenlyUITests
```

Expected: all UI tests PASS or external backend prerequisites are reported precisely.

- [ ] **Step 4: Build simulator app**

```bash
xcodebuild -project Evenly.xcodeproj -scheme Evenly -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Review worktree and report**

Confirm no unrelated files were reverted, summarize all changed files, test counts, remaining warnings, and any manual-device-only verification.
