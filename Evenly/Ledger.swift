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
    var avatarUrl: String?
    var isTemporary: Bool
    /// Membership status: active / pending / rejected / removed
    var status: String

    /// True if the person has accepted the invitation and is an active member
    var isActive: Bool { status == "active" }
    /// True if the person has been invited but not yet accepted
    var isPending: Bool { status == "pending" }
    /// True if the person declined the invitation (row retained for re-invite).
    var isRejected: Bool { status == "rejected" }
    /// Removed members remain available for rendering historical expenses.
    var isRemoved: Bool { status == "removed" }

    init(id: UUID = UUID(), name: String, userId: String? = nil, avatarUrl: String? = nil, isTemporary: Bool = false, status: String = "active") {
        self.id = id
        self.name = name
        self.userId = userId
        self.avatarUrl = avatarUrl
        self.isTemporary = isTemporary
        self.status = status
    }

    // Create from MemberResponse
    init(from member: MemberResponse) {
        self.id = UUID(uuidString: member.id) ?? UUID()
        self.name = member.nickname ?? member.temporaryName ?? member.user?.displayName ?? member.user?.email ?? "Unknown"
        self.userId = member.userId
        self.avatarUrl = member.user?.avatarUrl
        self.isTemporary = member.isTemporary
        self.status = member.status
    }

    // Custom Decodable so cached data without `status` defaults to "active"
    enum CodingKeys: String, CodingKey {
        case id, name, userId, avatarUrl, isTemporary, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        isTemporary = try container.decodeIfPresent(Bool.self, forKey: .isTemporary) ?? false
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
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
    /// When true, bills need participant confirmation before settlement/share.
    var requireConfirmation: Bool
    /// Custom bookshelf cover (COS URL), same storage style as avatars.
    var coverUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, ownerId, memberIds, participants, expenses, members
        case memberCount, expenseCount, requireConfirmation, coverUrl
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
        expenseCount: Int? = nil,
        requireConfirmation: Bool = true,
        coverUrl: String? = nil
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
        self.requireConfirmation = requireConfirmation
        self.coverUrl = coverUrl
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
        requireConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requireConfirmation) ?? true
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
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
        try container.encode(requireConfirmation, forKey: .requireConfirmation)
        try container.encodeIfPresent(coverUrl, forKey: .coverUrl)
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
        self.requireConfirmation = response.requireConfirmation
        self.coverUrl = response.coverUrl
    }

    // Create from LedgerWithMembers
    init(from response: LedgerWithMembers) {
        let activeMembers = response.members.filter { $0.status == "active" }
        self.id = UUID(uuidString: response.id) ?? UUID()
        self.title = response.name
        self.ownerId = response.ownerId
        self.memberIds = activeMembers.compactMap { $0.userId }
        self.participants = response.members.map { Person(from: $0) }
        self.expenses = []
        self.members = response.members
        self.memberCount = activeMembers.count
        self.expenseCount = 0
        self.requireConfirmation = response.requireConfirmation
        self.coverUrl = response.coverUrl
    }

    /// Expenses that shape transfer flow / share money math.
    /// Confirmed + pending (projected final state); rejected bills stay out.
    var settlementExpenses: [Expense] {
        expenses.filter { $0.status != .rejected }
    }

    var hasPendingSettlementExpenses: Bool {
        settlementExpenses.contains { $0.status == .pending }
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

    /// Get a person by the settlement identity returned by the backend.
    /// Registered members use userId; temporary members use their member id.
    func person(by settlementId: String) -> Person? {
        let memberId = UUID(uuidString: settlementId)
        return participants.first {
            $0.userId == settlementId || (memberId != nil && $0.id == memberId)
        }
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
