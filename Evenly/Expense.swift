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
        updatedAt: Date? = nil
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
    }
}

enum ExpenseStatus: String, Codable {
    case pending
    case confirmed
    case rejected
}

// Create API request model
extension Expense {
    func toCreateRequest(payerId: String, ledgerId: UUID) -> ExpenseCreate {
        let splits = participants.map { participant in
            // If participant has a userId, use equal split
            let shareAmount = amount / Decimal(participants.count)
            return ExpenseSplitCreate(
                userId: participant.userId ?? "",
                amount: shareAmount
            )
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
