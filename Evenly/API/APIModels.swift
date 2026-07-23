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

    func decodeFlexibleDecimalIfPresent(forKey key: Key) throws -> Decimal? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeFlexibleDecimal(forKey: key)
    }

    /// Accept UUID string or bare UUID from FastAPI/Pydantic.
    func decodeFlexibleID(forKey key: Key) throws -> String {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let u = try? decode(UUID.self, forKey: key) { return u.uuidString.lowercased() }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected string or UUID id")
    }

    func decodeFlexibleIDIfPresent(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeFlexibleID(forKey: key)
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

struct AppleLoginRequest: Encodable {
    let identityToken: String
    let nonce: String
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case nonce
        case fullName = "full_name"
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
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let createdAt: Date?
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
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
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let createdAt: Date?
    let usernameIsGenerated: Bool
    /// Nameplate key from admin catalog
    let badge: String?
    /// Chinese label from server, e.g. 创始人
    let badgeLabel: String?
    /// Ant Design color name or #hex
    let badgeColor: String?
    /// active | deactivated
    let status: String?
    /// Includes （已注销） when deactivated
    let publicDisplayName: String?
    /// app | platform
    let accountKind: String?
    /// True for platform ops accounts
    let isAdmin: Bool?

    /// Prefer server public label when present.
    var resolvedDisplayName: String {
        if let publicDisplayName, !publicDisplayName.isEmpty { return publicDisplayName }
        return displayName ?? username
    }

    /// Platform ops console account (not a normal ledger user).
    var isPlatformAccount: Bool {
        if (accountKind ?? "app") == "platform" { return true }
        return isAdmin == true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case usernameIsGenerated = "username_is_generated"
        case badge
        case badgeLabel = "badge_label"
        case badgeColor = "badge_color"
        case status
        case publicDisplayName = "public_display_name"
        case accountKind = "account_kind"
        case isAdmin = "is_admin"
    }

    init(
        id: String,
        email: String,
        username: String,
        displayName: String? = nil,
        avatarUrl: String? = nil,
        createdAt: Date? = nil,
        usernameIsGenerated: Bool = false,
        badge: String? = nil,
        badgeLabel: String? = nil,
        badgeColor: String? = nil,
        status: String? = "active",
        publicDisplayName: String? = nil,
        accountKind: String? = "app",
        isAdmin: Bool? = false
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.createdAt = createdAt
        self.usernameIsGenerated = usernameIsGenerated
        self.badge = badge
        self.badgeLabel = badgeLabel
        self.badgeColor = badgeColor
        self.status = status
        self.publicDisplayName = publicDisplayName
        self.accountKind = accountKind
        self.isAdmin = isAdmin
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        usernameIsGenerated = try container.decodeIfPresent(Bool.self, forKey: .usernameIsGenerated) ?? false
        badge = try container.decodeIfPresent(String.self, forKey: .badge)
        badgeLabel = try container.decodeIfPresent(String.self, forKey: .badgeLabel)
        badgeColor = try container.decodeIfPresent(String.self, forKey: .badgeColor)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        publicDisplayName = try container.decodeIfPresent(String.self, forKey: .publicDisplayName)
        accountKind = try container.decodeIfPresent(String.self, forKey: .accountKind)
        isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin)
    }
}

// MARK: - Platform admin (iOS ops shell)

struct AdminUserListResponse: Codable {
    let total: Int
    let items: [AdminUserListItem]
}

struct AdminUserListItem: Codable, Identifiable {
    let id: String
    let email: String
    let username: String
    let displayName: String?
    let publicDisplayName: String?
    let avatarUrl: String?
    let accountKind: String?
    let status: String?
    let badge: String?
    let badgeLabel: String?
    let badgeColor: String?
    let membershipCount: Int?
    let ownedLedgerCount: Int?
    let expenseCreatedCount: Int?
    let createdAt: Date?

    var listTitle: String {
        publicDisplayName ?? displayName ?? username
    }

