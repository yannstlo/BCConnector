import Foundation
import SwiftUI
import Security
import CryptoKit

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @ObservedObject private var settings = SettingsManager.shared
    
    private var redirectUri: String {
        settings.redirectUri
    }
    private var oauthTenant: String {
        let tenant = settings.tenantId.trimmingCharacters(in: .whitespacesAndNewlines)
        return tenant.isEmpty ? "organizations" : tenant
    }
    private let scopes = [
        "openid",
        "profile",
        "offline_access",
        "https://api.businesscentral.dynamics.com/user_impersonation"
    ]
    private var scope: String {
        scopes.joined(separator: " ")
    }
    private var codeVerifier: String?
    private var authState: String?
    
    private var authorizationEndpoint: String {
        "https://login.microsoftonline.com/\(oauthTenant)/oauth2/v2.0/authorize"
    }
    private var tokenEndpoint: String {
        "https://login.microsoftonline.com/\(oauthTenant)/oauth2/v2.0/token"
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
            try? KeychainHelper.set(accessToken, for: "accessToken")
        }
    }
    private var refreshToken: String? {
        didSet {
            try? KeychainHelper.set(refreshToken, for: "refreshToken")
        }
    }
    private var expirationDate: Date? {
        didSet {
            UserDefaults.standard.set(expirationDate, forKey: "expirationDate")
        }
    }
    
    private func loadTokens() {
        accessToken = (try? KeychainHelper.get("accessToken")) ?? UserDefaults.standard.string(forKey: "accessToken")
        refreshToken = (try? KeychainHelper.get("refreshToken")) ?? UserDefaults.standard.string(forKey: "refreshToken")
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
        if settings.networkLoggingEnabled {
            print("[Auth] Starting authentication…")
            print("[Auth] Client ID: \(settings.clientId)")
            print("[Auth] Tenant ID: \(settings.tenantId)")
            print("[Auth] OAuth Tenant: \(oauthTenant)")
            print("[Auth] Redirect URI: \(redirectUri)")
            print("[Auth] Scope: \(scope)")
        }
        
        var components = URLComponents(string: authorizationEndpoint)
        let verifier = Self.generateCodeVerifier()
        codeVerifier = verifier
        let state = UUID().uuidString
        authState = state
        let challenge = Self.codeChallenge(for: verifier)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: settings.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "prompt", value: "login"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: scope)
        ]
        
        guard let authURL = components?.url else {
            print("Invalid authorization URL")
            return nil
        }
        
        if settings.networkLoggingEnabled { print("[Auth] URL: \(authURL)") }
        return authURL
    }

    func handleRedirect(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw APIError.authenticationError(nil)
        }

        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            let description = components.queryItems?.first(where: { $0.name == "error_description" })?.value
            throw APIError.authenticationError(Self.authErrorResponse(code: error, message: description ?? error))
        }

        if let expectedState = authState,
           let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
           returnedState != expectedState {
            throw APIError.authenticationError(Self.authErrorResponse(
                code: "state_mismatch",
                message: "Authentication state mismatch."
            ))
        }

        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw APIError.authenticationError(nil)
        }

        _ = try await exchangeCodeForTokens(code: code)
        await MainActor.run {
            self.isAuthenticated = true
        }
        authState = nil
        codeVerifier = nil
    }

    func logout() {
        self.accessToken = nil
        self.refreshToken = nil
        self.expirationDate = nil
        UserDefaults.standard.removeObject(forKey: "accessToken")
        UserDefaults.standard.removeObject(forKey: "refreshToken")
        UserDefaults.standard.removeObject(forKey: "expirationDate")
        KeychainHelper.delete("accessToken")
        KeychainHelper.delete("refreshToken")
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
        var parameters = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "client_id": settings.clientId,
            "scope": scope
        ]
        if let verifier = codeVerifier {
            parameters["code_verifier"] = verifier
        }
        
        let bodyData = formEncodedBody(from: parameters)
        
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        if settings.networkLoggingEnabled {
            print("[Auth] Token request: \(request.url?.absoluteString ?? "nil")")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        if settings.networkLoggingEnabled { print("[Auth] Token status: \(httpResponse.statusCode)") }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode, nil)
        }
        
        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.expirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            updateTenantIdIfPossible(from: tokenResponse.accessToken)
            
            // If we didn't receive a refresh token, we should clear any existing one
            if tokenResponse.refreshToken == nil {
                self.refreshToken = nil
            }
            
            return tokenResponse.accessToken
        } catch {
            if settings.networkLoggingEnabled { print("[Auth] Token decode error: \(error)") }
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    private func refreshAccessToken(refreshToken: String) async throws -> String {
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": settings.clientId,
            "scope": scope
        ]
        
        let bodyData = formEncodedBody(from: parameters)
        
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.expirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        updateTenantIdIfPossible(from: tokenResponse.accessToken)
        
        return tokenResponse.accessToken
    }

    private static func generateCodeVerifier(length: Int = 64) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func formEncodedBody(from parameters: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = parameters
            .sorted(by: { $0.key < $1.key })
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let percentEncodedQuery = components.percentEncodedQuery else {
            return nil
        }

        return Data(percentEncodedQuery.utf8)
    }

    private static func authErrorResponse(code: String, message: String) -> ErrorResponse {
        ErrorResponse(error: ErrorDetails(code: code, message: message))
    }

    private func updateTenantIdIfPossible(from accessToken: String) {
        guard let tid = Self.jwtClaim("tid", from: accessToken), !tid.isEmpty else { return }
        if settings.tenantId != tid {
            DispatchQueue.main.async {
                self.settings.tenantId = tid
            }
        }
    }

    private static func jwtClaim(_ key: String, from token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder != 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json[key] as? String
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}
