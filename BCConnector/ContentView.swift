import SwiftUI
import AuthenticationServices
import Foundation

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var isShowingSettings = false
    @State private var authContextProvider: AuthContextProvider?
    @State private var selectedTab = 0
    @State private var authSession: ASWebAuthenticationSession?
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Your main app content
                TabView(selection: $selectedTab) {
                    CustomersView()
                        .tabItem {
                            Label("Customers", systemImage: "person.3")
                        }
                        .tag(0)
                    VendorsView()
                        .tabItem {
                            Label("Vendors", systemImage: "building.2")
                        }
                        .tag(1)
                    OrdersView()
                        .tabItem {
                            Label("Orders", systemImage: "list.clipboard")
                        }
                        .tag(2)
                    SettingsView(settings: settingsManager)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(3)
                }
                .onAppear {
                    // Set the initial tab to Customers when authenticated
                    selectedTab = 0
                }
            } else {
                VStack {
                    Text("Welcome to BCConnector")
                    Button("Log In") {
                        if let url = authManager.startAuthentication() {
                            startAuthSession(url: url)
                        }
                    }
                    Button("Settings") {
                        isShowingSettings = true
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView(settings: settingsManager)
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                selectedTab = 0
            }
        }
    }
    
    private func startAuthSession(url: URL) {
        authContextProvider = AuthContextProvider()
        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "ca.yann.bcconnector.auth"
        ) { callbackURL, error in
            if let error = error {
                print("Authentication error: \(error.localizedDescription)")
                return
            }
            
            guard let callbackURL = callbackURL else {
                print("No callback URL received")
                return
            }
            
            Task {
                do {
                    try await authManager.handleRedirect(url: callbackURL)
                } catch {
                    print("Error handling redirect: \(error)")
                }
            }
        }
        
        authSession?.presentationContextProvider = authContextProvider
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
    }
}

class AuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @State private var tempClientId: String = ""
    @State private var tempClientSecret: String = ""
    @State private var tempTenantId: String = ""
    @State private var tempCompanyId: String = ""
    @State private var tempEnvironment: String = ""
    @State private var tempRedirectUri: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Business Central Settings")) {
                TextField("Client ID", text: $tempClientId)
                SecureField("Client Secret", text: $tempClientSecret)
                TextField("Tenant ID", text: $tempTenantId)
                TextField("Company ID", text: $tempCompanyId)
                TextField("Environment", text: $tempEnvironment)
                TextField("Redirect URI", text: $tempRedirectUri)
            }
            
            Section {
                Button("Save Changes") {
                    settings.clientId = tempClientId
                    settings.clientSecret = tempClientSecret
                    settings.tenantId = tempTenantId
                    settings.companyId = tempCompanyId
                    settings.environment = tempEnvironment
                    settings.redirectUri = tempRedirectUri
                }
            }
            
            Section(header: Text("Current Values")) {
                Text("Client ID: \(settings.clientId)")
                Text("Tenant ID: \(settings.tenantId)")
                Text("Company ID: \(settings.companyId)")
                Text("Environment: \(settings.environment)")
                Text("Redirect URI: \(settings.redirectUri)")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            tempClientId = settings.clientId
            tempClientSecret = settings.clientSecret
            tempTenantId = settings.tenantId
            tempCompanyId = settings.companyId
            tempEnvironment = settings.environment
            tempRedirectUri = settings.redirectUri
        }
    }
}

struct CustomersView: View {
    @StateObject private var viewModel = CustomersViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.customers) { customer in
                VStack(alignment: .leading) {
                    Text(customer.displayName)
                        .font(.headline)
                    Text(customer.email)
                        .font(.subheadline)
                }
            }
            .navigationTitle("Customers")
        }
        .task {
            await viewModel.fetchCustomers()
        }
    }
}

struct VendorsView: View {
    @StateObject private var viewModel = VendorsViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.vendors) { vendor in
                VStack(alignment: .leading) {
                    Text(vendor.displayName)
                        .font(.headline)
                    Text(vendor.email)
                        .font(.subheadline)
                }
            }
            .navigationTitle("Vendors")
        }
        .task {
            await viewModel.fetchVendors()
        }
    }
}

struct OrdersView: View {
    @StateObject private var viewModel = OrdersViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.orders) { order in
                VStack(alignment: .leading) {
                    Text(order.customerName)
                        .font(.headline)
                    Text(order.orderDate, style: .date)
                    Text("Total: \(order.totalAmount, format: .currency(code: "USD"))")
                }
            }
            .navigationTitle("Orders")
        }
        .task {
            await viewModel.fetchOrders()
        }
    }
}

#Preview {
    ContentView()
}
