import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    
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
                    authManager.startAuthentication()
                }
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
