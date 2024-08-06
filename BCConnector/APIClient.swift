import Foundation
import SwiftUI
import Combine

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError(String)
    case authenticationError
    case networkError(String)
    case httpError(Int)
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
    
    func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)/\(apiVersion)/\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        let accessToken = try await AuthenticationManager.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("Sending request to URL: \(url)")
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError(error.localizedDescription)
            }
        case 400:
            if let errorData = String(data: data, encoding: .utf8) {
                print("HTTP 400 Error. Response body: \(errorData)")
            }
            throw APIError.httpError(400)
        case 401:
            throw APIError.authenticationError
        default:
            if let errorData = String(data: data, encoding: .utf8) {
                print("HTTP \(httpResponse.statusCode) Error. Response body: \(errorData)")
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
}
