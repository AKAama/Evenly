//
//  APIModels.swift
//  Evenly
//
//  API request and response models
//

import Foundation

extension KeyedDecodingContainer {
    func decodeFlexibleDecimal(forKey key: Key) throws -> Decimal {
        if let decimal = try? decode(Decimal.self, forKey: key) {
            return decimal
        }
        let string = try decode(String.self, forKey: key)
        if let decimal = Decimal(string: string) {
            return decimal
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Invalid decimal value: \(string)")
    }
}

// MARK: - Auth Models

struct LoginRequest: Encodable {
    let username: String  // email for login
    let password: String
}

struct LoginResponse: Decodable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let code: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case code
        case displayName = "display_name"
    }
}

struct RegisterResponse: Decodable {
    let id: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
    let createdAt: Date?
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

// MARK: - User Models

struct UserResponse: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

struct UserUpdate: Encodable {
    let displayName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

struct PasswordChange: Encodable {
    let oldPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case oldPassword = "old_password"
        case newPassword = "new_password"
    }
}

struct MessageResponse: Decodable {
    let message: String
}

// MARK: - Ledger Models

struct MemberCreate: Encodable {
    let userId: String?
    let nickname: String?
    let isTemporary: Bool
    let temporaryName: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickname
        case isTemporary = "is_temporary"
        case temporaryName = "temporary_name"
    }
}

struct LedgerCreate: Encodable {
    let name: String
    let currency: String?
    let members: [MemberCreate]

    enum CodingKeys: String, CodingKey {
        case name
        case currency
        case members
    }
}

struct LedgerResponse: Decodable, Identifiable {
    let id: String
    let name: String
    let ownerId: String
    let currency: String?
    let createdAt: Date?
    let updatedAt: Date?
    let memberCount: Int?
    let expenseCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId = "owner_id"
        case currency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memberCount = "member_count"
        case expenseCount = "expense_count"
    }

    var needsSummaryHydration: Bool {
        memberCount == nil || expenseCount == nil
    }
}

struct LedgerWithMembers: Decodable {
    let id: String
    let name: String
    let ownerId: String
    let currency: String?
    let createdAt: Date?
    let members: [MemberResponse]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId = "owner_id"
        case currency
        case createdAt = "created_at"
        case members
    }
}

// MARK: - Member Models

struct AddMemberRequest: Encodable {
    let userId: String?
    let nickname: String?
    let isTemporary: Bool
    let temporaryName: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickname
        case isTemporary = "is_temporary"
        case temporaryName = "temporary_name"
    }
}

struct MemberResponse: Codable, Identifiable {
    let id: String
    let userId: String?
    let nickname: String?
    let joinedAt: Date?
    let user: UserResponse?
    let isTemporary: Bool
    let temporaryName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case nickname
        case joinedAt = "joined_at"
        case user
        case isTemporary = "is_temporary"
        case temporaryName = "temporary_name"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(joinedAt, forKey: .joinedAt)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encode(isTemporary, forKey: .isTemporary)
        try container.encodeIfPresent(temporaryName, forKey: .temporaryName)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt)
        user = try container.decodeIfPresent(UserResponse.self, forKey: .user)
        isTemporary = try container.decodeIfPresent(Bool.self, forKey: .isTemporary) ?? false
        temporaryName = try container.decodeIfPresent(String.self, forKey: .temporaryName)
        id = decodedId ?? userId ?? UUID().uuidString
    }
}

// MARK: - Expense Models

struct ExpenseCreate: Encodable {
    let title: String
    let totalAmount: Decimal
    let payerId: String
    let splits: [ExpenseSplitCreate]
    let note: String?
    let expenseDate: String

    enum CodingKeys: String, CodingKey {
        case title
        case totalAmount = "total_amount"
        case payerId = "payer_id"
        case splits
        case note
        case expenseDate = "expense_date"
    }
}

struct ExpenseSplitCreate: Encodable {
    let userId: String?
    let memberId: String
    let amount: Decimal

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case memberId = "member_id"
        case amount
    }
}

