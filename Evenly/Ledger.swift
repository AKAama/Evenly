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

    init(id: UUID = UUID(), name: String, userId: String? = nil) {
        self.id = id
        self.name = name
        self.userId = userId
    }

    // Create from MemberResponse
    init(from member: MemberResponse) {
        self.id = UUID()
        self.name = member.nickname ?? member.user?.displayName ?? member.user?.email ?? "Unknown"
        self.userId = member.userId
    }
}

extension Person: Comparable {
    static func < (lhs: Person, rhs: Person) -> Bool {
        return lhs.name < rhs.name
    }
}

extension Person: Equatable {
    static func == (lhs: Person, rhs: Person) -> Bool {
        // Compare by userId if available, otherwise by name
        if let lhsUserId = lhs.userId, let rhsUserId = rhs.userId {
            return lhsUserId == rhsUserId
        }
        return lhs.name == rhs.name && lhs.id == rhs.id
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

    init(
        id: UUID = UUID(),
        title: String,
        ownerId: String,
        memberIds: [String] = [],
        participants: [Person] = [],
        expenses: [Expense] = [],
        members: [MemberResponse]? = nil
    ) {
        self.id = id
        self.title = title
        self.ownerId = ownerId
        self.memberIds = memberIds
        self.participants = participants
        self.expenses = expenses
        self.members = members
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
    }

    // Create from LedgerWithMembers
    init(from response: LedgerWithMembers) {
        self.id = UUID(uuidString: response.id) ?? UUID()
        self.title = response.name
        self.ownerId = response.ownerId
        self.memberIds = response.members.map { $0.userId }
        self.participants = response.members.map { Person(from: $0) }
        self.expenses = []
        self.members = response.members
    }

    var allMemberIds: [String] {
        [ownerId] + memberIds
    }

    /// 参与者数量（包含 owner 和所有 participants）
    var participantCount: Int {
        participants.count
    }

    /// Get member by userId
    func member(by userId: String) -> MemberResponse? {
        members?.first { $0.userId == userId }
    }

    /// Get person by userId
    func person(by userId: String) -> Person? {
        participants.first { $0.userId == userId }
    }
}
