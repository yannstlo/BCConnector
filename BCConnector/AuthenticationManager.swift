import Foundation
import SwiftUI

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @ObservedObject private var settings = SettingsManager.shared
    
    private var redirectUri: String {
        settings.redirectUri
    }
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
    
    private init() {
        loadTokens()
    }
    
    @Published private(set) var isAuthenticated = false
    
    private var accessToken: String? {
        didSet {
            UserDefaults.standard.set(accessToken, forKey: "accessToken")
        }
    }
    private var refreshToken: String? {
        didSet {
            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
        }
    }
    private var expirationDate: Date? {
        didSet {
            UserDefaults.standard.set(expirationDate, forKey: "expirationDate")
        }
    }
    
    private func loadTokens() {
        accessToken = UserDefaults.standard.string(forKey: "accessToken")
        refreshToken = UserDefaults.standard.string(forKey: "refreshToken")
        expirationDate = UserDefaults.standard.object(forKey: "expirationDate") as? Date
        isAuthenticated = accessToken != nil
    }
    
    func getAccessToken() async throws -> String {
        if let token = accessToken, let expirationDate = expirationDate, expirationDate > Date() {
            return token
        }
        
        if let refreshToken = refreshToken {
            do {
                return try await refreshAccessToken(refreshToken: refreshToken)
            } catch {
                // If refresh fails, fall back to initial authentication
                print("Token refresh failed: \(error)")
            }
        }
        
        return try await performInitialAuthentication()
    }
    
    func startAuthentication() -> URL? {
        print("Starting authentication...")
        print("Client ID: \(settings.clientId)")
        print("Tenant ID: \(settings.tenantId)")
        print("Redirect URI: \(redirectUri)")
        print("Scope: \(scope)")
        
        var components = URLComponents(string: authorizationEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: settings.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope)
        ]
        
        guard let authURL = components?.url else {
            print("Invalid authorization URL")
            return nil
        }
        
        print("Authentication URL: \(authURL)")
        return authURL
    }

    // Helper function to percent-encode the client ID
    private func percentEncodedClientId() -> String {
        let allowedCharacters = CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[]").inverted
        return settings.clientId.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? settings.clientId
    }

    func handleRedirect(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw APIError.authenticationError
        }

        _ = try await exchangeCodeForTokens(code: code)
        await MainActor.run {
            self.isAuthenticated = true
        }
    }

    func logout() {
        self.accessToken = nil
        self.refreshToken = nil
        self.expirationDate = nil
        UserDefaults.standard.removeObject(forKey: "accessToken")
        UserDefaults.standard.removeObject(forKey: "refreshToken")
        UserDefaults.standard.removeObject(forKey: "expirationDate")
        DispatchQueue.main.async {
            self.isAuthenticated = false
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
        
        print("Token request URL: \(request.url?.absoluteString ?? "nil")")
        print("Token request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        print("Token response status code: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Token response body: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.expirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            
            return tokenResponse.accessToken
        } catch {
            print("Error decoding token response: \(error)")
            throw APIError.decodingError(error.localizedDescription)
        }
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