struct ExpenseResponse: Decodable, Identifiable {
    let id: String
    let ledgerId: String
    let payerId: String
    let createdBy: String
    let title: String
    let totalAmount: Decimal
    let note: String?
    let expenseDate: Date?
    let status: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ledgerId = "ledger_id"
        case payerId = "payer_id"
        case createdBy = "created_by"
        case title
        case totalAmount = "total_amount"
        case note
        case expenseDate = "expense_date"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ledgerId = try container.decode(String.self, forKey: .ledgerId)
        payerId = try container.decode(String.self, forKey: .payerId)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        title = try container.decode(String.self, forKey: .title)
        totalAmount = try container.decodeFlexibleDecimal(forKey: .totalAmount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        expenseDate = try container.decodeIfPresent(Date.self, forKey: .expenseDate)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct ExpenseWithDetails: Decodable, Identifiable {
    let id: String
    let ledgerId: String
    let payerId: String
    let createdBy: String
    let title: String
    let totalAmount: Decimal
    let note: String?
    let expenseDate: Date?
    let status: String
    let createdAt: Date?
    let updatedAt: Date?
    let payer: UserResponse
    let splits: [ExpenseSplitResponse]
    let confirmations: [ExpenseConfirmationResponse]

    enum CodingKeys: String, CodingKey {
        case id
        case ledgerId = "ledger_id"
        case payerId = "payer_id"
        case createdBy = "created_by"
        case title
        case totalAmount = "total_amount"
        case note
        case expenseDate = "expense_date"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case payer
        case splits
        case confirmations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ledgerId = try container.decode(String.self, forKey: .ledgerId)
        payerId = try container.decode(String.self, forKey: .payerId)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        title = try container.decode(String.self, forKey: .title)
        totalAmount = try container.decodeFlexibleDecimal(forKey: .totalAmount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        expenseDate = try container.decodeIfPresent(Date.self, forKey: .expenseDate)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        payer = try container.decode(UserResponse.self, forKey: .payer)
        splits = try container.decode([ExpenseSplitResponse].self, forKey: .splits)
        confirmations = try container.decode([ExpenseConfirmationResponse].self, forKey: .confirmations)
    }
}

struct ExpenseSplitResponse: Decodable, Identifiable {
    let id: String
    let expenseId: String
    let userId: String?
    let memberId: String?
    let amount: Decimal
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case expenseId = "expense_id"
        case userId = "user_id"
        case memberId = "member_id"
        case amount
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        expenseId = try container.decode(String.self, forKey: .expenseId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        memberId = try container.decodeIfPresent(String.self, forKey: .memberId)
        amount = try container.decodeFlexibleDecimal(forKey: .amount)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct ExpenseConfirmationResponse: Decodable, Identifiable {
    let id: String
    let expenseId: String
    let userId: String
    let status: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case expenseId = "expense_id"
        case userId = "user_id"
        case status
        case createdAt = "created_at"
    }
}

struct ConfirmExpenseRequest: Encodable {
    let status: String
}

// MARK: - Settlement Models

struct SettlementCreate: Encodable {
    let fromUserId: String
    let toUserId: String
    let amount: Decimal
    let note: String?

    enum CodingKeys: String, CodingKey {
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case amount
        case note
    }
}

struct SettlementResponse: Decodable, Identifiable {
    let id: String
    let ledgerId: String
    let fromUserId: String
    let toUserId: String
    let amount: Decimal
    let note: String?
    let settledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ledgerId = "ledger_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case amount
        case note
        case settledAt = "settled_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ledgerId = try container.decode(String.self, forKey: .ledgerId)
        fromUserId = try container.decode(String.self, forKey: .fromUserId)
        toUserId = try container.decode(String.self, forKey: .toUserId)
        amount = try container.decodeFlexibleDecimal(forKey: .amount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        settledAt = try container.decodeIfPresent(Date.self, forKey: .settledAt)
    }
}

struct SettlementInstruction: Decodable, Identifiable {
    let fromUserId: String
    let fromUserName: String
    let toUserId: String
    let toUserName: String
    let amount: Decimal

    var id: String { "\(fromUserId)-\(toUserId)" }

    enum CodingKeys: String, CodingKey {
        case fromUserId = "from_user_id"
        case fromUserName = "from_user_name"
        case toUserId = "to_user_id"
        case toUserName = "to_user_name"
        case amount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fromUserId = try container.decode(String.self, forKey: .fromUserId)
        fromUserName = try container.decode(String.self, forKey: .fromUserName)
        toUserId = try container.decode(String.self, forKey: .toUserId)
        toUserName = try container.decode(String.self, forKey: .toUserName)
        amount = try container.decodeFlexibleDecimal(forKey: .amount)
    }
}

struct SettlementWithUsers: Decodable, Identifiable {
    let id: String
    let ledgerId: String
    let fromUserId: String
    let toUserId: String
    let amount: Decimal
    let note: String?
    let settledAt: Date?
    let fromUser: UserResponse
    let toUser: UserResponse

    enum CodingKeys: String, CodingKey {
        case id
        case ledgerId = "ledger_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case amount
        case note
        case settledAt = "settled_at"
        case fromUser = "from_user"
        case toUser = "to_user"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ledgerId = try container.decode(String.self, forKey: .ledgerId)
        fromUserId = try container.decode(String.self, forKey: .fromUserId)
        toUserId = try container.decode(String.self, forKey: .toUserId)
        amount = try container.decodeFlexibleDecimal(forKey: .amount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        settledAt = try container.decodeIfPresent(Date.self, forKey: .settledAt)
        fromUser = try container.decode(UserResponse.self, forKey: .fromUser)
        toUser = try container.decode(UserResponse.self, forKey: .toUser)
    }
}
