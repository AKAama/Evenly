//
//  LedgerStore.swift
//  Evenly
//
//  Data store for ledgers using Python backend
//

import Foundation
import Combine

final class LedgerStore: ObservableObject {
    @Published private(set) var ledgers: [Ledger] = []
    @Published var currentLedger: Ledger?
    @Published private(set) var isLoading = false
    /// True while the active ledger's overview (expenses/members/settlements) is loading.
    @Published private(set) var isLoadingCurrentDetail = false
    @Published var error: String?
    @Published private(set) var invitations: [LedgerInvitationResponse] = []

    private let api = APIClient.shared
    private var userId: String?
    private var pollingTimer: Timer?
    private let userDefaultsKey = "CurrentLedgerId"
    private var overviewInFlight: Set<UUID> = []
    private var lastOverviewFetchedAt: [UUID: Date] = [:]
    private var lastOverviewResponses: [UUID: LedgerOverviewResponse] = [:]

    /// Lightweight invitation poll interval while the app is foregrounded.
    /// Invites must surface without relaunch even when remote push is unavailable.
    private static let invitationPollInterval: TimeInterval = 5
    /// Soft-refresh debounce so scene-phase / onAppear / list reload don't triple-fetch.
    private static let overviewMinRefreshInterval: TimeInterval = 2.5

    // MARK: - Bind User

    func bind(userId: String) {
        let switchedUser = self.userId != userId
        if switchedUser {
            stop()
        }
        self.userId = userId

        print("=== LedgerStore.bind userId=\(userId) ===")

        // Paint from local cache immediately so the bill list isn't blank on cold start.
        if switchedUser || ledgers.isEmpty {
            restoreCachedLedgersIfNeeded()
        }

        // Always pull invites immediately — don't wait for the ledger list or the
        // first poll tick, otherwise a live invite never appears until relaunch.
        refreshInvitations()
        startInvitationPolling()
        fetchLedgers()
    }

