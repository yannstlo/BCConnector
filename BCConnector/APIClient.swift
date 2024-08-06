import Foundation
import SwiftUI
import BCConnector

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case authenticationError
}

class APIClient: ObservableObject {
    static let shared = APIClient()
    private init() {}
    
    @ObservedObject private var settings = SettingsManager.shared
    
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.authenticationError
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}
