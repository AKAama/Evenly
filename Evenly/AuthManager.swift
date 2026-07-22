//
//  AuthManager.swift
//  Evenly
//
//  Authentication manager using Python backend
//

import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit
import Security
import os

class AuthManager: ObservableObject {
    private static let logger = Logger(subsystem: "com.yhma.Evenly", category: "Authentication")
    @Published var user: UserResponse?
    @Published var userProfile: UserProfile?
    @Published var avatarImage: UIImage?
    @Published var isGuestMode = false
    @Published private(set) var authMethods: [String] = []
    @Published private(set) var hasPassword = true

    /// Platform ops account — uses a separate iOS shell (not ledger tabs).
    var isPlatformUser: Bool {
        user?.isPlatformAccount == true
    }

    // Login/Register state
    @Published var loginIdentifier = ""
    @Published var loginPassword = ""
    @Published var loginError: String?
    @Published var registerError: String?
    @Published var isLoading = false

    // Verification code state
    @Published var verificationCode = ""
    @Published var isSendingCode = false

    private let api = APIClient.shared
    private var currentAppleNonce: String?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingResetAuth") {
            api.clearToken()
        }

        // Try to restore session from stored token
        Task {
            await restoreSession()
        }
    }

    // MARK: - Session Restoration

    private func restoreSession() async {
        guard api.currentToken != nil else { return }

        do {
            let user: UserResponse = try await api.get(APIEndpoints.currentUser)
            await MainActor.run {
                self.user = user
                self.userProfile = UserProfile(
                    id: user.id,
                    username: user.username,
                    name: user.displayName,
                    email: user.email,
                    phone: nil,
                    avatarUrl: user.avatarUrl
                )
            }
        } catch {
            // Token is invalid, clear it
            await MainActor.run {
                api.clearToken()
            }
        }
    }

    // MARK: - Login

    func signIn(identifier: String, password: String, completion: @escaping (Error?) -> Void) {
        isLoading = true
        loginError = nil

        Task {
            do {
                // The login endpoint expects form data with username field (email)
                let formData = [
                    "username": identifier,
                    "password": password
                ]

                // Create URL with query params for form data
                guard let url = URL(string: "\(APIClient.baseURL)\(APIEndpoints.login)") else {
                    throw APIError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

                let bodyString = formData.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
                request.httpBody = bodyString.data(using: .utf8)

                // Use APIClient session timeouts (not URLSession.shared defaults).
                var timedRequest = request
                timedRequest.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: timedRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                if httpResponse.statusCode == 401 {
                    await MainActor.run {
                        self.loginError = "邮箱或密码错误"
                        self.isLoading = false
                    }
                    completion(NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "邮箱或密码错误"]))
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    throw APIError.server(statusCode: httpResponse.statusCode, data: data)
                }

                let decoder = JSONDecoder()
                let loginResponse = try decoder.decode(LoginResponse.self, from: data)

                // Store token
                api.setToken(loginResponse.accessToken)

                // Get user info
                let user: UserResponse = try await api.get(APIEndpoints.currentUser)

                await MainActor.run {
                    self.user = user
                    self.userProfile = UserProfile(
                        id: user.id,
                        username: user.username,
                        name: user.displayName,
                        email: user.email,
                        phone: nil,
                        avatarUrl: user.avatarUrl
                    )
                    self.isLoading = false
                }
                completion(nil)

            } catch {
                await MainActor.run {
                    self.loginError = Self.friendlyNetworkError(error)
                    self.isLoading = false
                }
                completion(error)
            }
        }
    }

    private static func friendlyNetworkError(_ error: Error) -> String {
        let ns = error as NSError
        let isTimeout = (error as? URLError)?.code == .timedOut
            || ns.domain == NSURLErrorDomain && ns.code == NSURLErrorTimedOut
        let isOffline = (error as? URLError)?.code == .notConnectedToInternet
            || (error as? URLError)?.code == .networkConnectionLost
            || (error as? URLError)?.code == .cannotConnectToHost
        if isTimeout || isOffline {
            return "网络超时，请检查网络后重试"
        }
        return error.localizedDescription
    }

    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        Self.logger.info("Preparing Sign in with Apple request")
        let nonce = Self.randomNonce()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        loginError = nil
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            Self.logger.error("Sign in with Apple failed: \(error.localizedDescription, privacy: .public)")
            isLoading = false
            if (error as? ASAuthorizationError)?.code != .canceled {
                loginError = error.localizedDescription
            }
        case .success(let authorization):
            Self.logger.info("Received Sign in with Apple authorization")
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentAppleNonce
            else {
                Self.logger.error("Apple authorization did not contain a usable identity token or nonce")
                loginError = "无法读取 Apple 登录凭证"
                isLoading = false
                return
            }

            let fullName = credential.fullName.map {
                PersonNameComponentsFormatter().string(from: $0)
            }.flatMap { $0.isEmpty ? nil : $0 }
            isLoading = true

            Task {
                do {
                    let loginResponse: LoginResponse = try await api.post(
                        APIEndpoints.appleLogin,
                        body: AppleLoginRequest(
                            identityToken: identityToken,
                            nonce: nonce,
                            fullName: fullName
                        ),
                        requiresAuth: false
                    )
                    api.setToken(loginResponse.accessToken)
                    let user: UserResponse = try await api.get(APIEndpoints.currentUser)
                    await MainActor.run {
                        self.user = user
                        self.userProfile = UserProfile(
                            id: user.id,
                            username: user.username,
                            name: user.displayName,
                            email: user.email,
                            phone: nil,
                            avatarUrl: user.avatarUrl
                        )
                        self.currentAppleNonce = nil
                        self.isLoading = false
                        HapticManager.notificationOccurred(.success)
                    }
                } catch {
                    await MainActor.run {
                        self.loginError = error.localizedDescription
                        self.currentAppleNonce = nil
                        self.isLoading = false
                        HapticManager.notificationOccurred(.error)
                    }
                }
            }
        }
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                fatalError("Unable to generate a secure Apple sign-in nonce")
            }
            for byte in bytes where byte < characters.count {
                result.append(characters[Int(byte)])
                remaining -= 1
                if remaining == 0 { break }
            }
        }
        return result
    }

    // MARK: - Register

    func signUp(
        username: String,
        displayName: String,
        email: String,
        phone: String,
        password: String,
        completion: @escaping (Error?) -> Void
    ) {
        isLoading = true
        registerError = nil

        Task {
            do {
                // Build form data
                let formFields: [String: String] = [
                    "email": email,
                    "username": username,
                    "password": password,
                    "code": verificationCode,
                    "display_name": displayName
                ]

                let response: RegisterResponse = try await api.requestWithFormData(
                    endpoint: APIEndpoints.register,
                    method: .post,
                    formFields: formFields,
                    files: [],
                    requiresAuth: false
                )

                // Store token
                api.setToken(response.accessToken)

                // Get user info
                let user: UserResponse = try await api.get(APIEndpoints.currentUser)

                await MainActor.run {
                    self.user = user
                    self.userProfile = UserProfile(
                        id: user.id,
                        username: user.username,
                        name: user.displayName,
                        email: user.email,
                        phone: phone,
                        avatarUrl: user.avatarUrl
                    )
                    self.isLoading = false
                    self.verificationCode = ""
                }
                completion(nil)

            } catch let error as APIError {
                await MainActor.run {
                    switch error {
                    case .serverError(let code, _) where code == 400:
                        self.registerError = "验证码错误或已过期"
                    default:
                        self.registerError = error.errorDescription ?? "注册失败"
                    }
                    self.isLoading = false
                }
                completion(error)
            } catch {
                await MainActor.run {
                    self.registerError = error.localizedDescription
                    self.isLoading = false
                }
                completion(error)
            }
        }
    }

    // MARK: - Verification Code

    func sendVerificationCode(email: String, completion: @escaping (Error?) -> Void) {
        isSendingCode = true

        Task {
            do {
                guard let url = URL(string: "\(APIClient.baseURL)\(APIEndpoints.sendVerification)?email=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email)") else {
                    throw APIError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                await MainActor.run {
                    self.isSendingCode = false
                }

                if httpResponse.statusCode == 200 {
                    completion(nil)
                } else if httpResponse.statusCode == 400 {
                    completion(NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "该邮箱已被注册"]))
                } else if httpResponse.statusCode == 429 {
                    completion(NSError(domain: "AuthManager", code: 429, userInfo: [NSLocalizedDescriptionKey: "发送过于频繁，请稍后重试"]))
                } else {
                    completion(APIError.serverError(httpResponse.statusCode, nil))
                }

            } catch {
                await MainActor.run {
                    self.isSendingCode = false
                }
                completion(error)
            }
        }
    }

    // MARK: - Update Profile

    func updateAvatar(_ imageData: Data, completion: @escaping (Error?) -> Void) {
        guard user != nil else {
            completion(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"]))
            return
        }

        Task {
            do {
                let filename = "avatar.jpg"
                let formFields: [String: String] = [:]

                let updatedUser: UserResponse = try await api.requestWithFormData(
                    endpoint: APIEndpoints.uploadAvatar,
                    method: .post,
                    formFields: formFields,
                    files: [FileUpload(
                        fieldName: "file",
                        filename: filename,
                        mimeType: "image/jpeg",
                        data: imageData
                    )],
                    requiresAuth: true
                )

                await MainActor.run {
                    self.user = updatedUser
                    self.avatarImage = UIImage(data: imageData)
                    self.userProfile = UserProfile(
                        id: updatedUser.id,
                        username: updatedUser.username,
                        name: updatedUser.displayName,
                        email: updatedUser.email,
                        phone: self.userProfile?.phone,
                        avatarUrl: updatedUser.avatarUrl
                    )
                    completion(nil)
                }

            } catch {
                await MainActor.run {
                    completion(error)
                }
            }
        }
    }

    func updateDisplayName(_ displayName: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let userUpdate = UserUpdate(displayName: displayName, avatarUrl: nil)
                let updatedUser: UserResponse = try await api.put(APIEndpoints.updateUser, body: userUpdate)

                await MainActor.run {
                    self.user = updatedUser
                    self.userProfile = UserProfile(
                        id: updatedUser.id,
                        username: updatedUser.username,
                        name: updatedUser.displayName,
                        email: updatedUser.email,
                        phone: self.userProfile?.phone,
                        avatarUrl: updatedUser.avatarUrl
                    )
                    completion(nil)
                }

            } catch {
                await MainActor.run { completion(error) }
            }
        }
    }

    func changePassword(oldPassword: String, newPassword: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let passwordChange = PasswordChange(oldPassword: oldPassword, newPassword: newPassword)
                let _: MessageResponse = try await api.put(APIEndpoints.changePassword, body: passwordChange)
                await MainActor.run {
                    completion(nil)
                }
            } catch {
                await MainActor.run {
                    completion(error)
                }
            }
        }
    }

    func refreshAuthMethods() {
        guard user != nil else { return }
        Task {
            do {
                let response: AuthMethodsResponse = try await api.get(APIEndpoints.authMethods)
                await MainActor.run {
                    self.authMethods = response.methods
                    self.hasPassword = response.hasPassword
                }
            } catch {
                // Keep the existing UI state if this supplementary request fails.
            }
        }
    }

    func updateUsername(_ username: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let updated: UserResponse = try await api.put(
                    APIEndpoints.updateUsername,
                    body: UsernameUpdateRequest(username: username)
                )
                await MainActor.run {
                    self.user = updated
                    self.userProfile = UserProfile(
                        id: updated.id,
                        username: updated.username,
                        name: updated.displayName,
                        email: updated.email,
                        phone: self.userProfile?.phone,
                        avatarUrl: updated.avatarUrl
                    )
                    completion(nil)
                }
            } catch {
                await MainActor.run { completion(error) }
            }
        }
    }

    func sendPasswordSetupCode(completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let _: MessageResponse = try await api.post(APIEndpoints.sendPasswordSetup)
                await MainActor.run { completion(nil) }
            } catch {
                await MainActor.run { completion(error) }
            }
        }
    }

    func setupPassword(code: String, newPassword: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let _: MessageResponse = try await api.put(
                    APIEndpoints.setupPassword,
                    body: PasswordSetupRequest(code: code, newPassword: newPassword)
                )
                await MainActor.run {
                    self.hasPassword = true
                    if !self.authMethods.contains("password") {
                        self.authMethods.append("password")
                    }
                    completion(nil)
                }
            } catch {
                await MainActor.run { completion(error) }
            }
        }
    }

    // MARK: - Logout

    func signOut() {
        Task {
            await NotificationManager.shared.unregisterCurrentDevice()
            await MainActor.run {
                api.clearToken()
                self.user = nil
                self.userProfile = nil
                self.avatarImage = nil
                self.isGuestMode = false
                self.authMethods = []
                self.hasPassword = true
            }
        }
    }

    func enterGuestMode() {
        api.clearToken()
        user = nil
        userProfile = nil
        avatarImage = nil
        isGuestMode = true
    }

    func leaveGuestMode() {
        isGuestMode = false
    }

    // MARK: - Password Reset

    func sendPasswordResetCode(email: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let _: MessageResponse = try await api.post(APIEndpoints.sendPasswordReset, body: EmailRequest(email: email), requiresAuth: false)
                await MainActor.run { completion(nil) }
            } catch { await MainActor.run { completion(error) } }
        }
    }

    func resetPassword(email: String, code: String, newPassword: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let request = PasswordResetRequest(email: email, code: code, newPassword: newPassword)
                let _: MessageResponse = try await api.post(APIEndpoints.resetPassword, body: request, requiresAuth: false)
                await MainActor.run { completion(nil) }
            } catch { await MainActor.run { completion(error) } }
        }
    }

    func sendEmailChangeCode(newEmail: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let _: MessageResponse = try await api.post(APIEndpoints.sendEmailChange, body: EmailChangeCodeRequest(newEmail: newEmail))
                await MainActor.run { completion(nil) }
            } catch { await MainActor.run { completion(error) } }
        }
    }

    func changeEmail(newEmail: String, code: String, password: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let request = EmailChangeRequest(newEmail: newEmail, code: code, password: password)
                let updatedUser: UserResponse = try await api.put(APIEndpoints.changeEmail, body: request)
                await MainActor.run {
                    self.user = updatedUser
                    self.userProfile = UserProfile(
                        id: updatedUser.id, username: updatedUser.username, name: updatedUser.displayName,
                        email: updatedUser.email, phone: self.userProfile?.phone, avatarUrl: updatedUser.avatarUrl
                    )
                    completion(nil)
                }
            } catch { await MainActor.run { completion(error) } }
        }
    }

    // MARK: - Validation

    func isValidUsername(_ username: String) -> Bool {
        let pattern = "^[a-zA-Z][a-zA-Z0-9_]*$"
        return username.range(of: pattern, options: .regularExpression) != nil && username.count >= 3
    }

    func isValidPhone(_ phone: String) -> Bool {
        let pattern = "^1[3-9]\\d{9}$"
        return phone.range(of: pattern, options: .regularExpression) != nil
    }

    func isValidEmail(_ email: String) -> Bool {
        let pattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Check username availability

    func checkUsernameExists(_ username: String, completion: @escaping (Bool) -> Void) {
        // For now, we'll skip this check during registration since the backend doesn't have this endpoint
        completion(false)
    }

    // MARK: - Account deactivation (soft)

    func fetchDeactivationPreview() async throws -> DeactivationPreviewResponse {
        try await api.get(APIEndpoints.deactivationPreview)
    }

    /// Soft-deactivate: transfer/archive owned ledgers, keep shared history.
    func deactivateAccount(
        ownerTransfers: [DeactivateOwnerTransfer],
        completion: @escaping (Result<DeactivateAccountResponse, Error>) -> Void
    ) {
        guard user != nil else {
            completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])))
            return
        }

        isLoading = true
        Task {
            do {
                let body = DeactivateAccountRequest(ownerTransfers: ownerTransfers, confirm: true)
                let result: DeactivateAccountResponse = try await api.post(
                    APIEndpoints.deactivateAccount,
                    body: body
                )
                await MainActor.run {
                    self.api.clearToken()
                    self.user = nil
                    self.userProfile = nil
                    self.avatarImage = nil
                    self.isLoading = false
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    completion(.failure(error))
                }
            }
        }
    }

    /// Legacy entry: soft-deactivate with system defaults (no manual transfers).
    func deleteAccount(completion: @escaping (Error?) -> Void) {
        deactivateAccount(ownerTransfers: []) { result in
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }

    // MARK: - Reauthenticate (placeholder - requires backend support)

    func reauthenticate(email: String, password: String, completion: @escaping (Error?) -> Void) {
        // This feature requires backend support
        completion(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "重新认证功能暂不支持"]))
    }
}

// MARK: - User Profile Model

struct UserProfile {
    let id: String
    let username: String?
    let name: String?
    let email: String?
    let phone: String?
    let avatarUrl: String?

    var displayName: String {
        name ?? username ?? email?.components(separatedBy: "@").first ?? "用户"
    }

}