    private func startInvitationPolling() {
        pollingTimer?.invalidate()
        // Schedule on the main run loop in common modes so scrolling doesn't pause polls.
        let timer = Timer(timeInterval: Self.invitationPollInterval, repeats: true) { [weak self] _ in
            self?.refreshInvitations()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        ledgers = []
        currentLedger = nil
        invitations = []
        isLoadingCurrentDetail = false
        overviewInFlight.removeAll()
        lastOverviewFetchedAt.removeAll()
        lastOverviewResponses.removeAll()
        userId = nil
    }

    // MARK: - Fetch Ledgers

    func fetchLedgers() {
        guard userId != nil else { return }

        Task {
            do {
                let responses: [LedgerResponse] = try await api.get(APIEndpoints.ledgers)

                let selectedId = await MainActor.run { () -> UUID? in
                    let previousById = Dictionary(uniqueKeysWithValues: self.ledgers.map { ($0.id, $0) })

                    // Keep previously loaded expenses/members while refreshing the shell list
                    // so the UI does not flash empty → filled on every foreground.
                    self.ledgers = responses.map { response in
                        var ledger = Ledger(from: response)
                        if let previous = UUID(uuidString: response.id).flatMap({ previousById[$0] }) {
                            if !previous.expenses.isEmpty {
                                ledger.expenses = previous.expenses
                                ledger.expenseCount = previous.expenses.count
                            }
                            if !previous.participants.isEmpty {
                                ledger.participants = previous.participants
                                ledger.members = previous.members
                                ledger.memberIds = previous.memberIds
                                ledger.memberCount = previous.participants.filter(\.isActive).count
                            }
                        }
                        return ledger
                    }
                    .sorted { $0.title < $1.title }

                    // Prefer last-used / current; only auto-enter when there is exactly one ledger.
                    // Multiple ledgers with no memory → leave selection empty so UI shows a picker.
                    let preferred = self.resolvePreferredLedger(from: self.ledgers, keeping: self.currentLedger?.id)

                    if let preferred {
                        let selectedId = preferred.id
                        if self.currentLedger?.id == selectedId, !(self.currentLedger?.expenses.isEmpty ?? true) {
                            var merged = preferred
                            merged.expenses = self.currentLedger?.expenses ?? preferred.expenses
                            merged.participants = self.currentLedger?.participants ?? preferred.participants
                            merged.members = self.currentLedger?.members ?? preferred.members
                            merged.memberIds = self.currentLedger?.memberIds ?? preferred.memberIds
                            merged.memberCount = merged.participants.filter(\.isActive).count
                            merged.expenseCount = merged.expenses.count
                            self.currentLedger = merged
                            if let idx = self.ledgers.firstIndex(where: { $0.id == selectedId }) {
                                self.ledgers[idx] = merged
                            }
                        } else {
                            self.currentLedger = preferred
                        }
                        UserDefaults.standard.set(preferred.id.uuidString, forKey: self.userDefaultsKey)
                        self.persistLedgersCache()
                        return selectedId
                    } else {
                        self.currentLedger = nil
                        self.persistLedgersCache()
                        return nil
                    }
                }

                // One overview call for the active ledger replaces N×(detail+expenses) hydrations.
                if let selectedId {
                    _ = try? await self.loadOverview(ledgerId: selectedId, force: false)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
            // Always refresh invites independently so a ledger-list failure cannot
            // hide pending invitations.
            await fetchInvitationsWithoutBlockingLedgers()
        }
    }

    /// Public refresh used by scene-phase, push callbacks, and polling.
    func refreshInvitations() {
        guard userId != nil else { return }
        Task { await fetchInvitationsWithoutBlockingLedgers() }
    }

    private func fetchInvitationsWithoutBlockingLedgers() async {
        do {
            let invitations: [LedgerInvitationResponse] = try await api.get(APIEndpoints.pendingInvitations)
            await MainActor.run { self.invitations = invitations }
        } catch {
            // Invitations are supplementary. A temporarily unavailable or
            // older backend must never hide the user's existing ledgers.
            print("Failed to fetch ledger invitations: \(error)")
        }
    }

    func respondToInvitation(_ invitation: LedgerInvitationResponse, accept: Bool) {
        Task {
            do {
                let _: EmptyResponse = try await api.post(
                    APIEndpoints.respondToInvitation(id: invitation.id, accept: accept)
                )
                await MainActor.run {
                    self.invitations.removeAll { $0.id == invitation.id }
                    if accept { self.fetchLedgers() }
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }

    func fetchLedgerDetails(ledgerId: UUID) {
        // Prefer the combined overview endpoint (members + expenses + settlements).
        Task { _ = try? await loadOverview(ledgerId: ledgerId, force: true) }
    }

    func fetchOverview(
        for ledger: Ledger,
        force: Bool = false,
        completion: @escaping (Result<LedgerOverviewResponse, Error>) -> Void
    ) {
        Task {
            do {
                if let response = try await loadOverview(ledgerId: ledger.id, force: force) {
                    await MainActor.run { completion(.success(response)) }
                } else if let cached = lastOverviewResponses[ledger.id] {
                    // Soft-skipped but we still have a recent overview for settlements UI.
                    await MainActor.run { completion(.success(cached)) }
                } else {
                    await MainActor.run { completion(.failure(URLError(.cancelled))) }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Loads ledger + members + expenses + settlements in a single request.
    /// Returns `nil` when a soft refresh is debounced or already in flight (caller may use cache).
    @discardableResult
    private func loadOverview(ledgerId: UUID, force: Bool) async throws -> LedgerOverviewResponse? {
        let (alreadyInFlight, hasLocalDetail, recentlyFetched) = await MainActor.run { () -> (Bool, Bool, Bool) in
            let inFlight = self.overviewInFlight.contains(ledgerId)
            let hasDetail = (self.currentLedger?.id == ledgerId && !(self.currentLedger?.expenses.isEmpty ?? true))
                || (self.ledgers.first(where: { $0.id == ledgerId })?.expenses.isEmpty == false)
            let recent: Bool
            if let last = self.lastOverviewFetchedAt[ledgerId] {
                recent = Date().timeIntervalSince(last) < Self.overviewMinRefreshInterval
            } else {
                recent = false
            }
            return (inFlight, hasDetail, recent)
        }

        if alreadyInFlight {
            // Wait briefly for the in-flight request so settlements can reuse its result.
            for _ in 0..<20 {
                try await Task.sleep(nanoseconds: 100_000_000)
                let done = await MainActor.run { !self.overviewInFlight.contains(ledgerId) }
                if done {
                    return lastOverviewResponses[ledgerId]
                }
            }
            return lastOverviewResponses[ledgerId]
        }
        if !force, recentlyFetched, hasLocalDetail {
            return lastOverviewResponses[ledgerId]
        }

        await MainActor.run {
            self.overviewInFlight.insert(ledgerId)
            // Only show the detail spinner when there is nothing useful on screen yet.
            if !hasLocalDetail {
                self.isLoadingCurrentDetail = true
            }
        }

        defer {
            Task { @MainActor in
                self.overviewInFlight.remove(ledgerId)
                if self.overviewInFlight.isEmpty {
                    self.isLoadingCurrentDetail = false
                }
            }
        }

        let response: LedgerOverviewResponse = try await api.get(
            APIEndpoints.ledgerOverview(id: ledgerId.uuidString)
        )
        var updatedLedger = Ledger(from: response.ledger)
        updatedLedger.expenses = response.expenses.map {
            Expense(from: $0, participants: updatedLedger.participants)
        }
        updatedLedger.memberCount = updatedLedger.participants.filter(\.isActive).count
        updatedLedger.expenseCount = updatedLedger.expenses.count

        await MainActor.run {
            if let index = self.ledgers.firstIndex(where: { $0.id == updatedLedger.id }) {
                self.ledgers[index] = updatedLedger
            } else {
                self.ledgers.append(updatedLedger)
                self.ledgers.sort { $0.title < $1.title }
            }
            if self.currentLedger?.id == updatedLedger.id || self.currentLedger == nil {
                self.currentLedger = updatedLedger
                UserDefaults.standard.set(updatedLedger.id.uuidString, forKey: self.userDefaultsKey)
            }
            self.lastOverviewFetchedAt[ledgerId] = Date()
            self.lastOverviewResponses[ledgerId] = response
            self.persistLedgersCache()
        }
        return response
    }

    // MARK: - Current Ledger

    func ledger(id: UUID) -> Ledger? {
        ledgers.first { $0.id == id }
    }

    func setCurrentLedger(_ ledger: Ledger) {
        currentLedger = ledger
        UserDefaults.standard.set(ledger.id.uuidString, forKey: userDefaultsKey)
        // Load detail for the newly selected ledger (single overview request).
        Task { _ = try? await loadOverview(ledgerId: ledger.id, force: ledger.expenses.isEmpty) }
    }

    func clearCurrentLedgerSelection() {
        currentLedger = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// Selection policy for landing:
    /// 1) keep the in-memory current ledger if it still exists
    /// 2) restore last-used id from disk if still a member
    /// 3) auto-open only when there is exactly one ledger
    /// 4) otherwise require an explicit pick (return nil)
    private func resolvePreferredLedger(from ledgers: [Ledger], keeping currentId: UUID?) -> Ledger? {
        if let currentId, let match = ledgers.first(where: { $0.id == currentId }) {
            return match
        }
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey).flatMap(UUID.init(uuidString:)),
           let match = ledgers.first(where: { $0.id == saved }) {
            return match
        }
        if ledgers.count == 1 {
            return ledgers[0]
        }
        return nil
    }

    private func restoreCachedLedgersIfNeeded() {
        let cached = DataPersistence.loadLedgers()
        guard !cached.isEmpty else { return }
        ledgers = cached.sorted { $0.title < $1.title }
        currentLedger = resolvePreferredLedger(from: ledgers, keeping: currentLedger?.id)
    }

    private func persistLedgersCache() {
        DataPersistence.saveLedgers(ledgers)
    }

    func applyUpdatedLedger(_ ledger: Ledger) {
        var ledger = ledger
        ledger.memberCount = ledger.participants.count
        if let existing = ledgers.first(where: { $0.id == ledger.id }), ledger.expenses.isEmpty {
            ledger.expenses = existing.expenses
            ledger.expenseCount = existing.expenseCount
        } else {
            ledger.expenseCount = ledger.expenses.count
        }

        if let index = ledgers.firstIndex(where: { $0.id == ledger.id }) {
            ledgers[index] = ledger
        } else {
            ledgers.append(ledger)
        }

        if currentLedger?.id == ledger.id {
            currentLedger = ledger
        }
    }

    // MARK: - Ledger Operations

    func createLedger(_ ledger: Ledger, completion: @escaping (Result<Ledger, Error>) -> Void) {
        guard userId != nil else {
            completion(.failure(NSError(domain: "LedgerStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])))
            return
        }

        // 检查是否存在同名账本
        if ledgers.contains(where: { $0.title.lowercased() == ledger.title.lowercased() }) {
            completion(.failure(NSError(domain: "LedgerStore", code: -2, userInfo: [NSLocalizedDescriptionKey: "已存在同名账本"])))
            return
        }

        isLoading = true

        Task {
            do {
                // Convert participants to MemberCreate array
                let members = ledger.participants.map { participant -> MemberCreate in
                    if participant.isTemporary {
                        return MemberCreate(
                            userId: nil,
                            nickname: participant.name,
                            isTemporary: true,
                            temporaryName: participant.name
                        )
                    } else {
                        return MemberCreate(
                            userId: participant.userId,
                            nickname: participant.name,
                            isTemporary: false,
                            temporaryName: nil
                        )
                    }
                }

                let createRequest = LedgerCreate(
                    name: ledger.title,
                    currency: nil,
                    members: members
                )

                let response: LedgerWithMembers = try await api.post(APIEndpoints.ledgers, body: createRequest)

                let newLedger = Ledger(from: response)
                await MainActor.run {
                    self.ledgers.append(newLedger)
                    self.currentLedger = newLedger
                    UserDefaults.standard.set(newLedger.id.uuidString, forKey: self.userDefaultsKey)
                    self.isLoading = false
                }
                completion(.success(newLedger))

            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
                completion(.failure(error))
            }
        }
    }

    func deleteLedger(_ ledger: Ledger, completion: @escaping (Error?) -> Void = { _ in }) {
        Task {
            do {
                try await api.delete(APIEndpoints.ledger(id: ledger.id.uuidString))

                await MainActor.run {
                    self.ledgers.removeAll { $0.id == ledger.id }
                    if self.currentLedger?.id == ledger.id {
                        self.currentLedger = self.ledgers.first
                    }
                }
                completion(nil)

            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
                completion(error)
            }
        }
    }

    // MARK: - QR / Universal Link invites

    func fetchInviteLink(ledgerId: UUID) async throws -> LedgerInviteLinkResponse {
        try await api.get(APIEndpoints.inviteLink(ledgerId: ledgerId.uuidString))
    }

    func rotateInviteLink(ledgerId: UUID) async throws -> LedgerInviteLinkResponse {
        try await api.post(APIEndpoints.rotateInviteLink(ledgerId: ledgerId.uuidString))
    }

    /// Join a ledger via share/QR token, then select it as current.
    func joinViaInviteToken(_ token: String) async throws -> JoinLedgerResponse {
        let response: JoinLedgerResponse = try await api.post(APIEndpoints.joinInviteLink(token: token))
        guard let id = UUID(uuidString: response.ledgerId) else { return response }

        // Pin preferred ledger before list refresh so resolvePreferredLedger picks it up.
        await MainActor.run {
            UserDefaults.standard.set(response.ledgerId, forKey: self.userDefaultsKey)
        }

        // Refresh membership list then force-load overview for the joined ledger.
        do {
            let responses: [LedgerResponse] = try await api.get(APIEndpoints.ledgers)
            await MainActor.run {
                let previousById = Dictionary(uniqueKeysWithValues: self.ledgers.map { ($0.id, $0) })
                self.ledgers = responses.map { item in
                    var ledger = Ledger(from: item)
                    if let previous = UUID(uuidString: item.id).flatMap({ previousById[$0] }) {
                        if !previous.expenses.isEmpty {
                            ledger.expenses = previous.expenses
                            ledger.expenseCount = previous.expenses.count
                        }
                        if !previous.participants.isEmpty {
                            ledger.participants = previous.participants
                            ledger.members = previous.members
                            ledger.memberIds = previous.memberIds
                            ledger.memberCount = previous.participants.filter(\.isActive).count
                        }
                    }
                    return ledger
                }
                .sorted { $0.title < $1.title }

                if let joined = self.ledgers.first(where: { $0.id == id }) {
                    self.currentLedger = joined
                }
                self.persistLedgersCache()
            }
            _ = try? await loadOverview(ledgerId: id, force: true)
        } catch {
            // Join already succeeded; surface list error separately if needed.
            await MainActor.run { self.error = error.localizedDescription }
        }
        return response
    }

    // MARK: - Member Management

    func addMember(
        userId: String,
        nickname: String?,
        to ledger: Ledger,
        completion: @escaping (Result<Ledger, Error>) -> Void
    ) {
        Task {
            do {
                let addRequest = AddMemberRequest(
                    userId: userId,
                    nickname: nickname,
                    isTemporary: false,
                    temporaryName: nil
                )
                let _: MemberResponse = try await api.post(
                    APIEndpoints.addMember(ledgerId: ledger.id.uuidString),
                    body: addRequest
                )
                let response: LedgerWithMembers = try await api.get(
                    APIEndpoints.ledger(id: ledger.id.uuidString)
                )
                let updatedLedger = Ledger(from: response)

                await MainActor.run {
                    self.applyUpdatedLedger(updatedLedger)
                    completion(.success(updatedLedger))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    func addMember(byEmail email: String, to ledger: Ledger, completion: @escaping (Result<Ledger, Error>) -> Void) {
        // First, search for the user by email
        Task {
            do {
                let users: [UserResponse] = try await api.get(APIEndpoints.searchUsers(q: email))

                guard let user = users.first(where: { $0.email.lowercased() == email.lowercased() }) else {
                    await MainActor.run {
                        completion(.failure(NSError(domain: "LedgerStore", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "未找到该邮箱的用户"])))
                    }
                    return
                }

                self.addMember(userId: user.id, nickname: user.displayName, to: ledger, completion: completion)

            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    func removeMember(_ memberId: String, from ledger: Ledger, completion: @escaping (Result<Ledger, Error>) -> Void) {
        Task {
            do {
                try await api.delete(APIEndpoints.removeMember(ledgerId: ledger.id.uuidString, userId: memberId))

                // Fetch updated ledger
                let response: LedgerWithMembers = try await api.get(APIEndpoints.ledger(id: ledger.id.uuidString))
                let updatedLedger = Ledger(from: response)

                await MainActor.run {
                    if let index = self.ledgers.firstIndex(where: { $0.id == ledger.id }) {
                        self.ledgers[index] = updatedLedger
                    }
                    if self.currentLedger?.id == ledger.id {
                        self.currentLedger = updatedLedger
                    }
                    completion(.success(updatedLedger))
                }

            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    func leaveLedger(_ ledger: Ledger, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await api.delete(APIEndpoints.leaveLedger(ledgerId: ledger.id.uuidString))

                await MainActor.run {
                    self.ledgers.removeAll { $0.id == ledger.id }
                    if self.currentLedger?.id == ledger.id {
                        self.currentLedger = self.ledgers.first
                        if let currentLedger {
                            UserDefaults.standard.set(currentLedger.id.uuidString, forKey: self.userDefaultsKey)
                            self.fetchLedgerDetails(ledgerId: currentLedger.id)
                        } else {
                            UserDefaults.standard.removeObject(forKey: self.userDefaultsKey)
                        }
                    }
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Expense Operations

    private func fetchExpenses(for ledger: Ledger) {
        guard let currentLedger = currentLedger, currentLedger.id == ledger.id else { return }

        Task {
            do {
                let responses: [ExpenseWithDetails] = try await api.get(APIEndpoints.expenses(ledgerId: ledger.id.uuidString))

                await MainActor.run {
                    let expenses = responses.map { Expense(from: $0, participants: currentLedger.participants) }
                    if var updatedLedger = self.currentLedger {
                        updatedLedger.expenses = expenses
                        updatedLedger.expenseCount = expenses.count
                        self.currentLedger = updatedLedger

                        if let index = self.ledgers.firstIndex(where: { $0.id == ledger.id }) {
                            self.ledgers[index] = updatedLedger
                        }
                    }
                }
            } catch {
                print("Failed to fetch expenses: \(error)")
            }
        }
    }

    func addExpense(_ expense: Expense, to ledger: Ledger, completion: @escaping (Result<Expense, Error>) -> Void) {
        guard userId != nil else {
            completion(.failure(NSError(domain: "LedgerStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])))
            return
        }

        guard let payerId = ledger.registeredUserId(for: expense.payer) else {
            // Diagnostic: this guard should be unreachable for a payer picked
            // from registeredParticipants. If it fires, log the payer + ledger
            // member state so we can tell a real bug from a stale build.
            let payer = expense.payer
            let memberDump = ledger.members?.map { "(id=\($0.id),userId=\($0.userId ?? "nil"),isTemporary=\($0.isTemporary))" }
                .joined(separator: ", ") ?? "members=nil"
            print("[AddExpense] payer guard failed: payer(id=\(payer.id.uuidString),userId=\(payer.userId ?? "nil"),isTemporary=\(payer.isTemporary)); ledger.members=[\(memberDump)]; participants.userIds=\(ledger.participants.map { $0.userId ?? "nil" })")
            completion(.failure(NSError(domain: "LedgerStore", code: -2, userInfo: [NSLocalizedDescriptionKey: "付款人必须是已注册成员"])))
            return
        }

        Task {
            do {
                let request = expense.toCreateRequest(payerId: payerId, ledgerId: ledger.id)
                let response: ExpenseResponse = try await api.post(APIEndpoints.expenses(ledgerId: ledger.id.uuidString), body: request)

                var newExpense = Expense(from: response, participants: expense.participants)
                // Prefer server values; keep local category/icon if an older API omits them.
                if newExpense.icon == nil { newExpense.icon = expense.icon }
                if newExpense.category == nil { newExpense.category = expense.category }

                await MainActor.run {
                    if var updatedLedger = self.currentLedger {
                        updatedLedger.expenses.append(newExpense)
                        updatedLedger.expenseCount = updatedLedger.expenses.count
                        self.currentLedger = updatedLedger

                        if let index = self.ledgers.firstIndex(where: { $0.id == ledger.id }) {
                            self.ledgers[index] = updatedLedger
                        }
                    }
                    completion(.success(newExpense))
                }

            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Record a partial refund against an expense (creator or payer).
    func setRefund(
        for expense: Expense,
        amount: Decimal,
        note: String? = nil,
        in ledger: Ledger,
        completion: @escaping (Result<Expense, Error>) -> Void
    ) {
        guard userId != nil else {
            completion(.failure(NSError(domain: "LedgerStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])))
            return
        }
        Task {
            do {
                let body = ExpenseRefundRequest(refundAmount: amount, note: note)
                let response: ExpenseResponse = try await api.patch(
                    APIEndpoints.expenseRefund(expenseId: expense.id.uuidString),
                    body: body
                )
                var updated = Expense(from: response, participants: expense.participants)
                if updated.icon == nil { updated.icon = expense.icon }
                if updated.category == nil { updated.category = expense.category }
                updated.confirmations = expense.confirmations
                await MainActor.run {
                    self.replaceExpense(updated, in: ledger.id)
                    completion(.success(updated))
                }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    /// Update a pending expense (creator only on server). Replaces local row.
    func updateExpense(_ expense: Expense, in ledger: Ledger, completion: @escaping (Result<Expense, Error>) -> Void) {
        guard userId != nil else {
            completion(.failure(NSError(domain: "LedgerStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])))
            return
        }
        guard let payerId = ledger.registeredUserId(for: expense.payer) else {
            completion(.failure(NSError(domain: "LedgerStore", code: -2, userInfo: [NSLocalizedDescriptionKey: "付款人必须是已注册成员"])))
            return
        }

        Task {
            do {
                let request = expense.toUpdateRequest(payerId: payerId)
                let response: ExpenseResponse = try await api.put(
                    APIEndpoints.updateExpense(expenseId: expense.id.uuidString),
                    body: request
                )
                // Prefer participants from the edit form; hydrate status/confirmations from server.
                var updated = Expense(from: response, participants: expense.participants)
                if updated.icon == nil { updated.icon = expense.icon }
                if updated.category == nil { updated.category = expense.category }
                // Mirror auto-confirm for creator/payer until next overview refresh.
                updated.confirmations[response.createdBy] = .confirmed
                if let payerUserId = expense.payer.userId {
                    updated.confirmations[payerUserId] = .confirmed
                }

                await MainActor.run {
                    self.replaceExpense(updated, in: ledger.id)
                    completion(.success(updated))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    private func replaceExpense(_ expense: Expense, in ledgerId: UUID) {
        if var updatedLedger = currentLedger, updatedLedger.id == ledgerId {
            if let idx = updatedLedger.expenses.firstIndex(where: { $0.id == expense.id }) {
                updatedLedger.expenses[idx] = expense
            }
            currentLedger = updatedLedger
            if let index = ledgers.firstIndex(where: { $0.id == ledgerId }) {
                ledgers[index] = updatedLedger
            }
        } else if let index = ledgers.firstIndex(where: { $0.id == ledgerId }) {
            var updatedLedger = ledgers[index]
            if let idx = updatedLedger.expenses.firstIndex(where: { $0.id == expense.id }) {
                updatedLedger.expenses[idx] = expense
            }
            ledgers[index] = updatedLedger
        }
    }

    func deleteExpense(_ expense: Expense, from ledger: Ledger, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await api.delete(APIEndpoints.deleteExpense(expenseId: expense.id.uuidString))

                await MainActor.run {
                    if var updatedLedger = self.currentLedger {
                        updatedLedger.expenses.removeAll { $0.id == expense.id }
                        updatedLedger.expenseCount = updatedLedger.expenses.count
                        self.currentLedger = updatedLedger

                        if let index = self.ledgers.firstIndex(where: { $0.id == ledger.id }) {
                            self.ledgers[index] = updatedLedger
                        }
                    }
                    completion(.success(()))
                }

            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    func respondToExpense(_ expense: Expense, status: ConfirmationStatus, in ledger: Ledger, completion: @escaping (Result<Void, Error>) -> Void) {
        guard status == .confirmed || status == .rejected else {
            completion(.failure(NSError(domain: "LedgerStore", code: -3, userInfo: [NSLocalizedDescriptionKey: "无效的确认状态"])))
            return
        }

        Task {
            do {
                let request = ConfirmExpenseRequest(status: status.rawValue)
                let response: ExpenseResponse = try await api.post(
                    APIEndpoints.confirmExpense(expenseId: expense.id.uuidString),
                    body: request
                )

                await MainActor.run {
                    if var updatedLedger = self.ledgers.first(where: { $0.id == ledger.id }),
                       let expenseIndex = updatedLedger.expenses.firstIndex(where: { $0.id == expense.id }) {
                        updatedLedger.expenses[expenseIndex].status = ExpenseStatus(rawValue: response.status) ?? updatedLedger.expenses[expenseIndex].status
                        if let userId = self.userId {
                            updatedLedger.expenses[expenseIndex].confirmations[userId] = status
                        }

                        if let ledgerIndex = self.ledgers.firstIndex(where: { $0.id == ledger.id }) {
                            self.ledgers[ledgerIndex] = updatedLedger
                        }
                        if self.currentLedger?.id == ledger.id {
                            self.currentLedger = updatedLedger
                        }
                    }
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Member Names

    func fetchMemberNames(ids: [String], completion: @escaping ([String: String]) -> Void) {
        var names: [String: String] = [:]

        // Use current ledger's members if available
        if let members = currentLedger?.members {
            for member in members {
                if let user = member.user {
                    names[member.userId ?? UUID().uuidString] = user.displayName ?? user.email.components(separatedBy: "@").first ?? "用户"
                }
            }
        }

        completion(names)
    }
}
