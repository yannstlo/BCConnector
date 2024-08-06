import SwiftUI
import AuthenticationServices
import Foundation

// Import SettingsManager
import BCConnector

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var settingsManager = SettingsManager()
    @State private var isShowingWebView = false
    @State private var authURL: URL?
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
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
        } else {
            VStack {
                Text("Welcome to BCConnector")
                Button("Log In") {
                    if let url = authManager.startAuthentication() {
                        authURL = url
                        isShowingWebView = true
                    }
                }
                Button("Settings") {
                    isShowingSettings = true
                }
            }
            .sheet(isPresented: $isShowingWebView) {
                if let url = authURL {
                    AuthWebView(url: url)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(settings: settingsManager)
            }
        }
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

struct AuthWebView: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        let authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "ca.yann.bcconnector.auth",
            completionHandler: { callbackURL, error in
                if let callbackURL = callbackURL {
                    Task {
                        do {
                            try await AuthenticationManager.shared.handleRedirect(url: callbackURL)
                        } catch {
                            print("Error handling redirect: \(error)")
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        )
        
        authSession.presentationContextProvider = context.coordinator
        authSession.prefersEphemeralWebBrowserSession = true
        authSession.start()
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
        var parent: AuthWebView
        
        init(_ parent: AuthWebView) {
            self.parent = parent
        }
        
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            if #available(iOS 15.0, *) {
                return UIApplication.shared.connectedScenes
                    .filter { $0.activationState == .foregroundActive }
                    .compactMap { $0 as? UIWindowScene }
                    .first?
                    .windows
                    .first { $0.isKeyWindow } ?? ASPresentationAnchor()
            } else {
                return UIApplication.shared.windows.first ?? ASPresentationAnchor()
            }
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
