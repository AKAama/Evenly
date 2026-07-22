//
//  APIEndpoints.swift
//  Evenly
//
//  API endpoint definitions
//

import Foundation

enum APIEndpoints {
    // MARK: - Auth
    static let login = "/auth/login"
    static let appleLogin = "/auth/apple"
    static let register = "/auth/register"
    static let sendVerification = "/auth/send-verification"
    static let verifyCode = "/auth/verify-code"
    static let sendPasswordReset = "/auth/password-reset/send"
    static let resetPassword = "/auth/password-reset"

    // MARK: - Users
    static let currentUser = "/users/me"
    static let uploadAvatar = "/users/me/avatar"
    static let updateUser = "/users/me"
    static let changePassword = "/users/me/password"
    static let authMethods = "/users/me/auth-methods"
    static let updateUsername = "/users/me/username"
    static let sendPasswordSetup = "/users/me/password/setup/send"
    static let setupPassword = "/users/me/password/setup"
    static let sendEmailChange = "/users/me/email/send-verification"
    static let changeEmail = "/users/me/email"
    static let deleteAccount = "/users/me"
    static let deactivationPreview = "/users/me/deactivation-preview"
    static let deactivateAccount = "/users/me/deactivate"
    static func pushDevice(token: String) -> String {
        "/users/me/push-devices/\(token)"
    }
    static func searchUsers(q: String, limit: Int = 20) -> String {
        "/users/search?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)&limit=\(limit)"
    }

    // MARK: - Platform admin (ops accounts)
    static func adminUsers(
        q: String? = nil,
        accountKind: String? = nil,
        badge: String? = nil,
        limit: Int = 100
    ) -> String {
        var parts = ["limit=\(limit)"]
        if let q, !q.isEmpty,
           let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            parts.append("q=\(encoded)")
        }
        if let accountKind, !accountKind.isEmpty {
            parts.append("account_kind=\(accountKind)")
        }
        if let badge, !badge.isEmpty,
           let encoded = badge.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            parts.append("badge=\(encoded)")
        }
        return "/admin/users?\(parts.joined(separator: "&"))"
    }

    static func adminLedgers(q: String? = nil, status: String? = nil, limit: Int = 100) -> String {
        var parts = ["limit=\(limit)"]
        if let q, !q.isEmpty,
           let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            parts.append("q=\(encoded)")
        }
        if let status, !status.isEmpty {
            parts.append("status=\(status)")
        }
        return "/admin/ledgers?\(parts.joined(separator: "&"))"
    }

    static func adminUser(id: String) -> String { "/admin/users/\(id)" }
    static func adminLedgerOverview(id: String) -> String { "/admin/ledgers/\(id)/overview" }
    static func adminDeactivateUser(id: String) -> String { "/admin/users/\(id)/deactivate" }
    static func adminResetPassword(id: String) -> String { "/admin/users/\(id)/reset-password" }
    static func adminSetBadge(id: String) -> String { "/admin/users/\(id)/badge" }
    static let adminBadges = "/admin/badges"
    static func adminBadge(id: String) -> String { "/admin/badges/\(id)" }
    static func adminAuditEvents(day: String?, source: String? = nil, limit: Int = 200) -> String {
        var parts = ["limit=\(limit)"]
        if let day { parts.append("day=\(day)") }
        if let source, !source.isEmpty { parts.append("source=\(source)") }
        return "/admin/audit-events?\(parts.joined(separator: "&"))"
    }
    static func adminAuditSummary(day: String?) -> String {
        var parts: [String] = []
        if let day { parts.append("day=\(day)") }
        return parts.isEmpty ? "/admin/audit-events/summary" : "/admin/audit-events/summary?\(parts.joined(separator: "&"))"
    }
    static let adminPlatformUsers = "/admin/platform-users"

    // MARK: - Ledgers
    static let ledgers = "/ledgers"
    static func ledger(id: String) -> String {
        "/ledgers/\(id)"
    }
    static func ledgerCover(id: String) -> String {
        "/ledgers/\(id)/cover"
    }
    static func ledgerOverview(id: String) -> String {
        "/ledgers/\(id)/overview"
    }
    static func members(ledgerId: String) -> String {
        "/ledgers/\(ledgerId)/members"
    }
    static func addMember(ledgerId: String) -> String {
        "/ledgers/\(ledgerId)/members"
    }
    static func removeMember(ledgerId: String, userId: String) -> String {
        "/ledgers/\(ledgerId)/members/\(userId)"
    }
    static func leaveLedger(ledgerId: String) -> String {
        "/ledgers/\(ledgerId)/members/me"
    }
    static let pendingInvitations = "/ledgers/invitations/pending"
    static func respondToInvitation(id: String, accept: Bool) -> String {
        "/ledgers/invitations/\(id)/\(accept ? "accept" : "reject")"
    }
    static func inviteLink(ledgerId: String) -> String {
        "/ledgers/\(ledgerId)/invite-link"
    }
    static func rotateInviteLink(ledgerId: String) -> String {
        "/ledgers/\(ledgerId)/invite-link/rotate"
    }
    static func inviteLinkPreview(token: String) -> String {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        return "/ledgers/invite-links/\(encoded)/preview"
    }
    static func joinInviteLink(token: String) -> String {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        return "/ledgers/invite-links/\(encoded)/join"
    }

    // MARK: - Expenses
    static func expenses(ledgerId: String) -> String {
        "/expenses/ledgers/\(ledgerId)/expenses"
    }
    static func voiceExpenseDraft(ledgerId: String) -> String {
        "/expenses/ledgers/\(ledgerId)/voice-draft"
    }
    static func voiceExpenseSession(ledgerId: String) -> String {
        "/expenses/ledgers/\(ledgerId)/voice-session"
    }
    static func expense(ledgerId: String, expenseId: String) -> String {
        "/expenses/\(expenseId)"
    }
    static func updateExpense(expenseId: String) -> String {
        "/expenses/\(expenseId)"
    }
    static func expenseRefund(expenseId: String) -> String {
        "/expenses/\(expenseId)/refund"
    }
    static func confirmExpense(expenseId: String) -> String {
        "/expenses/\(expenseId)/confirm"
    }
    static func rejectExpense(expenseId: String) -> String {
        "/expenses/\(expenseId)/reject"
    }
    static func deleteExpense(expenseId: String) -> String {
        "/expenses/\(expenseId)"
    }

    // MARK: - Settlements
    static func settlements(ledgerId: String) -> String {
        "/ledgers/\(ledgerId)/settlements"
    }
    static func settlementHistory(ledgerId: String) -> String {
        "/ledgers/\(ledgerId)/settlements/history"
    }
}
