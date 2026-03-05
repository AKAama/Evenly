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

        // Set up polling
        startPolling()
    }

    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchLedgers()
        }
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

                    // Restore current ledger
                    if let savedId = UserDefaults.standard.string(forKey: self.userDefaultsKey),
                       let uuid = UUID(uuidString: savedId),
                       let ledger = self.ledgers.first(where: { $0.id == uuid }) {
                        self.currentLedger = ledger
                        print("Restored current ledger: \(ledger.title)")
                    } else if let first = self.ledgers.first {
                        self.currentLedger = first
                        print("Set first ledger as current: \(first.title)")
                    }

                    // Fetch full details for each ledger to get members
                    self.fetchLedgerDetails()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func fetchLedgerDetails() {
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

    // MARK: - Current Ledger

    func setCurrentLedger(_ ledger: Ledger) {
        currentLedger = ledger
        UserDefaults.standard.set(ledger.id.uuidString, forKey: userDefaultsKey)

        // Fetch expenses for current ledger
        fetchExpenses(for: ledger)
    }

    // MARK: - Ledger Operations

    func createLedger(_ ledger: Ledger, completion: @escaping (Error?) -> Void) {
        guard let userId = userId else {
            completion(NSError(domain: "LedgerStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"]))
            return
        }

        isLoading = true

        Task {
            do {
                let createRequest = LedgerCreate(
                    name: ledger.title,
                    currency: nil
                )

                let response: LedgerResponse = try await api.post(APIEndpoints.ledgers, body: createRequest)

                await MainActor.run {
                    let newLedger = Ledger(from: response)
                    self.ledgers.append(newLedger)
                    self.currentLedger = newLedger
                    self.isLoading = false
                    self.fetchLedgerDetails()
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
                let addRequest = AddMemberRequest(userId: user.id, nickname: user.displayName)
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
        guard let userId = userId else {
            completion(.failure(NSError(domain: "LedgerStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])))
            return
        }

        Task {
            do {
                let request = expense.toCreateRequest(payerId: userId, ledgerId: ledger.id)
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
                    names[member.userId] = user.displayName ?? user.email.components(separatedBy: "@").first ?? "用户"
                }
            }
        }

        completion(names)
    }
}
