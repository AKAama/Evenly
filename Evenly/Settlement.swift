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

    init(
        id: String = UUID().uuidString,
        fromUserId: String,
        fromUserName: String,
        toUserId: String,
        toUserName: String,
        amount: Decimal
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.toUserId = toUserId
        self.toUserName = toUserName
        self.amount = amount
    }

    // Create from SettlementInstruction
    init(from instruction: SettlementInstruction) {
        self.id = instruction.id
        self.fromUserId = instruction.fromUserId
        self.fromUserName = instruction.fromUserName
        self.toUserId = instruction.toUserId
        self.toUserName = instruction.toUserName
        self.amount = instruction.amount
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
        self.fromUserName = response.fromUser.displayName ?? response.fromUser.email ?? "Unknown"
        self.toUserName = response.toUser.displayName ?? response.toUser.email ?? "Unknown"
    }
}
