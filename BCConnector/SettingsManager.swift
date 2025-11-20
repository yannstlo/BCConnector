import Foundation
import Security

// Fallback Keychain helper to avoid target-membership issues if the standalone file isn't included.
// If another KeychainHelper exists in the target, this won't conflict because of the type name check below.
#if !canImport(BCConnector_KeychainHelper)
enum KeychainError: Error { case unexpectedStatus(OSStatus); case dataConversionFailed }
struct KeychainHelper {
    static func set(_ value: String?, for key: String, service: String = Bundle.main.bundleIdentifier ?? "BCConnector") throws {
        let account = key
        let service = service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard let value = value else { return }
        guard let data = value.data(using: .utf8) else { throw KeychainError.dataConversionFailed }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }
    static func get(_ key: String, service: String = Bundle.main.bundleIdentifier ?? "BCConnector") throws -> String? {
        let account = key
        let service = service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }
    static func delete(_ key: String, service: String = Bundle.main.bundleIdentifier ?? "BCConnector") {
        let account = key
        let service = service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
#endif

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var clientId: String {
        didSet { UserDefaults.standard.set(clientId, forKey: "clientId") }
    }
    @Published var clientSecret: String {
        didSet { try? KeychainHelper.set(clientSecret, for: "clientSecret") }
    }
    @Published var tenantId: String {
        didSet { UserDefaults.standard.set(tenantId, forKey: "tenantId") }
    }
    @Published var companyId: String {
        didSet { UserDefaults.standard.set(companyId, forKey: "companyId") }
    }
    @Published var environment: String {
        didSet { UserDefaults.standard.set(environment, forKey: "environment") }
    }
    @Published var redirectUri: String {
        didSet { UserDefaults.standard.set(redirectUri, forKey: "redirectUri") }
    }
    @Published var openAIAPIKey: String {
        didSet { try? KeychainHelper.set(openAIAPIKey, for: "openAIAPIKey") }
    }

    // Business Central API namespace pieces (publisher/group/version) to avoid hardcoding
    @Published var apiPublisher: String {
        didSet { UserDefaults.standard.set(apiPublisher, forKey: "apiPublisher") }
    }
    @Published var apiGroup: String {
        didSet { UserDefaults.standard.set(apiGroup, forKey: "apiGroup") }
    }
    @Published var apiVersion: String {
        didSet { UserDefaults.standard.set(apiVersion, forKey: "apiVersion") }
    }

    // Helper to build the Business Central Customers endpoint using current settings
    var customersURL: URL? {
        // Expecting: https://api.businesscentral.dynamics.com/v2.0/{tenantId}/{environment}/api/{publisher}/{group}/{version}/companies({companyId})/customers
        guard !tenantId.isEmpty, !environment.isEmpty, !companyId.isEmpty, !apiPublisher.isEmpty, !apiGroup.isEmpty, !apiVersion.isEmpty else { return nil }
        let path = "https://api.businesscentral.dynamics.com/v2.0/\(tenantId)/\(environment)/api/\(apiPublisher)/\(apiGroup)/\(apiVersion)/companies(\(companyId))/customers"
        return URL(string: path)
    }
    
    private init() {
        self.clientId = UserDefaults.standard.string(forKey: "clientId") ?? ""
        self.clientSecret = (try? KeychainHelper.get("clientSecret")) ?? UserDefaults.standard.string(forKey: "clientSecret") ?? ""
        self.tenantId = UserDefaults.standard.string(forKey: "tenantId") ?? ""
        self.companyId = UserDefaults.standard.string(forKey: "companyId") ?? ""
        self.environment = UserDefaults.standard.string(forKey: "environment") ?? ""
        self.redirectUri = UserDefaults.standard.string(forKey: "redirectUri") ?? "ca.yann.bcconnector.auth://auth"
        self.openAIAPIKey = (try? KeychainHelper.get("openAIAPIKey")) ?? UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        self.apiPublisher = UserDefaults.standard.string(forKey: "apiPublisher") ?? "yann"
        self.apiGroup = UserDefaults.standard.string(forKey: "apiGroup") ?? "demo"
        self.apiVersion = UserDefaults.standard.string(forKey: "apiVersion") ?? "v1.0"
    }
}
