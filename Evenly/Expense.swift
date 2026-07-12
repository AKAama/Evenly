//
//  Expense.swift
//  Evenly
//
//  Expense data model
//

import Foundation

enum ExpenseKind: String, Codable, CaseIterable {
    case expense
    case income

    var isIncome: Bool { self == .income }

    var displayName: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        }
    }
}

struct Expense: Identifiable, Codable {
    let id: UUID
    var title: String
    var amount: Decimal
    var kind: ExpenseKind
    /// Links cost+income (or multi-part) rows that UI shows as one bill.
    var groupId: UUID?
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

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        kind: ExpenseKind = .expense,
        groupId: UUID? = nil,
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
        self.kind = kind
        self.groupId = groupId
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
        self.kind = ExpenseKind(rawValue: response.kind ?? "expense") ?? .expense
        self.groupId = response.groupId.flatMap(UUID.init(uuidString:))
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
        self.kind = ExpenseKind(rawValue: response.kind ?? "expense") ?? .expense
        self.groupId = response.groupId.flatMap(UUID.init(uuidString:))
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

    /// Group cost+income rows for list UI (same group_id, order: expense then income).
    static func listItems(from expenses: [Expense]) -> [ExpenseListItem] {
        var seenGroups = Set<UUID>()
        var items: [ExpenseListItem] = []
        // Preserve chronological order of first appearance.
        for expense in expenses {
            if let gid = expense.groupId {
                if seenGroups.contains(gid) { continue }
                seenGroups.insert(gid)
                let peers = expenses.filter { $0.groupId == gid }
                    .sorted { lhs, rhs in
                        if lhs.kind != rhs.kind { return lhs.kind == .expense }
                        return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
                    }
                if peers.count >= 2 {
                    items.append(.group(id: gid, expenses: peers))
                } else if let only = peers.first {
                    items.append(.single(only))
                }
            } else {
                items.append(.single(expense))
            }
        }
        return items
    }

    /// 获取特定成员的确认状态
    func confirmationStatus(for person: Person) -> ConfirmationStatus {
        guard let userId = person.userId else { return .pending }
        return confirmations[userId] ?? .pending
    }
}

enum ExpenseListItem: Identifiable {
    case single(Expense)
    case group(id: UUID, expenses: [Expense])

    var id: String {
        switch self {
        case .single(let e): return e.id.uuidString
        case .group(let id, _): return "group-\(id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .single(let e): return e.title
        case .group(_, let expenses): return expenses.first?.title ?? "组合账单"
        }
    }

    var representative: Expense {
        switch self {
        case .single(let e): return e
        case .group(_, let expenses):
            return expenses.first(where: { $0.kind == .expense }) ?? expenses[0]
        }
    }

    var allExpenses: [Expense] {
        switch self {
        case .single(let e): return [e]
        case .group(_, let expenses): return expenses
        }
    }

    var cost: Expense? { allExpenses.first { $0.kind == .expense } }
    var income: Expense? { allExpenses.first { $0.kind == .income } }
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
            kind: kind.rawValue,
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
