//
//  APIClient.swift
//  Evenly
//
//  Unified API client for Python backend with JWT token management
//

import Foundation
import Combine

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int)
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
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to parse response"
        case .networkError(let error):
            return error.localizedDescription
        }
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
        return "http://192.168.124.14:8000"
        #else
        return "https://evenly.ismyh.cn"
        #endif
    }()

    @Published private(set) var isAuthenticated = false
    private var token: String?
    private let tokenKey = "JWT_Token"

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

            if let date = fractional.date(from: value) ?? seconds.date(from: value) ?? ISO8601DateFormatter().date(from: value) {
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

        // Load token from UserDefaults
        self.token = UserDefaults.standard.string(forKey: tokenKey)
        self.isAuthenticated = token != nil
    }

    // MARK: - Token Management

    func setToken(_ newToken: String?) {
        token = newToken
        if let token = token {
            UserDefaults.standard.set(token, forKey: tokenKey)
        } else {
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
                do {
                    return try Self.jsonDecoder.decode(T.self, from: data)
                } catch {
                    print("📡 JSON Decode Error: \(error)")
                    throw APIError.decodingError(error)
                }
            case 401:
                throw APIError.unauthorized
            default:
                throw APIError.serverError(httpResponse.statusCode)
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
                throw APIError.serverError(httpResponse.statusCode)
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

struct FormDataBody {
    let data: Data
}

struct EmptyResponse: Decodable {}

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