    enum CodingKeys: String, CodingKey {
        case id, email, username, badge, status
        case displayName = "display_name"
        case publicDisplayName = "public_display_name"
        case avatarUrl = "avatar_url"
        case accountKind = "account_kind"
        case badgeLabel = "badge_label"
        case badgeColor = "badge_color"
        case membershipCount = "membership_count"
        case ownedLedgerCount = "owned_ledger_count"
        case expenseCreatedCount = "expense_created_count"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeFlexibleID(forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        username = try c.decode(String.self, forKey: .username)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        publicDisplayName = try c.decodeIfPresent(String.self, forKey: .publicDisplayName)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        accountKind = try c.decodeIfPresent(String.self, forKey: .accountKind)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        badge = try c.decodeIfPresent(String.self, forKey: .badge)
        badgeLabel = try c.decodeIfPresent(String.self, forKey: .badgeLabel)
        badgeColor = try c.decodeIfPresent(String.self, forKey: .badgeColor)
        membershipCount = try c.decodeIfPresent(Int.self, forKey: .membershipCount)
        ownedLedgerCount = try c.decodeIfPresent(Int.self, forKey: .ownedLedgerCount)
        expenseCreatedCount = try c.decodeIfPresent(Int.self, forKey: .expenseCreatedCount)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct AdminLedgerListResponse: Codable {
    let total: Int
    let items: [AdminLedgerListItem]
}

struct AdminLedgerListItem: Codable, Identifiable {
    let id: String
    let name: String
    let ownerId: String?
    let currency: String?
    let status: String?
    let ownerLabel: String?
    let ownerEmail: String?
    let memberCount: Int?
    let expenseCount: Int?
    let totalSpend: Double?
    let createdAt: Date?
    /// Archived with no living registered members — display tag only.
    let isOrphan: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, currency, status
        case ownerId = "owner_id"
        case ownerLabel = "owner_label"
        case ownerEmail = "owner_email"
        case memberCount = "member_count"
        case expenseCount = "expense_count"
        case totalSpend = "total_spend"
        case createdAt = "created_at"
        case isOrphan = "is_orphan"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeFlexibleID(forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        ownerId = try c.decodeFlexibleIDIfPresent(forKey: .ownerId)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        ownerLabel = try c.decodeIfPresent(String.self, forKey: .ownerLabel)
        ownerEmail = try c.decodeIfPresent(String.self, forKey: .ownerEmail)
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount)
        expenseCount = try c.decodeIfPresent(Int.self, forKey: .expenseCount)
        if let d = try? c.decodeIfPresent(Double.self, forKey: .totalSpend) {
            totalSpend = d
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .totalSpend) {
            totalSpend = Double(i)
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .totalSpend), let d = Double(s) {
            totalSpend = d
        } else {
            totalSpend = nil
        }
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        isOrphan = try c.decodeIfPresent(Bool.self, forKey: .isOrphan)
    }
}

struct AdminBadgeItem: Codable, Identifiable {
    let id: String
    let key: String
    let label: String
    let description: String?
    let color: String?
    let sortOrder: Int?
    let isActive: Bool?
    let userCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, key, label, description, color
        case sortOrder = "sort_order"
        case isActive = "is_active"
        case userCount = "user_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeFlexibleID(forKey: .id)
        key = try c.decode(String.self, forKey: .key)
        label = try c.decode(String.self, forKey: .label)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive)
        userCount = try c.decodeIfPresent(Int.self, forKey: .userCount)
    }
}

struct AdminBadgeListResponse: Codable {
    let items: [AdminBadgeItem]
    let unassignedCount: Int?

    enum CodingKeys: String, CodingKey {
        case items
        case unassignedCount = "unassigned_count"
    }
}

struct AdminBadgeCreateBody: Encodable {
    let label: String
    let description: String?
    let color: String
    let key: String?
}

struct AdminBadgeUpdateBody: Encodable {
    var label: String? = nil
    var description: String? = nil
    var color: String? = nil
    var isActive: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case label, description, color
        case isActive = "is_active"
    }
}

struct AdminSetBadgeBody: Encodable {
    let badge: String?
}

struct AdminResetPasswordBody: Encodable {
    let newPassword: String
    enum CodingKeys: String, CodingKey { case newPassword = "new_password" }
}

struct AdminResetPasswordResponse: Codable {
    let message: String?
    let userId: String?
    let username: String?
    enum CodingKeys: String, CodingKey {
        case message
        case userId = "user_id"
        case username
    }
}

