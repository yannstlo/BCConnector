import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var isShowingWebView = false
    @State private var authURL: URL?
    
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
            }
            .sheet(isPresented: $isShowingWebView) {
                if let url = authURL {
                    AuthWebView(url: url)
                }
            }
        }
    }
}

struct AuthWebView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> ASWebAuthenticationSession.ViewController {
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
            }
        )
        
        let controller = ASWebAuthenticationSession.ViewController()
        authSession.presentationContextProvider = controller
        authSession.prefersEphemeralWebBrowserSession = true
        authSession.start()
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ASWebAuthenticationSession.ViewController, context: Context) {}
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
