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
    @Published var error: String?

    private let api = APIClient.shared
    private var userId: String?
    private var pollingTimer: Timer?
    private let userDefaultsKey = "CurrentLedgerId"

    // MARK: - Bind User

    func bind(userId: String) {
        // If same user already bound, skip
        if self.userId == userId && !ledgers.isEmpty {
            print("LedgerStore.bind: Same user, skipping bind")
            return
        }

        // If different user, clear first
        if self.userId != userId {
            stop()
            self.userId = userId
        }

        print("=== LedgerStore.bind ===")
        print("userId: \(userId)")

        // Start polling for ledgers
        fetchLedgers()

        // Keep data stable while users are editing forms. Mutations refresh their own data.
        startPolling()
    }

    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        ledgers = []
        currentLedger = nil
    }

    // MARK: - Fetch Ledgers

    func fetchLedgers() {
        guard userId != nil else { return }

        Task {
            do {
                let responses: [LedgerResponse] = try await api.get(APIEndpoints.ledgers)

                await MainActor.run {
                    self.ledgers = responses.map { Ledger(from: $0) }.sorted { $0.title < $1.title }

                    let selectedId = self.currentLedger?.id
                        ?? UserDefaults.standard.string(forKey: self.userDefaultsKey).flatMap(UUID.init(uuidString:))
                        ?? self.ledgers.first?.id

                    if let selectedId,
                       let ledger = self.ledgers.first(where: { $0.id == selectedId }) {
                        self.currentLedger = ledger
                        UserDefaults.standard.set(ledger.id.uuidString, forKey: self.userDefaultsKey)
                        self.fetchLedgerDetails(ledgerId: ledger.id)
                    } else {
                        self.currentLedger = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func fetchAllLedgerDetails() {
        for (index, ledger) in ledgers.enumerated() {
            Task {
                do {
                    let response: LedgerWithMembers = try await api.get(APIEndpoints.ledger(id: ledger.id.uuidString))

                    await MainActor.run {
                        let updatedLedger = Ledger(from: response)
                        self.ledgers[index] = updatedLedger

                        // Update current ledger if it matches
                        if self.currentLedger?.id == updatedLedger.id {
                            self.currentLedger = updatedLedger
                        }
                    }
                } catch {
                    print("Failed to fetch ledger details: \(error)")
                }
            }
        }
    }

    func fetchLedgerDetails(ledgerId: UUID) {
        Task {
            do {
                let response: LedgerWithMembers = try await api.get(APIEndpoints.ledger(id: ledgerId.uuidString))
                let updatedLedger = Ledger(from: response)

                await MainActor.run {
                    if let index = self.ledgers.firstIndex(where: { $0.id == ledgerId }) {
                        var merged = updatedLedger
                        if self.currentLedger?.id == ledgerId {
                            merged.expenses = self.currentLedger?.expenses ?? []
                        } else {
                            merged.expenses = self.ledgers[index].expenses
                        }
                        self.ledgers[index] = merged
                        self.currentLedger = merged
                        self.fetchExpenses(for: merged)
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Current Ledger

    func setCurrentLedger(_ ledger: Ledger) {
        currentLedger = ledger
        UserDefaults.standard.set(ledger.id.uuidString, forKey: userDefaultsKey)
        fetchLedgerDetails(ledgerId: ledger.id)
    }

    func applyUpdatedLedger(_ ledger: Ledger) {
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

    func createLedger(_ ledger: Ledger, completion: @escaping (Error?) -> Void) {
        guard userId != nil else {
            completion(NSError(domain: "LedgerStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"]))
            return
        }

        // 检查是否存在同名账本
        if ledgers.contains(where: { $0.title.lowercased() == ledger.title.lowercased() }) {
            completion(NSError(domain: "LedgerStore", code: -2, userInfo: [NSLocalizedDescriptionKey: "已存在同名账本"]))
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

                await MainActor.run {
                    let newLedger = Ledger(from: response)
                    self.ledgers.append(newLedger)
                    self.currentLedger = newLedger
                    UserDefaults.standard.set(newLedger.id.uuidString, forKey: self.userDefaultsKey)
                    self.isLoading = false
                }
                completion(nil)

            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
                completion(error)
            }
        }
    }

    func updateLedger(_ ledger: Ledger, completion: @escaping (Error?) -> Void = { _ in }) {
        // The backend doesn't have an update endpoint, so we skip this
        completion(nil)
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

    // MARK: - Member Management

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

                // Add member to ledger
                let addRequest = AddMemberRequest(userId: user.id, nickname: user.displayName, isTemporary: false, temporaryName: nil)
                let _: MemberResponse = try await api.post(APIEndpoints.addMember(ledgerId: ledger.id.uuidString), body: addRequest)

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

        guard let payerId = expense.payer.userId, !payerId.isEmpty else {
            completion(.failure(NSError(domain: "LedgerStore", code: -2, userInfo: [NSLocalizedDescriptionKey: "付款人必须是已注册成员"])))
            return
        }

        Task {
            do {
                let request = expense.toCreateRequest(payerId: payerId, ledgerId: ledger.id)
                let response: ExpenseResponse = try await api.post(APIEndpoints.expenses(ledgerId: ledger.id.uuidString), body: request)

                let newExpense = Expense(from: response, participants: expense.participants)

                await MainActor.run {
                    if var updatedLedger = self.currentLedger {
                        updatedLedger.expenses.append(newExpense)
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

    func deleteExpense(_ expense: Expense, from ledger: Ledger, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await api.delete(APIEndpoints.deleteExpense(expenseId: expense.id.uuidString))

                await MainActor.run {
                    if var updatedLedger = self.currentLedger {
                        updatedLedger.expenses.removeAll { $0.id == expense.id }
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

    // MARK: - Settlement Operations

    func fetchSettlements(for ledger: Ledger, completion: @escaping (Result<[Settlement], Error>) -> Void) {
        Task {
            do {
                let responses: [SettlementInstruction] = try await api.get(APIEndpoints.settlements(ledgerId: ledger.id.uuidString))

                await MainActor.run {
                    let settlements = responses.map { Settlement(from: $0) }
                    completion(.success(settlements))
                }

            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    func createSettlement(from fromUserId: String, to toUserId: String, amount: Decimal, for ledger: Ledger, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let request = SettlementCreate(
                    fromUserId: fromUserId,
                    toUserId: toUserId,
                    amount: amount,
                    note: nil
                )
                let _: SettlementResponse = try await api.post(APIEndpoints.settlements(ledgerId: ledger.id.uuidString), body: request)

                await MainActor.run {
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
