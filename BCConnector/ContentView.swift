import SwiftUI
import AuthenticationServices
import Foundation
import UIKit

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var isShowingSettings = false
    @State private var authContextProvider: AuthContextProvider?
    @State private var selectedTab = 0
    @State private var isShowingWorkspaceSelection = false
    @State private var authSession: ASWebAuthenticationSession?
    @ObservedObject private var toast = ToastManager.shared
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Your main app content
                VStack(spacing: 0) {
                    if settingsManager.environment.isEmpty || settingsManager.companyId.isEmpty {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Complete setup").font(.headline)
                                Text("Select your environment and company to begin.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Select") {
                                isShowingWorkspaceSelection = true
                            }
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.15))
                    }

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
                        ItemsView()
                            .tabItem {
                                Label("Items", systemImage: "shippingbox")
                            }
                            .tag(2)
                        OrdersView()
                            .tabItem {
                                Label("Orders", systemImage: "list.clipboard")
                            }
                            .tag(3)
                        SettingsView(settings: settingsManager)
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                            .tag(4)
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
                        isShowingWorkspaceSelection = settingsManager.environment.isEmpty || settingsManager.companyId.isEmpty
                    }
                    .sheet(isPresented: $isShowingWorkspaceSelection) {
                        EnvironmentCompanySelectionView()
                            .environmentObject(authManager)
                            .environmentObject(settingsManager)
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
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowWorkspaceSelection"))) { _ in
            isShowingWorkspaceSelection = true
        }
        .overlay(alignment: .top) {
            if let message = toast.message {
                ToastBanner(text: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .zIndex(1000)
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
    @State private var isShowingMap = false
    
    var body: some View {
        Form {
            HStack {
                InitialsIcon(name: customer.displayNameOrName, color: .orange)
                VStack(alignment: .leading) {
                    Text(customer.displayNameOrName)
                        .font(.headline)
                    Text(customer.no)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Address")) {
                Button(action: {
                    isShowingMap = true
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Address: \(customer.address)")
                            Text("City: \(customer.city)")
                            Text("State: \(customer.county)")
                            Text("Post Code: \(customer.postCode)")
                            Text("Country: \(customer.countryRegionCode)")
                        }
                        Spacer()
                        Image(systemName: "map")
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(.primary)
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

            Section(header: Text("Orders")) {
                CustomerOrdersList(customerId: customer.bcId, customerNumber: customer.no)
            }
        }
        .navigationTitle(customer.displayNameOrName)
        .sheet(isPresented: $isShowingMap) {
            MapView(address: "\(customer.address), \(customer.city), \(customer.county) \(customer.postCode), \(customer.countryRegionCode)")
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
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
    @State private var tempTenantId: String = ""
    @State private var tempOpenAIAPIKey: String = ""
    @State private var tempApiPublisher: String = ""
    @State private var tempApiGroup: String = ""
    @State private var tempApiVersion: String = ""
    @State private var showAdvanced = false
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showSavedBanner = false
    
    private var isDirty: Bool {
        tempClientId != settings.clientId ||
        tempTenantId != settings.tenantId ||
        tempOpenAIAPIKey != settings.openAIAPIKey ||
        tempApiPublisher != settings.apiPublisher ||
        tempApiGroup != settings.apiGroup ||
        tempApiVersion != settings.apiVersion
    }
    
    private func saveChanges() {
        settings.clientId = tempClientId
        settings.tenantId = tempTenantId
        settings.openAIAPIKey = tempOpenAIAPIKey
        settings.apiPublisher = tempApiPublisher
        settings.apiGroup = tempApiGroup
        settings.apiVersion = tempApiVersion
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            showSavedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showSavedBanner = false
            }
        }
    }
    
    var body: some View {
        NavigationView {
        Form {
            Section(header: Text("Business Central Settings")) {
                HStack {
                    Text("Client ID")
                    Spacer()
                    TextField("Enter Client ID", text: $tempClientId)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                HStack {
                    Text("Tenant ID")
                    Spacer()
                    TextField("7ea5e9d3-…", text: $tempTenantId)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                // Redirect URI moved to Azure Setup Help
            }
            
            Section(header: Text("Integrations")) {
                HStack {
                    Text("OpenAI API Key")
                    Spacer()
                    SecureField("sk-…", text: $tempOpenAIAPIKey)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
            }
            
            Section(header: Text("Workspace")) {
                Button("Switch Environment/Company") {
                    // Present the selection flow via a notification to ContentView
                    NotificationCenter.default.post(name: Notification.Name("ShowWorkspaceSelection"), object: nil)
                }
                HStack {
                    Text("Environment")
                    Spacer()
                    Text(settings.environment.isEmpty ? "Not set" : settings.environment)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Company")
                        Spacer()
                        Text(settings.companyName.isEmpty ? "Not set" : settings.companyName)
                            .foregroundColor(.secondary)
                    }
                    if !settings.companyId.isEmpty {
                        HStack {
                            Text("")
                            Spacer()
                            Text(settings.companyId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("Advanced")) {
                DisclosureGroup(isExpanded: $showAdvanced) {
                    HStack {
                        Text("API Publisher")
                        Spacer()
                        TextField("microsoft", text: $tempApiPublisher)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    HStack {
                        Text("API Group")
                        Spacer()
                        TextField("dynamics", text: $tempApiGroup)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    HStack {
                        Text("API Version")
                        Spacer()
                        TextField("v2.0", text: $tempApiVersion)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                } label: {
                    Text("Business Central API namespace")
                }
            }
            
            // Save moved to toolbar
            
            /*
            Section(header: Text("Current Values")) {
                Text("Client ID: \(settings.clientId)")
                Text("Tenant ID: \(settings.tenantId)")
                Text("Company ID: \(settings.companyId)")
                Text("Environment: \(settings.environment)")
                Text("Redirect URI: \(settings.redirectUri)")
                Text("OpenAI API Key: \(settings.openAIAPIKey.isEmpty ? "Not set" : "••••••••")")
            }
            */
            
            Section(header: Text("Help & Docs")) {
                NavigationLink("Azure Setup Help") {
                    AzureSetupHelpView(settings: settings)
                }
                Toggle("Network logging", isOn: $settings.networkLoggingEnabled)
                    .tint(.blue)
                Toggle("Log response bodies", isOn: $settings.networkLogBodies)
                    .tint(.blue)
            }

            Section {
                Button("Log Out") {
                    authManager.logout()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                let canSave = isDirty && !tempClientId.isEmpty && !tempTenantId.isEmpty
                Button("Save") { saveChanges() }
                    .tint(canSave ? .blue : .secondary)
                    .disabled(!canSave)
            }
        }
        .overlay(alignment: .top) {
            if showSavedBanner {
                SavedBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        }
        .onAppear {
            tempClientId = settings.clientId
            tempTenantId = settings.tenantId
            tempOpenAIAPIKey = settings.openAIAPIKey
            tempApiPublisher = settings.apiPublisher
            tempApiGroup = settings.apiGroup
            tempApiVersion = settings.apiVersion
        }
    }
}

private struct SavedBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
            Text("Saved").foregroundColor(.white).font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.green.opacity(0.95))
        )
    }
}

struct CustomersView: View {
    @StateObject private var viewModel = CustomersViewModel()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationView {
            Group {
                if !viewModel.customers.isEmpty {
                    List {
                        ForEach(Array(viewModel.customers.enumerated()), id: \.element.id) { idx, customer in
                            NavigationLink(destination: CustomerDetailPagerView(customers: viewModel.customers, index: idx)) {
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
            .searchable(text: $searchText, prompt: "Search customers")
        }
        .task {
            await viewModel.fetchCustomers()
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task { [q = newValue] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled { return }
                if q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await viewModel.fetchCustomers()
                } else {
                    await viewModel.searchCustomers(query: q)
                }
            }
        }
    }
}

struct VendorsView: View {
    @StateObject private var viewModel = VendorsViewModel()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationView {
            Group {
                if !viewModel.vendors.isEmpty {
                    List {
                        ForEach(Array(viewModel.vendors.enumerated()), id: \.element.id) { idx, vendor in
                            NavigationLink(destination: VendorDetailPagerView(vendors: viewModel.vendors, index: idx)) {
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
            .searchable(text: $searchText, prompt: "Search vendors")
        }
        .task {
            await viewModel.fetchVendors()
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task { [q = newValue] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled { return }
                if q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await viewModel.fetchVendors()
                } else {
                    await viewModel.searchVendors(query: q)
                }
            }
        }
    }
}

struct ItemsView: View {
    @StateObject private var vm = ItemsViewModel()
    @ObservedObject private var settings = SettingsManager.shared
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationView {
            Group {
                if !vm.items.isEmpty {
                    List {
                        ForEach(Array(vm.items.enumerated()), id: \.element.id) { idx, item in
                            NavigationLink(destination: ItemDetailPagerView(items: vm.items, index: idx)) {
                                HStack(spacing: 12) {
                                    ItemThumbnailView(itemId: item.id, itemNumber: item.number)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.displayName ?? item.number ?? "—")
                                            .font(.subheadline)
                                            .bold()
                                        if let number = item.number, let name = item.displayName, number != name {
                                            Text(number)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else if let error = vm.errorMessage {
                    VStack(spacing: 8) {
                        Text(error).foregroundColor(.red)
                        Button("Retry") { Task { await vm.fetchItems() } }
                    }
                } else {
                    ProgressView("Loading items…")
                }
            }
            .navigationTitle("Items")
            .searchable(text: $searchText, prompt: "Search items")
        }
        .task { await vm.fetchItems() }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task { [q = newValue] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled { return }
                if q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await vm.fetchItems()
                } else {
                    do {
                        let results = try await ItemsSearchAdapter().searchItems(query: q)
                        await MainActor.run { vm.items = results }
                    } catch { }
                }
            }
        }
    }
}

// Rich item detail card
struct ItemDetailCardView: View {
    let item: ItemDetailDTO
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var loader = ItemImageLoader()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hero image
                Group {
                    if let img = loader.image {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 260)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .ignoresSafeArea(edges: .top)
                    } else {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                            )
                            .ignoresSafeArea(edges: .top)
                    }
                }

                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.displayName ?? item.number ?? "—")
                        .font(.title3)
                        .fontWeight(.semibold)
                    if let number = item.number { Text(number).font(.subheadline).foregroundColor(.secondary) }
                }
                .padding(.horizontal)
                .padding(.top, 4)

                // Info sections
                VStack(alignment: .leading, spacing: 12) {
                    // Basic info
                    Section(header: Text("Info").font(.subheadline).foregroundColor(.secondary)) {
                        KeyValueRow(key: "Type", value: item.type)
                        KeyValueRow(key: "Category", value: item.itemCategoryCode)
                        if let blocked = item.blocked { KeyValueRow(key: "Blocked", value: blocked ? "Yes" : "No") }
                    }
                    // Unit and pricing
                    Section(header: Text("Unit & Pricing").font(.subheadline).foregroundColor(.secondary)) {
                        KeyValueRow(key: "Base Unit", value: item.baseUnitOfMeasure ?? item.baseUnitOfMeasureId)
                        if let price = item.unitPrice { KeyValueRow(key: "Unit Price", value: currencyFormatter().string(from: NSDecimalNumber(decimal: price))) }
                        if let cost = item.unitCost { KeyValueRow(key: "Unit Cost", value: currencyFormatter().string(from: NSDecimalNumber(decimal: cost))) }
                    }
                    // Inventory
                    Section(header: Text("Inventory").font(.subheadline).foregroundColor(.secondary)) {
                        if let inv = item.inventory { KeyValueRow(key: "On Hand", value: "\(inv as NSDecimalNumber)") }
                        if let gtin = item.gtin { KeyValueRow(key: "GTIN", value: gtin) }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle(item.displayName ?? item.number ?? "Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { loader.load(companyId: settings.companyId, itemId: item.id, itemNumber: item.number) }
        .onChange(of: item.id) { _, _ in
            loader.image = nil
            loader.load(companyId: settings.companyId, itemId: item.id, itemNumber: item.number)
        }
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String?
    var body: some View {
        HStack {
            Text(key)
            Spacer()
            Text(value ?? "—").foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// Loads an item by id or number, then shows the rich ItemDetailCardView
struct ItemDetailLoaderView: View {
    let itemId: String?
    let itemNumber: String?
    @State private var item: ItemDetailDTO?
    @State private var errorMessage: String?
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Group {
            if let item = item {
                ItemDetailCardView(item: item)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage).foregroundColor(.red)
                    Button("Retry") { Task { await load() } }
                        .font(.caption)
                }
                .navigationTitle("Item")
            } else {
                ProgressView("Loading item…")
                    .navigationTitle("Item")
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            if let id = itemId {
                let path = "api/v2.0/companies(\(settings.companyId))/items(\(id))"
                let dto: ItemDetailDTO = try await APIClient.shared.fetch(path)
                await MainActor.run { self.item = dto }
                return
            }
            if let number = itemNumber {
                let path = "api/v2.0/companies(\(settings.companyId))/items?$filter=number eq '\(number)'"
                let resp: BusinessCentralResponse<ItemDetailDTO> = try await APIClient.shared.fetch(path)
                await MainActor.run { self.item = resp.value.first }
                return
            }
            await MainActor.run { self.errorMessage = "Missing item id/number" }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
}

// Pager wrapper to navigate between items with Previous/Next
struct ItemDetailPagerView: View {
    let items: [ItemDTO]
    @State var index: Int
    
    var body: some View {
        let clampedIndex = min(max(index, 0), max(0, items.count - 1))
        let item = items.isEmpty ? ItemDTO(id: "", number: nil, displayName: "Item", description: nil) : items[clampedIndex]
        ItemDetailLoaderView(itemId: item.id, itemNumber: item.number)
            .id(item.id)
            .animation(Animation.easeInOut, value: index)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { if index > 0 { index -= 1 } }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(index <= 0)
                    Button(action: { if index < items.count - 1 { index += 1 } }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(index >= items.count - 1)
                }
            }
    }
}

struct VendorDetailView: View {
    let vendor: Vendor
    @State private var isShowingMap = false
    
    var body: some View {
        Form {
            HStack {
                InitialsIcon(name: vendor.name, color: .blue)
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
                Button(action: {
                    isShowingMap = true
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Address: \(vendor.address)")
                            if !vendor.address2.isEmpty {
                                Text("Address 2: \(vendor.address2)")
                            }
                            Text("City: \(vendor.city)")
                            Text("County: \(vendor.county)")
                            Text("Post Code: \(vendor.postCode)")
                            Text("Country: \(vendor.countryRegionCode)")
                        }
                        Spacer()
                        Image(systemName: "map")
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(.primary)
            }
            
            Section(header: Text("Financial Information")) {
                Text("Balance: \(vendor.balance, format: .currency(code: "USD"))")
                Text("Payment Terms: \(vendor.paymentTermsCode)")
            }
        }
        .navigationTitle(vendor.name)
        .sheet(isPresented: $isShowingMap) {
            MapView(address: "\(vendor.address), \(vendor.city), \(vendor.county) \(vendor.postCode), \(vendor.countryRegionCode)")
        }
    }
}

struct OrdersView: View {
    @StateObject private var viewModel = OrdersViewModel()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(viewModel.orders.enumerated()), id: \.element.id) { idx, order in
                    NavigationLink(destination: OrderDetailPagerView(orders: viewModel.orders, index: idx)) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    ShippingStatusIconInteractive(fullyShipped: order.fullyShipped ?? false, status: order.status)
                                    Text(order.number ?? "–")
                                        .font(.subheadline)
                                        .bold()
                                    if let status = order.status, !status.isEmpty {
                                        StatusBadge(status: status)
                                    }
                                }
                                if let d = parseBCDate(order.orderDate) {
                                    Text(d, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let name = order.customerName, !name.isEmpty {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if let total = order.totalAmountIncludingTax ?? order.totalAmountExcludingTax {
                                Text(NSDecimalNumber(decimal: total), formatter: currencyFormatter())
                                    .font(.footnote)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Orders")
            .searchable(text: $searchText, prompt: "Search orders")
        }
        .task {
            await viewModel.fetchOrders()
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task { [q = newValue] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled { return }
                if q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await viewModel.fetchOrders()
                } else {
                    await viewModel.searchOrders(query: q)
                }
            }
        }
    }
}

// Pager wrapper to navigate between orders with Previous/Next
struct OrderDetailPagerView: View {
    let orders: [OrderDTO]
    @State var index: Int
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        let clampedIndex = min(max(index, 0), max(0, orders.count - 1))
        let o = orders.isEmpty ? nil : orders[clampedIndex]
        Group {
            if let o = o {
                OrderDetailView(orderId: o.id, fallbackNumber: o.number ?? "", initialStatus: o.status ?? nil, initialFullyShipped: o.fullyShipped ?? false)
                    .id(o.id)
            } else {
                Text("No order")
            }
        }
        .animation(Animation.easeInOut, value: index)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { if index > 0 { index -= 1 } }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(index <= 0)
                Button(action: { if index < orders.count - 1 { index += 1 } }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(index >= orders.count - 1)
            }
        }
    }
}

// Pager wrappers for Customers and Vendors
struct CustomerDetailPagerView: View {
    let customers: [Customer]
    @State var index: Int
    var body: some View {
        let clamped = min(max(index, 0), max(0, customers.count - 1))
        let c = customers.isEmpty ? nil : customers[clamped]
        Group {
            if let c = c {
                CustomerDetailView(customer: c)
                    .id(c.id)
            } else { Text("No customer") }
        }
        .animation(Animation.easeInOut, value: index)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { if index > 0 { index -= 1 } }) { Image(systemName: "chevron.left") }
                    .disabled(index <= 0)
                Button(action: { if index < customers.count - 1 { index += 1 } }) { Image(systemName: "chevron.right") }
                    .disabled(index >= customers.count - 1)
            }
        }
    }
}

struct VendorDetailPagerView: View {
    let vendors: [Vendor]
    @State var index: Int
    var body: some View {
        let clamped = min(max(index, 0), max(0, vendors.count - 1))
        let v = vendors.isEmpty ? nil : vendors[clamped]
        Group {
            if let v = v {
                VendorDetailView(vendor: v)
                    .id(v.id)
            } else { Text("No vendor") }
        }
            .animation(Animation.easeInOut, value: index)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { if index > 0 { index -= 1 } }) { Image(systemName: "chevron.left") }
                    .disabled(index <= 0)
                Button(action: { if index < vendors.count - 1 { index += 1 } }) { Image(systemName: "chevron.right") }
                    .disabled(index >= vendors.count - 1)
            }
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

// Lightweight orders list for a specific customer
final class CustomerOrdersViewModel: ObservableObject {
    @Published var orders: [OrderDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private var currentKey: String?
    private var task: Task<Void, Never>?
    private var completedKeys: Set<String> = []

    func load(customerId: String, customerNumber: String, companyId: String, force: Bool = false) {
        guard !companyId.isEmpty else { return }
        let key = "\(customerNumber)-\(companyId)"
        if isLoading { return }
        if !force && (completedKeys.contains(key) || (currentKey == key && (!orders.isEmpty || errorMessage != nil))) {
            return
        }
        currentKey = key
        isLoading = true
        errorMessage = nil

        task?.cancel()
        task = Task { [weak self] in
            guard let self = self else { return }
            let select = "$select=id,number,status,orderDate,totalAmountIncludingTax,totalAmountExcludingTax,customerNumber,fullyShipped"
            let filter = "$filter=customerNumber eq '\(customerNumber)'"
            let order = "$orderby=orderDate desc"
            let top = "$top=50"
            let path = "api/v2.0/companies(\(companyId))/salesOrders?\(select)&\(filter)&\(order)&\(top)"
            do {
                let dtos: [OrderDTO] = try await APIClient.shared.fetchPaged(path)
                await MainActor.run {
                    self.completedKeys.insert(key)
                    if SettingsManager.shared.networkLoggingEnabled {
                        if SettingsManager.shared.networkLogBodies,
                           let jsonData = try? JSONEncoder().encode(dtos),
                           let jsonStr = String(data: jsonData, encoding: .utf8) {
                            let snippet = jsonStr.count > 4000 ? String(jsonStr.prefix(4000)) + "…(truncated)" : jsonStr
                            print("[Orders] JSON (decoded):\n\(snippet)")
                        } else {
                            let summary = dtos.map { ($0.number ?? "–") + ":" + ($0.status ?? "?") }.joined(separator: ", ")
                            print("[Orders] Loaded \(dtos.count). Statuses: \(summary)")
                        }
                    }
                    self.orders = dtos
                    self.isLoading = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    self.completedKeys.insert(key)
                    switch error {
                    case .httpError(let code, _):
                        self.errorMessage = code == 429 ? "Rate limited (429). Please wait and retry." : "HTTP error: \(code)"
                    case .decodingError(let msg):
                        self.errorMessage = "Decoding error: \(msg)"
                    case .authenticationError:
                        self.errorMessage = "Authentication error. Please log in again."
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                    self.isLoading = false
                }
            } catch is CancellationError {
                await MainActor.run { self.isLoading = false }
            } catch let urlError as URLError where urlError.code == .cancelled {
                await MainActor.run { self.isLoading = false }
            } catch {
                await MainActor.run {
                    self.completedKeys.insert(key)
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct CustomerOrdersList: View {
    let customerId: String
    let customerNumber: String
    @StateObject private var vm = CustomerOrdersViewModel()
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading orders…")
            } else if let errorMessage = vm.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage).foregroundColor(.red)
                    Button("Retry") { vm.load(customerId: customerId, customerNumber: customerNumber, companyId: settings.companyId, force: true) }
                        .font(.caption)
                }
            } else if vm.orders.isEmpty {
                Text("No orders found").foregroundColor(.secondary)
            } else {
                ForEach(Array(vm.orders.prefix(20).enumerated()), id: \.element.id) { idx, order in
                    NavigationLink(destination: OrderDetailPagerView(orders: vm.orders, index: idx)) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    ShippingStatusIconInteractive(fullyShipped: order.fullyShipped ?? false, status: order.status)
                                    Text(order.number ?? "–").font(.subheadline).bold()
                                    if let status = order.status, !status.isEmpty {
                                        StatusBadge(status: status)
                                    }
                                }
                                if let date = parseBCDate(order.orderDate) {
                                    Text(date, style: .date).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if let total = order.totalAmountIncludingTax ?? order.totalAmountExcludingTax {
                                Text(NSDecimalNumber(decimal: total), formatter: currencyFormatter())
                                    .font(.footnote)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .onAppear { vm.load(customerId: customerId, customerNumber: customerNumber, companyId: settings.companyId) }
        .onChange(of: settings.companyId) { _, newValue in
            vm.load(customerId: customerId, customerNumber: customerNumber, companyId: newValue, force: true)
        }
    }

    private func currencyFormatter() -> NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "USD"
        return nf
    }

    private func parseBCDate(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty, s != "0001-01-01" else { return nil }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: s) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: s)
    }

}

// Reusable status badge view so it’s accessible across views
struct StatusBadge: View {
    let status: String
    var body: some View {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch normalized {
        case "OPEN":
            Text(normalized)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.18)))
        case "DRAFT":
            Text(normalized)
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    Capsule().stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        case "RELEASED":
            Text(normalized)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.18)))
        default:
            Text(normalized)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
    }
}

// Shipment status icon (best-effort using header fields)
struct ShippingStatusIcon: View {
    let fullyShipped: Bool
    let status: String?
    var body: some View {
        if fullyShipped {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
                .accessibilityLabel("Fully shipped")
        } else {
            // Without per-line shipped quantities, treat non-fully-shipped as pending
            let normalized = (status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            switch normalized {
            case "OPEN", "RELEASED":
                Image(systemName: "shippingbox")
                    .foregroundColor(.orange)
                    .accessibilityLabel("Not fully shipped")
            case "DRAFT":
                Image(systemName: "clock")
                    .foregroundColor(.gray)
                    .accessibilityLabel("Draft")
            default:
                Image(systemName: "shippingbox")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Pending shipment")
            }
        }
    }
}

struct ShippingStatusIconInteractive: View {
    let fullyShipped: Bool
    let status: String?

    var body: some View {
        let text = tooltipText
        ShippingStatusIcon(fullyShipped: fullyShipped, status: status)
            .onTapGesture { ToastManager.shared.show(text) }
            .help(text)
            .accessibilityHint(text)
    }

    private var tooltipText: String {
        let normalized = (status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if fullyShipped { return "Fully shipped" }
        switch normalized {
        case "OPEN": return "Open (not fully shipped)"
        case "RELEASED": return "Released (not fully shipped)"
        case "DRAFT": return "Draft (not shipped)"
        default: return "Pending shipment"
        }
    }
}

// MARK: - Toast (global lightweight banner)

final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    @Published var message: String?
    private init() {}
    func show(_ text: String, duration: TimeInterval = 1.6) {
        message = text
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) { self?.message = nil }
        }
    }
}

struct ToastBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundColor(.white)
            Text(text).foregroundColor(.white).font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.black.opacity(0.85))
        )
        .padding(.top, 6)
    }
}

// MARK: - Shared Helpers

func parseBCDate(_ s: String?) -> Date? {
    guard let s = s, !s.isEmpty, s != "0001-01-01" else { return nil }
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    df.dateFormat = "yyyy-MM-dd"
    if let d = df.date(from: s) { return d }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return iso.date(from: s)
}

func currencyFormatter() -> NumberFormatter {
    let nf = NumberFormatter()
    nf.numberStyle = .currency
    nf.currencyCode = "USD"
    return nf
}

// Inline Azure setup help to ensure symbol availability within target
struct AzureSetupHelpView: View {
    @ObservedObject var settings: SettingsManager
    @State private var didCopyRedirectURI = false
    @State private var didCopyAuthorize = false
    @State private var didCopyToken = false
    @State private var didCopyScope = false

    private var authorizeURL: String {
        "https://login.microsoftonline.com/\(settings.tenantId)/oauth2/v2.0/authorize"
    }
    private var tokenURL: String {
        "https://login.microsoftonline.com/\(settings.tenantId)/oauth2/v2.0/token"
    }
    private var scope: String { "https://api.businesscentral.dynamics.com/.default offline_access" }

    var body: some View {
        Form {
            Section(header: Text("Overview")) {
                Text("Use this guide to configure your Azure Entra ID App Registration for BCConnector.")
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Redirect URI")) {
                HStack(spacing: 8) {
                    Text("URI")
                    Spacer()
                    Text(settings.redirectUri)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = settings.redirectUri
                        didCopyRedirectURI = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didCopyRedirectURI = false }
                    } label: {
                        Image(systemName: didCopyRedirectURI ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundColor(didCopyRedirectURI ? .green : .blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy Redirect URI")
                }
                Text("Add this Redirect URI in Azure Entra ID (public client). Use the same value in your app settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Endpoints")) {
                labeledCopyRow(label: "Authorize", value: authorizeURL, didCopy: $didCopyAuthorize)
                labeledCopyRow(label: "Token", value: tokenURL, didCopy: $didCopyToken)
                labeledCopyRow(label: "Scope", value: scope, didCopy: $didCopyScope)
            }

            Section(header: Text("Steps")) {
                Text("1. Register a new application in Azure Entra ID.")
                Text("2. Set the Redirect URI shown above (custom scheme).")
                Text("3. Grant API permissions to Business Central (/.default).")
                Text("4. Grant admin consent, then authenticate in the app.")
            }

            Section(header: Text("More Info")) {
                Link("Microsoft docs: Register an app", destination: URL(string: "https://learn.microsoft.com/entra/identity-platform/quickstart-register-app")!)
            }
        }
        .navigationTitle("Azure Setup Help")
    }

    @ViewBuilder
    private func labeledCopyRow(label: String, value: String, didCopy: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Button {
                UIPasteboard.general.string = value
                didCopy.wrappedValue = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didCopy.wrappedValue = false }
            } label: {
                Image(systemName: didCopy.wrappedValue ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundColor(didCopy.wrappedValue ? .green : .blue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(label)")
        }
    }
}

// MARK: - Order Detail

final class OrderDetailViewModel: ObservableObject {
    @Published var header: OrderDTO?
    @Published var lines: [SalesOrderLineDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(orderId: String, companyId: String) {
        guard !companyId.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task { [weak self] in
            guard let self = self else { return }
            let headerSelect = "$select=id,number,status,orderDate,customerName,totalAmountIncludingTax,totalAmountExcludingTax,currencyCode,fullyShipped"
            let headerPath = "api/v2.0/companies(\(companyId))/salesOrders(\(orderId))?\(headerSelect)"
            let linesSelect = "$select=id,sequence,lineType,lineObjectNumber,itemId,description,quantity,unitPrice,amountExcludingTax,amountIncludingTax"
            let linesPath = "api/v2.0/companies(\(companyId))/salesOrders(\(orderId))/salesOrderLines?\(linesSelect)"
            do {
                async let headerReq: OrderDTO = APIClient.shared.fetch(headerPath)
                async let linesReq: BusinessCentralResponse<SalesOrderLineDTO> = APIClient.shared.fetch(linesPath)
                let (h, l) = try await (headerReq, linesReq)
                await MainActor.run {
                    self.header = h
                    self.lines = l.value
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct OrderDetailView: View {
    let orderId: String
    let fallbackNumber: String
    let initialStatus: String?
    let initialFullyShipped: Bool
    @StateObject private var vm = OrderDetailViewModel()
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading order…")
            } else if let error = vm.errorMessage {
                VStack(spacing: 8) {
                    Text(error).foregroundColor(.red)
                    Button("Retry") { vm.load(orderId: orderId, companyId: settings.companyId) }
                        .font(.caption)
                }
            } else if let h = vm.header {
                List {
                    Section(header: Text("Summary")) {
                        HStack {
                            Text("Number")
                            Spacer()
                            Text(h.number ?? fallbackNumber).foregroundColor(.secondary)
                        }
                        if let status = h.status ?? initialStatus {
                            HStack {
                                Text("Status")
                                Spacer()
                                StatusBadge(status: status)
                            }
                        }
                        HStack {
                            Text("Shipment")
                            Spacer()
                            ShippingStatusIconInteractive(fullyShipped: h.fullyShipped ?? initialFullyShipped, status: h.status ?? initialStatus)
                        }
                        if let s = h.orderDate, let d = parseDate(s) {
                            HStack {
                                Text("Order Date")
                                Spacer()
                                Text(d, style: .date).foregroundColor(.secondary)
                            }
                        }
                        if let total = h.totalAmountIncludingTax ?? h.totalAmountExcludingTax {
                            HStack {
                                Text("Total")
                                Spacer()
                                Text(NSDecimalNumber(decimal: total), formatter: currencyFormatter())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Section(header: Text("Lines")) {
                        if vm.lines.isEmpty {
                            Text("No lines").foregroundColor(.secondary)
                        } else {
                            ForEach(vm.lines, id: \.id) { line in
                                HStack(alignment: .top, spacing: 10) {
                                    if (line.lineType?.lowercased() == "item") {
                                        ItemThumbnailView(itemId: line.itemId, itemNumber: line.lineObjectNumber)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(line.description ?? line.lineObjectNumber ?? "—")
                                            .font(.subheadline)
                                        HStack {
                                            if let qty = line.quantity { Text("Qty: \(qty as NSDecimalNumber)") }
                                            if let price = line.unitPrice {
                                                Text("@ \(NSDecimalNumber(decimal: price), formatter: currencyFormatter())")
                                            }
                                            Spacer()
                                            if let amt = line.amountIncludingTax ?? line.amountExcludingTax {
                                                Text(NSDecimalNumber(decimal: amt), formatter: currencyFormatter())
                                                    .font(.footnote)
                                            }
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
            } else {
                Text("No data")
            }
        }
        .navigationTitle(vm.header?.number ?? fallbackNumber)
        .onAppear { vm.load(orderId: orderId, companyId: settings.companyId) }
        .onChange(of: orderId) { _, _ in
            vm.header = nil
            vm.lines = []
            vm.errorMessage = nil
            vm.load(orderId: orderId, companyId: settings.companyId)
        }
    }

    private func currencyFormatter() -> NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "USD"
        return nf
}

    private func parseDate(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty, s != "0001-01-01" else { return nil }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: s) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: s)
    }
}

// MARK: - Item Thumbnail

private final class ItemImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var task: Task<Void, Never>?
    static var cache = NSCache<NSString, UIImage>()

    func load(companyId: String, itemId: String?, itemNumber: String?) {
        guard !companyId.isEmpty else { return }
        task?.cancel()
        task = Task { [weak self] in
            guard let self = self else { return }
            do {
                var resolvedItemId = itemId
                if resolvedItemId == nil, let number = itemNumber {
                    let path = "api/v2.0/companies(\(companyId))/items?$filter=number eq '\(number)'&$select=id"
                    let resp: BusinessCentralResponse<ItemIdDTO> = try await APIClient.shared.fetch(path)
                    resolvedItemId = resp.value.first?.id
                }
                guard let id = resolvedItemId else { return }
                let cacheKey = "item-thumb-\(id)" as NSString
                if let cached = ItemImageLoader.cache.object(forKey: cacheKey) {
                    await MainActor.run { self.image = cached }
                    return
                }
                let imgPath = "https://api.businesscentral.dynamics.com/v2.0/\(SettingsManager.shared.tenantId)/\(SettingsManager.shared.environment)/api/v2.0/companies(\(companyId))/items(\(id))/picture/pictureContent"
                guard let imgURL = URL(string: imgPath) else { return }
                let imgData = try await APIClient.shared.authorizedData(from: imgURL)
                if let ui = UIImage(data: imgData) {
                    ItemImageLoader.cache.setObject(ui, forKey: cacheKey)
                    await MainActor.run { self.image = ui }
                }
            } catch {
                if SettingsManager.shared.networkLoggingEnabled {
                    print("[Items] Thumbnail load failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

private struct ItemIdDTO: Codable, Identifiable { let id: String }
private struct ItemPictureMeta: Codable, Identifiable {
    let id: String
    let mediaReadLink: String?
    enum CodingKeys: String, CodingKey {
        case id
        case mediaReadLink = "content@odata.mediaReadLink"
    }
}

struct ItemThumbnailView: View {
    let itemId: String?
    let itemNumber: String?
    @StateObject private var loader = ItemImageLoader()
    @ObservedObject private var settings = SettingsManager.shared
    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
        .frame(width: 32, height: 32)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onAppear { loader.load(companyId: settings.companyId, itemId: itemId, itemNumber: itemNumber) }
    }
}
