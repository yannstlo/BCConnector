import SwiftUI
import AuthenticationServices
import Foundation

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var isShowingSettings = false
    
    var body: some View {
        if authManager.isAuthenticated {
            // Your main app content
            TabView {
                CustomersView()
                    .tabItem {
                        Label("Customers", systemImage: "person.3")
                    }
                VendorsView()
                    .tabItem {
                        Label("Vendors", systemImage: "building.2")
                    }
                OrdersView()
                    .tabItem {
                        Label("Orders", systemImage: "list.clipboard")
                    }
                SettingsView(settings: settingsManager)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
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
    
    private func startAuthSession(url: URL) {
        let session = ASWebAuthenticationSession(
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
        
        session.presentationContextProvider = AuthContextProvider()
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }
}

class AuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        Form {
            Section(header: Text("Business Central Settings")) {
                TextField("Client ID", text: $settings.clientId)
                SecureField("Client Secret", text: $settings.clientSecret)
                TextField("Tenant ID", text: $settings.tenantId)
                TextField("Company ID", text: $settings.companyId)
                TextField("Environment", text: $settings.environment)
            }
        }
        .navigationTitle("Settings")
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
