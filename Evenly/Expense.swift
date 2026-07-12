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
    /// Original billed amount (before any refund).
    var amount: Decimal
    /// Partial refund (e.g. hotel returned ¥100). Net spend = amount - refundAmount.
    var refundAmount: Decimal
    var payer: Person
    var participants: [Person]
    var status: ExpenseStatus
    var note: String?
    var category: String?
    var icon: ExpenseIcon?
    var expenseDate: Date?
    var createdAt: Date?
    var updatedAt: Date?
    let createdBy: String?
    /// 成员确认状态: userId -> ConfirmationStatus
    var confirmations: [String: ConfirmationStatus]

    /// Effective spend after refunds — used for totals and settlement display.
    var netAmount: Decimal { max(amount - refundAmount, 0) }

    var hasRefund: Bool { refundAmount > 0 }

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        refundAmount: Decimal = 0,
        payer: Person,
        participants: [Person],
        status: ExpenseStatus = .pending,
        note: String? = nil,
        category: String? = nil,
        icon: ExpenseIcon? = nil,
        expenseDate: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        createdBy: String? = nil,
        confirmations: [String: ConfirmationStatus] = [:]
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.refundAmount = refundAmount
        self.payer = payer
        self.participants = participants
        self.status = status
        self.note = note
        self.category = category
        self.icon = icon
        self.expenseDate = expenseDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.confirmations = confirmations
    }

    // Create from ExpenseWithDetails
    init(from response: ExpenseWithDetails, participants: [Person]) {
        self.id = UUID(uuidString: response.id) ?? UUID()
        self.title = response.title
        self.amount = response.totalAmount
        self.refundAmount = response.refundAmount ?? 0
        self.payer = participants.first { $0.userId == response.payerId } ?? Person(name: response.payer.displayName ?? "Unknown", userId: response.payerId)
        let splitUserIds = Set(response.splits.compactMap(\.userId))
        // Compare member ids as UUIDs: the backend serializes them as lowercase
        // strings, but `Person.id.uuidString` is uppercase, so a string
        // comparison silently drops participants (notably temporary ones, which
        // have no user_id fallback) whose ids contain hex letters.
        let splitMemberIds: Set<UUID> = Set(response.splits.compactMap { split -> UUID? in
            split.memberId.flatMap(UUID.init(uuidString:))
        })
        self.participants = participants.filter { person in
            splitMemberIds.contains(person.id)
                || person.userId.map(splitUserIds.contains) == true
        }
        self.status = ExpenseStatus(rawValue: response.status) ?? .pending
        self.note = response.note
        self.category = response.category
        self.icon = response.iconType.flatMap(ExpenseIconType.init(rawValue:)).flatMap { type in
            response.iconValue.map { ExpenseIcon(type: type, value: $0) }
        }
        self.expenseDate = response.expenseDate
        self.createdAt = response.createdAt
        self.updatedAt = response.updatedAt
        self.createdBy = response.createdBy

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
        self.refundAmount = response.refundAmount ?? 0
        self.payer = participants.first { $0.userId == response.payerId } ?? Person(name: "Unknown", userId: response.payerId)
        self.participants = participants
        self.status = ExpenseStatus(rawValue: response.status) ?? .pending
        self.note = response.note
        self.category = response.category
        self.icon = response.iconType.flatMap(ExpenseIconType.init(rawValue:)).flatMap { type in
            response.iconValue.map { ExpenseIcon(type: type, value: $0) }
        }
        self.expenseDate = response.expenseDate
        self.createdAt = response.createdAt
        self.updatedAt = response.updatedAt
        self.createdBy = response.createdBy
        // The backend treats creation as the creator's confirmation. Mirror
        // that state immediately instead of waiting for the next full refresh.
        self.confirmations = participants.contains { $0.userId == response.createdBy }
            ? [response.createdBy: .confirmed]
            : [:]
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
        let cents = NSDecimalNumber(decimal: amount * 100).rounding(accordingToBehavior: nil).intValue
        let baseCents = cents / max(participants.count, 1)
        let remainder = cents % max(participants.count, 1)

        let splits = participants.enumerated().map { index, participant in
            let participantCents = baseCents + (index < remainder ? 1 : 0)
            let shareAmount = Decimal(participantCents) / 100
            return ExpenseSplitCreate(
                userId: participant.userId,
                memberId: participant.id.uuidString,
                amount: shareAmount
            )
        }

        return ExpenseCreate(
            title: title,
            totalAmount: amount,
            payerId: payerId,
            splits: splits,
            note: note,
            expenseDate: Self.requestDateFormatter.string(from: expenseDate ?? Date()),
            category: category,
            iconType: icon?.type.rawValue,
            iconValue: icon?.value
        )
    }

    /// Same payload shape as create — backend treats PUT as full replace.
    func toUpdateRequest(payerId: String) -> ExpenseCreate {
        toCreateRequest(payerId: payerId, ledgerId: UUID())
    }

    private static let requestDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