struct AuditEventItem: Codable, Sendable, Identifiable {
    let id: String
    let createdAt: Date?
    let actorLabel: String?
    let action: String
    let source: String?
    let summary: String?
    let ip: String?

    enum CodingKeys: String, CodingKey {
        case id, action, source, summary, ip
        case createdAt = "created_at"
        case actorLabel = "actor_label"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Invalid audit id")
        }
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        actorLabel = try c.decodeIfPresent(String.self, forKey: .actorLabel)
        action = try c.decode(String.self, forKey: .action)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        ip = try c.decodeIfPresent(String.self, forKey: .ip)
    }
}

struct AuditEventListResponse: Codable, Sendable {
    let day: String?
    let total: Int
    let items: [AuditEventItem]
}

struct AuditSummaryResponse: Codable, Sendable {
    let total: Int?
    let byAction: [AuditActionCount]?

    enum CodingKeys: String, CodingKey {
        case total
        case byAction = "by_action"
    }
}

struct AuditActionCount: Codable, Sendable, Identifiable {
    var id: String { action }
    let action: String
    let count: Int
}

struct PlatformUserCreateBody: Encodable {
    let email: String
    let username: String
    let password: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case email, username, password
        case displayName = "display_name"
    }
}

// MARK: - Account deactivation

struct DeactivationMemberBrief: Codable, Identifiable, Hashable {
    let userId: String
    let displayName: String
    let username: String

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case username
    }
}

struct DeactivationTransferPreview: Codable, Identifiable {
    let ledgerId: String
    let ledgerName: String
    let memberCountRegisteredActive: Int
    let defaultSuccessor: DeactivationMemberBrief?
    let candidates: [DeactivationMemberBrief]

    var id: String { ledgerId }

    enum CodingKeys: String, CodingKey {
        case ledgerId = "ledger_id"
        case ledgerName = "ledger_name"
        case memberCountRegisteredActive = "member_count_registered_active"
        case defaultSuccessor = "default_successor"
        case candidates
    }
}

struct DeactivationArchivePreview: Codable, Identifiable {
    let ledgerId: String
    let ledgerName: String
    let action: String
    let reason: String

    var id: String { ledgerId }

    enum CodingKeys: String, CodingKey {
        case ledgerId = "ledger_id"
        case ledgerName = "ledger_name"
        case action
        case reason
    }
}

struct DeactivationPreviewResponse: Codable {
    let ownedLedgersRequiringTransfer: [DeactivationTransferPreview]
    let ownedLedgersToArchive: [DeactivationArchivePreview]
    let membershipLedgerCount: Int

    enum CodingKeys: String, CodingKey {
        case ownedLedgersRequiringTransfer = "owned_ledgers_requiring_transfer"
        case ownedLedgersToArchive = "owned_ledgers_to_archive"
        case membershipLedgerCount = "membership_ledger_count"
    }
}

struct DeactivateOwnerTransfer: Encodable {
    let ledgerId: String
    let newOwnerId: String?

    enum CodingKeys: String, CodingKey {
        case ledgerId = "ledger_id"
        case newOwnerId = "new_owner_id"
    }
}

struct DeactivateAccountRequest: Encodable {
    let ownerTransfers: [DeactivateOwnerTransfer]
    let confirm: Bool

    enum CodingKeys: String, CodingKey {
        case ownerTransfers = "owner_transfers"
        case confirm
    }
}

struct DeactivateTransferResult: Codable, Identifiable {
    let ledgerId: String
    let ledgerName: String
    let action: String
    let newOwner: DeactivationMemberBrief?

    var id: String { ledgerId }

    enum CodingKeys: String, CodingKey {
        case ledgerId = "ledger_id"
        case ledgerName = "ledger_name"
        case action
        case newOwner = "new_owner"
    }
}

struct DeactivateAccountResponse: Codable {
    let transfers: [DeactivateTransferResult]
}

struct AuthMethodsResponse: Decodable {
    let methods: [String]
    let hasPassword: Bool

    enum CodingKeys: String, CodingKey {
        case methods
        case hasPassword = "has_password"
    }
}

struct UsernameUpdateRequest: Encodable {
    let username: String
}

