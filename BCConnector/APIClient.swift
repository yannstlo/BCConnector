import Foundation
import SwiftUI
import Combine

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError(String)
    case authenticationError(ErrorResponse?)
    case networkError(String)
    case httpError(Int, ErrorResponse?)
    case tokenResponseError(String)
}

class APIClient: ObservableObject {
    static let shared = APIClient()
    private init() {}
    
    private let settings = SettingsManager.shared
    private let authManager = AuthenticationManager.shared
    
    private var baseURL: String {
        "https://api.businesscentral.dynamics.com/v2.0/\(settings.tenantId)/\(settings.environment)"
    }

    // api root: either custom namespace (premium) or default v2.0
    private var apiRoot: String {
        if settings.useCustomNamespace,
           !settings.apiPublisher.isEmpty,
           !settings.apiGroup.isEmpty,
           !settings.apiVersion.isEmpty {
            return "api/\(settings.apiPublisher)/\(settings.apiGroup)/\(settings.apiVersion)"
        }
        return "api/v2.0"
    }

    func companiesPath(_ suffix: String) -> String {
        return "\(apiRoot)/companies(\(settings.companyId))/\(suffix)"
    }
    private let apiVersion = "v2.0"

    // MARK: - Discovery Helpers
    struct BCEnvironment: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let displayName: String
    }

    struct Company: Identifiable, Codable, Hashable {
        let id: String
        let name: String
    }

    /// Attempts to discover available environments by probing common names without mutating app state.
    /// Note: The most reliable way is the Business Central Admin API (requires additional permissions).
    func fetchEnvironments(candidates: [String]? = nil) async -> [BCEnvironment] {
        let defaults: [String] = {
            var arr = ["Production", "Sandbox"]
            arr.append(contentsOf: (1...10).map { "Sandbox\($0)" })
            arr.append(contentsOf: ["Preview", "Staging", "Test"]) // best-effort extras
            return arr
        }()
        let names = candidates ?? defaults

        // Build requests without changing SettingsManager.environment
        return await withTaskGroup(of: BCEnvironment?.self) { group in
            for env in names {
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    guard !self.settings.tenantId.isEmpty else { return nil }
                    let urlString = "https://api.businesscentral.dynamics.com/v2.0/\(self.settings.tenantId)/\(env)/api/v2.0/companies?$top=1"
                    guard let url = URL(string: urlString) else { return nil }
                    do {
                        var req = URLRequest(url: url)
                        let token = try await self.authManager.getAccessToken()
                        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        req.setValue("application/json", forHTTPHeaderField: "Accept")
                        let (_, resp) = try await URLSession.shared.data(for: req)
                        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                            return nil
                        }
                        return BCEnvironment(id: env.lowercased(), name: env, displayName: env)
                    } catch {
                        return nil
                    }
                }
            }
            var results: [BCEnvironment] = []
            for await env in group { if let env = env { results.append(env) } }
            return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Fetches companies for the current tenant/environment using the standard BC endpoint.
    func fetchCompanies() async throws -> [Company] {
        let response: BusinessCentralResponse<Company> = try await fetch("\(apiRoot)/companies")
        return response.value
    }
    
    /// Fetch companies for a specific environment name without mutating SettingsManager.
    func fetchCompanies(inEnvironment environment: String) async throws -> [Company] {
        guard !settings.tenantId.isEmpty else { return [] }
        let urlString = "https://api.businesscentral.dynamics.com/v2.0/\(settings.tenantId)/\(environment)/\(apiRoot)/companies"
        guard let url = URL(string: urlString) else { return [] }
        var request = URLRequest(url: url)
        let accessToken = try await authManager.getAccessToken()
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }
        let decoder = JSONDecoder()
        let resp = try decoder.decode(BusinessCentralResponse<Company>.self, from: data)
        return resp.value
    }
    
    /// Fetches a BusinessCentralResponse and follows a single @odata.nextLink if present, returning concatenated values.
    func fetchPaged<T: Decodable & Identifiable>(_ endpoint: String) async throws -> [T] where T: Codable {
        let response: BusinessCentralResponse<T> = try await fetch(endpoint)
        var items = response.value
        // Try to parse a nextLink if present in the raw response
        // We re-fetch the raw data to check for nextLink without creating a new model type
        let full = "\(baseURL)/\(endpoint)"
        let url: URL
        if let q = full.firstIndex(of: "?") {
            let path = String(full[..<q])
            let query = String(full[full.index(after: q)...])
            let enc = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            guard let u = URL(string: path + "?" + enc) else { return items }
            url = u
        } else {
            guard let u = URL(string: full) else { return items }
            url = u
        }
        var request = URLRequest(url: url)
        let accessToken = try await authManager.getAccessToken()
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let nextLink = json["@odata.nextLink"] as? String {
            // nextLink is absolute; request it and append results
            let (nextData, _) = try await URLSession.shared.data(from: URL(string: nextLink)!)
            let nextPage = try JSONDecoder().decode(BusinessCentralResponse<T>.self, from: nextData)
            items.append(contentsOf: nextPage.value)
        }
        return items
    }
    
    func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        let full = "\(baseURL)/\(endpoint)"
        let url: URL
        if let q = full.firstIndex(of: "?") {
            let path = String(full[..<q])
            let query = String(full[full.index(after: q)...])
            let enc = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            guard let u = URL(string: path + "?" + enc) else { throw APIError.invalidURL }
            url = u
        } else {
            guard let u = URL(string: full) else { throw APIError.invalidURL }
            url = u
        }
        
        let accessToken = try await AuthenticationManager.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if settings.networkLoggingEnabled {
            print("[API] GET \(url.absoluteString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        if settings.networkLoggingEnabled {
            print("[API] Status: \(httpResponse.statusCode)")
            if settings.networkLogBodies, let body = String(data: data, encoding: .utf8) {
                let snippet = body.count > 4000 ? String(body.prefix(4000)) + "…(truncated)" : body
                print("[API] Body: \n\(snippet)")
            }
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                if settings.networkLoggingEnabled { print("[API] Decoding error: \(error)") }
                throw APIError.decodingError(error.localizedDescription)
            }
        case 400:
            let errorResponse = try? decodeErrorResponse(from: data)
            if settings.networkLoggingEnabled {
                print("[API] 400 Bad Request: \(errorResponse?.error.message ?? "Unknown error")")
            }
            throw APIError.httpError(400, errorResponse)
        case 401:
            if settings.networkLoggingEnabled { print("[API] 401 Unauthorized") }
            throw APIError.authenticationError(try? decodeErrorResponse(from: data))
        case 403:
            if settings.networkLoggingEnabled { print("[API] 403 Forbidden") }
            throw APIError.httpError(403, try? decodeErrorResponse(from: data))
        case 404:
            if settings.networkLoggingEnabled { print("[API] 404 Not Found") }
            throw APIError.httpError(404, try? decodeErrorResponse(from: data))
        default:
            if settings.networkLoggingEnabled { print("[API] HTTP \(httpResponse.statusCode)") }
            throw APIError.httpError(httpResponse.statusCode, try? decodeErrorResponse(from: data))
        }
    }
    
    private func decodeErrorResponse(from data: Data) throws -> ErrorResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(ErrorResponse.self, from: data)
    }
    
    // Fetch raw data from a URL with Authorization header (for media like item pictures)
    func authorizedData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        let accessToken = try await AuthenticationManager.shared.getAccessToken()
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.networkError("Media request failed")
        }
        return data
    }

    // MARK: - POST helper (returns created resource)
    func post<T: Decodable, Body: Encodable>(_ endpoint: String, body: Body) async throws -> T {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw APIError.invalidURL
        }
        let accessToken = try await AuthenticationManager.shared.getAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let bodyData = try JSONEncoder().encode(body)
        request.httpBody = bodyData

        if settings.networkLoggingEnabled {
            print("[API] POST \(url.absoluteString)")
            if settings.networkLogBodies, let bodyStr = String(data: bodyData, encoding: .utf8) {
                print("[API] Body: \n\(bodyStr)")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.httpError(status, try? decodeErrorResponse(from: data))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - PATCH helper
    func patch<Body: Encodable>(_ endpoint: String, body: Body) async throws {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw APIError.invalidURL
        }
        let accessToken = try await AuthenticationManager.shared.getAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Allow unconditional update if ETag unknown
        request.setValue("*", forHTTPHeaderField: "If-Match")
        let data = try JSONEncoder().encode(body)
        request.httpBody = data

        if settings.networkLoggingEnabled {
            print("[API] PATCH \(url.absoluteString)")
            if settings.networkLogBodies, let bodyStr = String(data: data, encoding: .utf8) {
                print("[API] Body: \n\(bodyStr)")
            }
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.httpError(status, nil)
        }
    }

    // MARK: - DELETE helper
    func delete(_ endpoint: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw APIError.invalidURL
        }
        let accessToken = try await AuthenticationManager.shared.getAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("*", forHTTPHeaderField: "If-Match")

        if settings.networkLoggingEnabled {
            print("[API] DELETE \(url.absoluteString)")
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.httpError(status, nil)
        }
    }
}

struct ErrorResponse: Codable {
    let error: ErrorDetails
}

struct ErrorDetails: Codable {
    let code: String
    let message: String
}
