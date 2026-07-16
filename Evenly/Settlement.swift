//
//  Settlement.swift
//  Evenly
//
//  Settlement data models
//

import Foundation

struct Settlement: Identifiable {
    let id: String
    let fromUserId: String
    let fromUserName: String
    let toUserId: String
    let toUserName: String
    let amount: Decimal
    /// Pending bills still affect this transfer; show gray "未确认" badge.
    let includesUnconfirmed: Bool

    init(
        id: String = UUID().uuidString,
        fromUserId: String,
        fromUserName: String,
        toUserId: String,
        toUserName: String,
        amount: Decimal,
        includesUnconfirmed: Bool = false
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.toUserId = toUserId
        self.toUserName = toUserName
        self.amount = amount
        self.includesUnconfirmed = includesUnconfirmed
    }

    // Create from SettlementInstruction
    init(from instruction: SettlementInstruction) {
        self.id = instruction.id
        self.fromUserId = instruction.fromUserId
        self.fromUserName = instruction.fromUserName
        self.toUserId = instruction.toUserId
        self.toUserName = instruction.toUserName
        self.amount = instruction.amount
        self.includesUnconfirmed = instruction.includesUnconfirmed
    }
}

struct SettlementHistory: Identifiable {
    let id: String
    let ledgerId: String
    let fromUserId: String
    let toUserId: String
    let amount: Decimal
    let note: String?
    let settledAt: Date?
    let fromUserName: String
    let toUserName: String

    init(from response: SettlementWithUsers) {
        self.id = response.id
        self.ledgerId = response.ledgerId
        self.fromUserId = response.fromUserId
        self.toUserId = response.toUserId
        self.amount = response.amount
        self.note = response.note
        self.settledAt = response.settledAt
        self.fromUserName = response.fromUser.displayName ?? response.fromUser.email
        self.toUserName = response.toUser.displayName ?? response.toUser.email
    }

    nonisolated private init(group: [SettlementHistory]) {
        let latest = group.max { ($0.settledAt ?? .distantPast) < ($1.settledAt ?? .distantPast) }!
        self.id = "\(latest.fromUserId)->\(latest.toUserId)"
        self.ledgerId = latest.ledgerId
        self.fromUserId = latest.fromUserId
        self.toUserId = latest.toUserId
        self.amount = group.reduce(Decimal.zero) { $0 + $1.amount }
        self.note = nil
        self.settledAt = latest.settledAt
        self.fromUserName = latest.fromUserName
        self.toUserName = latest.toUserName
    }

    nonisolated static func merging(_ records: [SettlementHistory]) -> [SettlementHistory] {
        Dictionary(grouping: records) { "\($0.fromUserId)->\($0.toUserId)" }
            .values
            .map(SettlementHistory.init(group:))
            .sorted { ($0.settledAt ?? .distantPast) > ($1.settledAt ?? .distantPast) }
    }
}
