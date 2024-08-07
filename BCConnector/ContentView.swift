import SwiftUI
import AuthenticationServices
import Foundation

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
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
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("BCConnector")
                            .font(.headline)
                    }
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

struct CustomerDetailView: View {
    let customer: Customer
    
    var body: some View {
        Form {
            HStack {
                InitialsIcon(name: customer.displayNameOrName)
                VStack(alignment: .leading) {
                    Text(customer.displayNameOrName)
                        .font(.headline)
                    Text(customer.no)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Address")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Address: \(customer.address)")
                        Text("City: \(customer.city)")
                        Text("State: \(customer.county)")
                        Text("Post Code: \(customer.postCode)")
                        Text("Country: \(customer.countryRegionCode)")
                    }
                    Spacer()
                    Button(action: {
                        openMap(for: customer)
                    }) {
                        Image(systemName: "map")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Section(header: Text("Financial Information")) {
                Text("Balance: \(formatCurrency(customer.balance))")
                Text("Credit Limit: \(formatCurrency(customer.creditLimitLCY))")
                Text("Payment Terms: \(customer.paymentTermsCode)")
            }
            
            Section(header: Text("Sales Information")) {
                Text("Salesperson: \(customer.salespersonCode)")
                Text("Customer Posting Group: \(customer.customerPostingGroup)")
                Text("Gen. Bus. Posting Group: \(customer.genBusPostingGroup)")
            }
        }
        .navigationTitle(customer.displayNameOrName)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func openMap(for customer: Customer) {
        let address = "\(customer.address), \(customer.city), \(customer.county) \(customer.postCode), \(customer.countryRegionCode)"
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mapString = "http://maps.apple.com/?address=\(encodedAddress)"
        if let url = URL(string: mapString) {
            UIApplication.shared.open(url)
        }
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
    @EnvironmentObject private var authManager: AuthenticationManager
    
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
            
            Section {
                Button("Log Out") {
                    authManager.logout()
                }
                .foregroundColor(.red)
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
            Group {
                if !viewModel.customers.isEmpty {
                    List {
                        ForEach(viewModel.customers) { customer in
                            NavigationLink(destination: CustomerDetailView(customer: customer)) {
                                HStack {
                                    InitialsIcon(name: customer.displayNameOrName, color: .orange)
                                    VStack(alignment: .leading) {
                                        Text(customer.displayNameOrName)
                                            .font(.headline)
                                        Text("Number: \(customer.no)")
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ProgressView("Loading customers...")
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
            Group {
                if !viewModel.vendors.isEmpty {
                    List {
                        ForEach(viewModel.vendors) { vendor in
                            NavigationLink(destination: VendorDetailView(vendor: vendor)) {
                                HStack {
                                    InitialsIcon(name: vendor.name, color: .blue)
                                    VStack(alignment: .leading) {
                                        Text(vendor.name)
                                            .font(.headline)
                                        Text("Number: \(vendor.no)")
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ProgressView("Loading vendors...")
                }
            }
            .navigationTitle("Vendors")
        }
        .task {
            await viewModel.fetchVendors()
        }
    }
}

struct VendorDetailView: View {
    let vendor: Vendor
    
    var body: some View {
        Form {
            HStack {
                InitialsIcon(name: vendor.name)
                VStack(alignment: .leading) {
                    Text(vendor.name)
                        .font(.headline)
                    Text(vendor.no)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Contact Information")) {
                Text("Phone: \(vendor.phoneNo)")
                Text("Contact: \(vendor.contact)")
            }
            
            Section(header: Text("Address")) {
                Text("Address: \(vendor.address)")
                Text("Address 2: \(vendor.address2)")
                Text("City: \(vendor.city)")
                Text("County: \(vendor.county)")
                Text("Post Code: \(vendor.postCode)")
                Text("Country: \(vendor.countryRegionCode)")
            }
            
            Section(header: Text("Financial Information")) {
                Text("Balance: \(vendor.balance, format: .currency(code: "USD"))")
                Text("Payment Terms: \(vendor.paymentTermsCode)")
            }
        }
        .navigationTitle(vendor.name)
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

struct InitialsIcon: View {
    let name: String
    let color: Color
    
    var initials: String {
        let words = name.split(separator: " ")
        return words.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
            
            Text(initials)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .bold))
        }
    }
}
