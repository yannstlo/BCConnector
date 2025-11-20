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

    /// Attempts to discover available environments. Business Central does not provide a simple public list endpoint.
    /// This helper probes a small set of common environment names and returns those that respond successfully.
    /// You can replace this with a true discovery mechanism if you have one available.
    func fetchEnvironments(candidates: [String] = ["Production", "Sandbox", "Sandbox1", "Sandbox2"]) async -> [BCEnvironment] {
        await withTaskGroup(of: BCEnvironment?.self) { group in
            for env in candidates {
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    let probeEndpoint = "api/v2.0/companies?$top=1"
                    let originalEnv = self.settings.environment
                    // Temporarily set environment to probe
                    await MainActor.run { self.settings.environment = env }
                    defer { Task { await MainActor.run { self.settings.environment = originalEnv } } }
                    do {
                        let _: BusinessCentralResponse<Company> = try await self.fetch(probeEndpoint)
                        return BCEnvironment(id: env.lowercased(), name: env, displayName: env)
                    } catch {
                        return nil
                    }
                }
            }
            var results: [BCEnvironment] = []
            for await env in group {
                if let env = env { results.append(env) }
            }
            return results.sorted { $0.name < $1.name }
        }
    }

    /// Fetches companies for the current tenant/environment using the standard BC endpoint.
    func fetchCompanies() async throws -> [Company] {
        let response: BusinessCentralResponse<Company> = try await fetch("api/v2.0/companies")
        return response.value
    }
    
    /// Fetches a BusinessCentralResponse and follows a single @odata.nextLink if present, returning concatenated values.
    func fetchPaged<T: Decodable & Identifiable>(_ endpoint: String) async throws -> [T] where T: Codable {
        let response: BusinessCentralResponse<T> = try await fetch(endpoint)
        var items = response.value
        // Try to parse a nextLink if present in the raw response
        // We re-fetch the raw data to check for nextLink without creating a new model type
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else { return items }
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
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        let accessToken = try await AuthenticationManager.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("Sending request to URL: \(url)")
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Access Token: \(accessToken)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        print("Response status code: \(httpResponse.statusCode)")
        if let responseBody = String(data: data, encoding: .utf8) {
            print("Response body: \(responseBody)")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError(error.localizedDescription)
            }
        case 400:
            let errorResponse = try? decodeErrorResponse(from: data)
            print("Bad Request error: \(errorResponse?.error.message ?? "Unknown error")")
            print("Error details: \(String(data: data, encoding: .utf8) ?? "No data")")
            throw APIError.httpError(400, errorResponse)
        case 401:
            print("Authentication error: The access token might be invalid or expired.")
            throw APIError.authenticationError(try? decodeErrorResponse(from: data))
        case 403:
            print("Authorization error: The user might not have permission to access this resource.")
            throw APIError.httpError(403, try? decodeErrorResponse(from: data))
        case 404:
            print("Not Found error: The requested resource might not exist.")
            throw APIError.httpError(404, try? decodeErrorResponse(from: data))
        default:
            throw APIError.httpError(httpResponse.statusCode, try? decodeErrorResponse(from: data))
        }
    }
    
    private func decodeErrorResponse(from data: Data) throws -> ErrorResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(ErrorResponse.self, from: data)
    }
}

struct ErrorResponse: Codable {
    let error: ErrorDetails
}

struct ErrorDetails: Codable {
    let code: String
    let message: String
}
