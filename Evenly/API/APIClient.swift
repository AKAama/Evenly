//
//  APIClient.swift
//  Evenly
//
//  Unified API client for Python backend with JWT token management
//

import Foundation
import Combine
import Security

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int, String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please login again"
        case .serverError(let code, let detail):
            return detail ?? "Server error: \(code)"
        case .decodingError:
            return "Failed to parse response"
        case .networkError(let error):
            return error.localizedDescription
        }
    }

    static func server(statusCode: Int, data: Data) -> APIError {
        let detail: String?
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = object["detail"] {
            if let message = value as? String {
                detail = message
            } else if let issues = value as? [[String: Any]] {
                let messages = issues.compactMap { $0["msg"] as? String }
                detail = messages.isEmpty ? nil : messages.joined(separator: "\n")
            } else {
                detail = nil
            }
        } else {
            detail = nil
        }
        return .serverError(statusCode, detail)
    }
}

final class APIClient: ObservableObject {
    static let shared = APIClient()

    static let baseURL: String = {
        if let configuredURL = Bundle.main.object(forInfoDictionaryKey: "EVENLY_API_BASE_URL") as? String,
           !configuredURL.isEmpty,
           !configuredURL.hasPrefix("$(") {
            return configuredURL
        }

        #if DEBUG
        print("debug")
        return "http://192.168.124.14:8000"
        #else
        print("prod")
        return "https://evenly.ismyh.cn/api"
        #endif
    }()

    @Published private(set) var isAuthenticated = false
    private var token: String?
    private let tokenKey = "JWT_Token"
    private let tokenStore = KeychainTokenStore(service: "cn.evenly.api")

    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractional = DateFormatter()
            fractional.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            fractional.locale = Locale(identifier: "en_US_POSIX")

            let seconds = DateFormatter()
            seconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            seconds.locale = Locale(identifier: "en_US_POSIX")

            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"
            dateOnly.locale = Locale(identifier: "en_US_POSIX")

            if let date = fractional.date(from: value) ?? seconds.date(from: value) ?? dateOnly.date(from: value) ?? ISO8601DateFormatter().date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return decoder
    }()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.token = tokenStore.readToken(account: tokenKey)
        if token == nil, let legacyToken = UserDefaults.standard.string(forKey: tokenKey) {
            token = legacyToken
            tokenStore.saveToken(legacyToken, account: tokenKey)
            UserDefaults.standard.removeObject(forKey: tokenKey)
        }
        self.isAuthenticated = token != nil
    }

    // MARK: - Token Management

    func setToken(_ newToken: String?) {
        token = newToken
        if let token = token {
            tokenStore.saveToken(token, account: tokenKey)
        } else {
            tokenStore.deleteToken(account: tokenKey)
            UserDefaults.standard.removeObject(forKey: tokenKey)
        }
        isAuthenticated = token != nil
    }

    func clearToken() {
        setToken(nil)
    }

    var currentToken: String? {
        token
    }

    // MARK: - Request Methods

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = true,
        contentType: ContentType = .json
    ) async throws -> T {
        guard let url = URL(string: "\(Self.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Set headers
        request.setValue(contentType.headerValue, forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = token else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Set body
        if let body = body {
            if contentType == .formData {
                // Handle form data separately
                if let formBody = body as? FormDataBody {
                    request.httpBody = formBody.data
                }
            } else {
                request.httpBody = try JSONEncoder().encode(body)
            }
        }

        do {
            let (data, response) = try await session.data(for: request)

            // Debug logging
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📡 API Response - Status: \((response as? HTTPURLResponse)?.statusCode ?? 0), Body: \(responseString)")

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                if data.isEmpty, T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }

                do {
                    return try Self.jsonDecoder.decode(T.self, from: data)
                } catch {
                    print("📡 JSON Decode Error: \(error)")
                    throw APIError.decodingError(error)
                }
            case 401:
                throw APIError.unauthorized
            default:
                throw APIError.server(statusCode: httpResponse.statusCode, data: data)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    func requestWithFormData<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .post,
        formFields: [String: String],
        files: [FileUpload] = [],
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(Self.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = token else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        // Add form fields
        for (key, value) in formFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add files
        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return try Self.jsonDecoder.decode(T.self, from: data)
            case 401:
                throw APIError.unauthorized
            default:
                throw APIError.server(statusCode: httpResponse.statusCode, data: data)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Convenience Methods

    func get<T: Decodable>(_ endpoint: String, requiresAuth: Bool = true) async throws -> T {
        try await request(endpoint: endpoint, method: .get, requiresAuth: requiresAuth)
    }

    func post<T: Decodable>(_ endpoint: String, body: Encodable? = nil, requiresAuth: Bool = true) async throws -> T {
        try await request(endpoint: endpoint, method: .post, body: body, requiresAuth: requiresAuth)
    }

    func put<T: Decodable>(_ endpoint: String, body: Encodable? = nil, requiresAuth: Bool = true) async throws -> T {
        try await request(endpoint: endpoint, method: .put, body: body, requiresAuth: requiresAuth)
    }

    func delete(_ endpoint: String, requiresAuth: Bool = true) async throws {
        let _: EmptyResponse = try await request(endpoint: endpoint, method: .delete, requiresAuth: requiresAuth)
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

enum ContentType {
    case json
    case formData
    case formURLEncoded

    var headerValue: String {
        switch self {
        case .json:
            return "application/json"
        case .formData:
            return "multipart/form-data"
        case .formURLEncoded:
            return "application/x-www-form-urlencoded"
        }
    }
}

struct FileUpload {
    let fieldName: String
    let filename: String
    let mimeType: String
    let data: Data
}

struct FormDataBody: Encodable {
    let data: Data
}

struct EmptyResponse: Decodable {}

final class KeychainTokenStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func readToken(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func saveToken(_ token: String, account: String) {
        let data = Data(token.utf8)
        var query = baseQuery(account: account)
        let attributes = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func deleteToken(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

struct FormDataBuilder {
    private var fields: [String: String] = [:]
    private var files: [FileUpload] = []

    mutating func addField(_ key: String, value: String) {
        fields[key] = value
    }

    mutating func addFile(_ fieldName: String, filename: String, mimeType: String, data: Data) {
        files.append(FileUpload(fieldName: fieldName, filename: filename, mimeType: mimeType, data: data))
    }

    var fieldsDict: [String: String] {
        fields
    }

    var filesArray: [FileUpload] {
        files
    }
}
