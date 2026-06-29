//
//  Ledger.swift
//  Evenly
//
//  Ledger and Person data models
//

import Foundation

struct Person: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    /// Backend user ID
    var userId: String?
    var isTemporary: Bool

    init(id: UUID = UUID(), name: String, userId: String? = nil, isTemporary: Bool = false) {
        self.id = id
        self.name = name
        self.userId = userId
        self.isTemporary = isTemporary
    }

    // Create from MemberResponse
    init(from member: MemberResponse) {
        self.id = UUID(uuidString: member.id) ?? UUID()
        self.name = member.nickname ?? member.temporaryName ?? member.user?.displayName ?? member.user?.email ?? "Unknown"
        self.userId = member.userId
        self.isTemporary = member.isTemporary
    }
}

extension Person: Comparable {
    static func < (lhs: Person, rhs: Person) -> Bool {
        return lhs.name < rhs.name
    }
}

extension Person: Equatable {
    static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.id == rhs.id
    }
}

extension Person {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Ledger: Identifiable, Codable {
    let id: UUID
    var title: String
    let ownerId: String
    var memberIds: [String]
    var participants: [Person]
    var expenses: [Expense]
    var members: [MemberResponse]?
    var memberCount: Int
    var expenseCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, ownerId, memberIds, participants, expenses, members
        case memberCount, expenseCount
    }

    init(
        id: UUID = UUID(),
        title: String,
        ownerId: String,
        memberIds: [String] = [],
        participants: [Person] = [],
        expenses: [Expense] = [],
        members: [MemberResponse]? = nil,
        memberCount: Int? = nil,
        expenseCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.ownerId = ownerId
        self.memberIds = memberIds
        self.participants = participants
        self.expenses = expenses
        self.members = members
        self.memberCount = memberCount ?? participants.count
        self.expenseCount = expenseCount ?? expenses.count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        memberIds = try container.decodeIfPresent([String].self, forKey: .memberIds) ?? []
        participants = try container.decodeIfPresent([Person].self, forKey: .participants) ?? []
        expenses = try container.decodeIfPresent([Expense].self, forKey: .expenses) ?? []
        members = try container.decodeIfPresent([MemberResponse].self, forKey: .members)
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount) ?? participants.count
        expenseCount = try container.decodeIfPresent(Int.self, forKey: .expenseCount) ?? expenses.count
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(memberIds, forKey: .memberIds)
        try container.encode(participants, forKey: .participants)
        try container.encode(expenses, forKey: .expenses)
        try container.encodeIfPresent(members, forKey: .members)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encode(expenseCount, forKey: .expenseCount)
    }

    // Create from LedgerResponse
    init(from response: LedgerResponse) {
        self.id = UUID(uuidString: response.id) ?? UUID()
        self.title = response.name
        self.ownerId = response.ownerId
        self.memberIds = []
        self.participants = []
        self.expenses = []
        self.members = nil
        self.memberCount = response.memberCount ?? 0
        self.expenseCount = response.expenseCount ?? 0
    }

    // Create from LedgerWithMembers
    init(from response: LedgerWithMembers) {
        self.id = UUID(uuidString: response.id) ?? UUID()
        self.title = response.name
        self.ownerId = response.ownerId
        self.memberIds = response.members.compactMap { $0.userId }
        self.participants = response.members.map { Person(from: $0) }
        self.expenses = []
        self.members = response.members
        self.memberCount = response.members.count
        self.expenseCount = 0
    }

    var allMemberIds: [String] {
        [ownerId] + memberIds
    }

    /// 参与者数量（包含 owner 和所有 participants）
    var participantCount: Int {
        memberCount
    }

    /// Get member by userId
    func member(by userId: String) -> MemberResponse? {
        members?.first { $0.userId == userId }
    }

    /// Get person by userId
    func person(by userId: String) -> Person? {
        participants.first { $0.userId == userId }
    }

    func registeredUserId(for person: Person) -> String? {
        // Compare member ids as UUIDs: backend ids are lowercase strings while
        // `person.id.uuidString` is uppercase, so a string comparison fails for
        // ids containing hex letters.
        if let member = members?.first(where: { UUID(uuidString: $0.id) == person.id }),
           !member.isTemporary,
           let userId = member.userId,
           !userId.isEmpty {
            return userId
        }

        if let participant = participants.first(where: { $0.id == person.id }),
           !participant.isTemporary,
           let userId = participant.userId,
           !userId.isEmpty {
            return userId
        }

        guard !person.isTemporary, let userId = person.userId, !userId.isEmpty else {
            return nil
        }
        return userId
    }
}
