//
//  Expense.swift
//  Evenly
//
//  Expense data model
//

import Foundation

struct Expense: Identifiable, Codable {
    let id: UUID
    var title: String
    var amount: Decimal
    var payer: Person
    var participants: [Person]
    var status: ExpenseStatus
    var note: String?
    var expenseDate: Date?
    var createdAt: Date?
    var updatedAt: Date?
    /// 成员确认状态: userId -> ConfirmationStatus
    var confirmations: [String: ConfirmationStatus]

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        payer: Person,
        participants: [Person],
        status: ExpenseStatus = .pending,
        note: String? = nil,
        expenseDate: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        confirmations: [String: ConfirmationStatus] = [:]
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.payer = payer
        self.participants = participants
        self.status = status
        self.note = note
        self.expenseDate = expenseDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.confirmations = confirmations
    }

    // Create from ExpenseWithDetails
    init(from response: ExpenseWithDetails, participants: [Person]) {
        self.id = UUID(uuidString: response.id) ?? UUID()
        self.title = response.title
        self.amount = response.totalAmount
        self.payer = participants.first { $0.userId == response.payerId } ?? Person(name: response.payer.displayName ?? "Unknown", userId: response.payerId)
        self.participants = participants
        self.status = ExpenseStatus(rawValue: response.status) ?? .pending
        self.note = response.note
        self.expenseDate = response.expenseDate
        self.createdAt = response.createdAt
        self.updatedAt = response.updatedAt
        
        // Parse confirmations from response
        var confirmations: [String: ConfirmationStatus] = [:]
        for confirmation in response.confirmations {
            confirmations[confirmation.userId] = ConfirmationStatus(rawValue: confirmation.status) ?? .pending
        }
        self.confirmations = confirmations
    }

    // Create from ExpenseResponse
    init(from response: ExpenseResponse, participants: [Person]) {
        self.id = UUID(uuidString: response.id) ?? UUID()
        self.title = response.title
        self.amount = response.totalAmount
        self.payer = participants.first { $0.userId == response.payerId } ?? Person(name: "Unknown", userId: response.payerId)
        self.participants = participants
        self.status = ExpenseStatus(rawValue: response.status) ?? .pending
        self.note = response.note
        self.expenseDate = response.expenseDate
        self.createdAt = response.createdAt
        self.updatedAt = response.updatedAt
        self.confirmations = [:]
    }
    
    /// 获取特定成员的确认状态
    func confirmationStatus(for person: Person) -> ConfirmationStatus {
        guard let userId = person.userId else { return .pending }
        return confirmations[userId] ?? .pending
    }
}

enum ConfirmationStatus: String, Codable {
    case pending
    case confirmed
    case rejected
}

enum ExpenseStatus: String, Codable {
    case pending
    case confirmed
    case rejected
}

// Create API request model
extension Expense {
    func toCreateRequest(payerId: String, ledgerId: UUID) -> ExpenseCreate {
        let registeredParticipants = participants.filter { ($0.userId?.isEmpty == false) }
        let cents = NSDecimalNumber(decimal: amount * 100).rounding(accordingToBehavior: nil).intValue
        let baseCents = cents / max(registeredParticipants.count, 1)
        let remainder = cents % max(registeredParticipants.count, 1)

        let splits = registeredParticipants.enumerated().compactMap { index, participant -> ExpenseSplitCreate? in
            guard let userId = participant.userId else { return nil }
            let participantCents = baseCents + (index < remainder ? 1 : 0)
            let shareAmount = Decimal(participantCents) / 100
            return ExpenseSplitCreate(userId: userId, amount: shareAmount)
        }

        return ExpenseCreate(
            title: title,
            totalAmount: amount,
            payerId: payerId,
            splits: splits,
            note: note,
            expenseDate: expenseDate
        )
    }
}
