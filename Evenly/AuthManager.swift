//
//  AuthManager.swift
//  Evenly
//
//  Authentication manager using Python backend
//

import Foundation
import SwiftUI
import Combine

class AuthManager: ObservableObject {
    @Published var user: UserResponse?
    @Published var userProfile: UserProfile?

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

    init() {
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
                    username: user.displayName,
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

                let (data, response) = try await URLSession.shared.data(for: request)

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
                    throw APIError.serverError(httpResponse.statusCode)
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
                        username: user.displayName,
                        email: user.email,
                        phone: nil,
                        avatarUrl: user.avatarUrl
                    )
                    self.isLoading = false
                }
                completion(nil)

            } catch {
                await MainActor.run {
                    self.loginError = error.localizedDescription
                    self.isLoading = false
                }
                completion(error)
            }
        }
    }

    // MARK: - Register

    func signUp(
        username: String,
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
                var formFields: [String: String] = [
                    "email": email,
                    "password": password,
                    "code": verificationCode,
                    "display_name": username
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
                        username: user.displayName,
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
                    case .serverError(let code) where code == 400:
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
                    completion(APIError.serverError(httpResponse.statusCode))
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
        guard let user = user else {
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
                    self.userProfile = UserProfile(
                        id: updatedUser.id,
                        username: updatedUser.displayName,
                        email: updatedUser.email,
                        phone: self.userProfile?.phone,
                        avatarUrl: updatedUser.avatarUrl
                    )
                }
                completion(nil)

            } catch {
                completion(error)
            }
        }
    }

    func updateUsername(_ username: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let userUpdate = UserUpdate(displayName: username, avatarUrl: nil)
                let updatedUser: UserResponse = try await api.put(APIEndpoints.updateUser, body: userUpdate)

                await MainActor.run {
                    self.user = updatedUser
                    self.userProfile = UserProfile(
                        id: updatedUser.id,
                        username: updatedUser.displayName,
                        email: updatedUser.email,
                        phone: self.userProfile?.phone,
                        avatarUrl: updatedUser.avatarUrl
                    )
                }
                completion(nil)

            } catch {
                completion(error)
            }
        }
    }

    // MARK: - Logout

    func signOut() {
        api.clearToken()
        self.user = nil
        self.userProfile = nil
    }

    // MARK: - Password Reset

    func resetPassword(email: String, completion: @escaping (Error?) -> Void) {
        // Not implemented in backend yet
        completion(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "暂不支持密码重置"]))
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

    // MARK: - Delete Account (placeholder - requires backend support)

    func deleteAccount(completion: @escaping (Error?) -> Void) {
        // This feature requires backend support
        completion(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "删除账户功能暂不支持"]))
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
    let email: String?
    let phone: String?
    let avatarUrl: String?

    var displayName: String {
        username ?? email?.components(separatedBy: "@").first ?? "用户"
    }

    var avatarImage: UIImage? {
        nil // Will be loaded from URL
    }
}