struct PasswordSetupRequest: Encodable {
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case code
        case newPassword = "new_password"
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

struct EmailRequest: Encodable {
    let email: String
}

struct EmailChangeCodeRequest: Encodable {
    let newEmail: String
    enum CodingKeys: String, CodingKey { case newEmail = "new_email" }
}

struct EmailChangeRequest: Encodable {
    let newEmail: String
    let code: String
    let password: String
    enum CodingKeys: String, CodingKey {
        case newEmail = "new_email"
        case code, password
    }
}

struct PasswordResetRequest: Encodable {
    let email: String
    let code: String
    let newPassword: String
    enum CodingKeys: String, CodingKey {
        case email, code
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
    let requireConfirmation: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case currency
        case members
        case requireConfirmation = "require_confirmation"
    }
}

struct LedgerUpdate: Encodable {
    var name: String? = nil
    var currency: String? = nil
    var requireConfirmation: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case name
        case currency
        case requireConfirmation = "require_confirmation"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(currency, forKey: .currency)
        try container.encodeIfPresent(requireConfirmation, forKey: .requireConfirmation)
    }
}

struct LedgerResponse: Decodable, Identifiable {
    let id: String
    let name: String
    let ownerId: String
    let currency: String?
    let requireConfirmation: Bool
    let coverUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    let memberCount: Int?
    let expenseCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId = "owner_id"
        case currency
        case requireConfirmation = "require_confirmation"
        case coverUrl = "cover_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memberCount = "member_count"
        case expenseCount = "expense_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        requireConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requireConfirmation) ?? true
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount)
        expenseCount = try container.decodeIfPresent(Int.self, forKey: .expenseCount)
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
    let requireConfirmation: Bool
    let coverUrl: String?
    let createdAt: Date?
    let members: [MemberResponse]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId = "owner_id"
        case currency
        case requireConfirmation = "require_confirmation"
        case coverUrl = "cover_url"
        case createdAt = "created_at"
        case members
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        requireConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requireConfirmation) ?? true
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        members = try container.decodeIfPresent([MemberResponse].self, forKey: .members) ?? []
    }
}

struct LedgerOverviewResponse: Decodable {
    let ledger: LedgerWithMembers
    let expenses: [ExpenseWithDetails]
    let settlementSuggestions: [SettlementInstruction]
    let settlementHistory: [SettlementWithUsers]

    enum CodingKeys: String, CodingKey {
        case ledger, expenses
        case settlementSuggestions = "settlement_suggestions"
        case settlementHistory = "settlement_history"
    }
}

struct LedgerInviteLinkResponse: Decodable {
    let token: String
    let url: String
    let ledgerId: String
    let ledgerName: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case token, url
        case ledgerId = "ledger_id"
        case ledgerName = "ledger_name"
        case createdAt = "created_at"
    }
}

struct LedgerInvitePreviewResponse: Decodable {
    let token: String
    let ledgerId: String
    let ledgerName: String
    let ownerName: String
    let valid: Bool

    enum CodingKeys: String, CodingKey {
        case token, valid
        case ledgerId = "ledger_id"
        case ledgerName = "ledger_name"
        case ownerName = "owner_name"
    }
}

struct JoinLedgerResponse: Decodable {
    let ledgerId: String
    let ledgerName: String
    let status: String
    let memberId: String

    enum CodingKeys: String, CodingKey {
        case status
        case ledgerId = "ledger_id"
        case ledgerName = "ledger_name"
        case memberId = "member_id"
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
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case nickname
        case joinedAt = "joined_at"
        case user
        case isTemporary = "is_temporary"
        case temporaryName = "temporary_name"
        case status
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
        try container.encode(status, forKey: .status)
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
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        id = decodedId ?? userId ?? UUID().uuidString
    }
}

struct LedgerInvitationResponse: Decodable, Identifiable {
    let id: String
    let ledgerId: String
    let ledgerName: String
    let invitedByName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ledgerId = "ledger_id"
        case ledgerName = "ledger_name"
        case invitedByName = "invited_by_name"
        case createdAt = "created_at"
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
    let category: String?
    let iconType: String?
    let iconValue: String?

