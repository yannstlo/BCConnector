import Foundation

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var clientId: String {
        didSet { UserDefaults.standard.set(clientId, forKey: "clientId") }
    }
    @Published var clientSecret: String {
        didSet { UserDefaults.standard.set(clientSecret, forKey: "clientSecret") }
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
    
    private init() {
        self.clientId = UserDefaults.standard.string(forKey: "clientId") ?? ""
        self.clientSecret = UserDefaults.standard.string(forKey: "clientSecret") ?? ""
        self.tenantId = UserDefaults.standard.string(forKey: "tenantId") ?? ""
        self.companyId = UserDefaults.standard.string(forKey: "companyId") ?? ""
        self.environment = UserDefaults.standard.string(forKey: "environment") ?? ""
        self.redirectUri = UserDefaults.standard.string(forKey: "redirectUri") ?? "ca.yann.bcconnector.auth://auth"
    }
}
