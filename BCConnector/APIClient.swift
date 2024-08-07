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
