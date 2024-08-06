import Foundation
import SwiftUI

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @ObservedObject private var settings = SettingsManager.shared
    
    private let redirectUri = "ca.yann.bcconnector.auth://oauth2redirect"
    private let scope = "https://api.businesscentral.dynamics.com/.default"
    
    private var authorizationEndpoint: String {
        "https://login.microsoftonline.com/\(settings.tenantId)/oauth2/v2.0/authorize"
    }
    private var tokenEndpoint: String {
        "https://login.microsoftonline.com/\(settings.tenantId)/oauth2/v2.0/token"
    }
    private var apiEndpoint: String {
        "https://api.businesscentral.dynamics.com/v2.0/\(settings.environment)/api/v2.0"
    }
    
    private init() {}
    
    @Published private(set) var isAuthenticated = false
    
    private var accessToken: String?
    private var refreshToken: String?
    private var expirationDate: Date?
    
    func getAccessToken() async throws -> String {
        if let token = accessToken, let expirationDate = expirationDate, expirationDate > Date() {
            return token
        }
        
        if let refreshToken = refreshToken {
            return try await refreshAccessToken(refreshToken: refreshToken)
        }
        
        return try await performInitialAuthentication()
    }
    
    func startAuthentication() -> URL? {
        let updatedScope = "\(apiEndpoint)/.default"
        guard let encodedRedirectUri = redirectUri.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
              let encodedScope = updatedScope.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
              let authURL = URL(string: "\(authorizationEndpoint)?client_id=\(settings.clientId)&redirect_uri=\(encodedRedirectUri)&response_type=code&scope=\(encodedScope)") else {
            print("Invalid authorization URL")
            return nil
        }
        
        return authURL
    }

    func handleRedirect(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw APIError.authenticationError
        }

        _ = try await exchangeCodeForTokens(code: code)
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
    }
    
    private func performInitialAuthentication() async throws -> String {
        // In a real app, you'd initiate the OAuth flow here,
        // typically by opening a web view for user login
        // For this example, we'll simulate it:
        
        // Simulate getting an authorization code
        let authCode = "SIMULATED_AUTH_CODE"
        
        // Exchange auth code for tokens
        return try await exchangeCodeForTokens(code: authCode)
    }
    
    private func exchangeCodeForTokens(code: String) async throws -> String {
        // Construct the token request
        var components = URLComponents(string: tokenEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "client_id", value: settings.clientId),
            URLQueryItem(name: "client_secret", value: settings.clientSecret)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.expirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        return tokenResponse.accessToken
    }
    
    private func refreshAccessToken(refreshToken: String) async throws -> String {
        var components = URLComponents(string: tokenEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: settings.clientId),
            URLQueryItem(name: "client_secret", value: settings.clientSecret)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.expirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        return tokenResponse.accessToken
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}