    enum CodingKeys: String, CodingKey {
        case title
        case totalAmount = "total_amount"
        case payerId = "payer_id"
        case splits
        case note
        case expenseDate = "expense_date"
        case category
        case iconType = "icon_type"
        case iconValue = "icon_value"
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
    let refundAmount: Decimal?
    let note: String?
    let expenseDate: Date?
    let status: String
    let createdAt: Date?
    let updatedAt: Date?
    let category: String?
    let iconType: String?
    let iconValue: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ledgerId = "ledger_id"
        case payerId = "payer_id"
        case createdBy = "created_by"
        case title
        case totalAmount = "total_amount"
        case refundAmount = "refund_amount"
        case note
        case expenseDate = "expense_date"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case category
        case iconType = "icon_type"
        case iconValue = "icon_value"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ledgerId = try container.decode(String.self, forKey: .ledgerId)
        payerId = try container.decode(String.self, forKey: .payerId)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        title = try container.decode(String.self, forKey: .title)
        totalAmount = try container.decodeFlexibleDecimal(forKey: .totalAmount)
        refundAmount = try container.decodeFlexibleDecimalIfPresent(forKey: .refundAmount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        expenseDate = try container.decodeIfPresent(Date.self, forKey: .expenseDate)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        iconType = try container.decodeIfPresent(String.self, forKey: .iconType)
        iconValue = try container.decodeIfPresent(String.self, forKey: .iconValue)
    }
}

struct ExpenseRefundRequest: Encodable {
    let refundAmount: Decimal
    let note: String?

    enum CodingKeys: String, CodingKey {
        case refundAmount = "refund_amount"
        case note
    }
}

struct ExpenseWithDetails: Decodable, Identifiable {
    let id: String
    let ledgerId: String
    let payerId: String
    let createdBy: String
    let title: String
    let totalAmount: Decimal
    let refundAmount: Decimal?
    let note: String?
    let expenseDate: Date?
    let status: String
    let createdAt: Date?
    let updatedAt: Date?
    let category: String?
    let iconType: String?
    let iconValue: String?
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
        case refundAmount = "refund_amount"
        case note
        case expenseDate = "expense_date"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case category
        case iconType = "icon_type"
        case iconValue = "icon_value"
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
        refundAmount = try container.decodeFlexibleDecimalIfPresent(forKey: .refundAmount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        expenseDate = try container.decodeIfPresent(Date.self, forKey: .expenseDate)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        iconType = try container.decodeIfPresent(String.self, forKey: .iconType)
        iconValue = try container.decodeIfPresent(String.self, forKey: .iconValue)
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

struct VoiceExpenseDraft: Decodable {
    let transcript: String
    let title: String
    let amount: Decimal
    let payerUserId: String
    let participantMemberIds: [String]
    let confirmationText: String
    let category: String?

    enum CodingKeys: String, CodingKey {
        case transcript, title, amount, category
        case payerUserId = "payer_user_id"
        case participantMemberIds = "participant_member_ids"
        case confirmationText = "confirmation_text"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transcript = try container.decode(String.self, forKey: .transcript)
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decodeFlexibleDecimal(forKey: .amount)
        payerUserId = try container.decode(String.self, forKey: .payerUserId)
        participantMemberIds = try container.decode([String].self, forKey: .participantMemberIds)
        confirmationText = try container.decode(String.self, forKey: .confirmationText)
        category = try container.decodeIfPresent(String.self, forKey: .category)
    }
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
    /// True when either party still has pending (unconfirmed) bills affecting this flow.
    let includesUnconfirmed: Bool

    var id: String { "\(fromUserId)-\(toUserId)" }

    enum CodingKeys: String, CodingKey {
        case fromUserId = "from_user_id"
        case fromUserName = "from_user_name"
        case toUserId = "to_user_id"
        case toUserName = "to_user_name"
        case amount
        case includesUnconfirmed = "includes_unconfirmed"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fromUserId = try container.decode(String.self, forKey: .fromUserId)
        fromUserName = try container.decode(String.self, forKey: .fromUserName)
        toUserId = try container.decode(String.self, forKey: .toUserId)
        toUserName = try container.decode(String.self, forKey: .toUserName)
        amount = try container.decodeFlexibleDecimal(forKey: .amount)
        includesUnconfirmed = try container.decodeIfPresent(Bool.self, forKey: .includesUnconfirmed) ?? false
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
