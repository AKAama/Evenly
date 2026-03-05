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
    static let register = "/auth/register"
    static let sendVerification = "/auth/send-verification"
    static let verifyCode = "/auth/verify-code"

    // MARK: - Users
    static let currentUser = "/users/me"
    static let uploadAvatar = "/users/me/avatar"
    static let updateUser = "/users/me"
    static let changePassword = "/users/me/password"
    static func searchUsers(q: String, limit: Int = 20) -> String {
        "/users/search?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)&limit=\(limit)"
    }

    // MARK: - Ledgers
    static let ledgers = "/ledgers"
    static func ledger(id: String) -> String {
        "/ledgers/\(id)"
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

    // MARK: - Expenses
    static func expenses(ledgerId: String) -> String {
        "/expenses/ledgers/\(ledgerId)/expenses"
    }
    static func expense(ledgerId: String, expenseId: String) -> String {
        "/expenses/\(expenseId)"
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
