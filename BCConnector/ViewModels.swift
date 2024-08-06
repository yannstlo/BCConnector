import Foundation

@MainActor
class CustomersViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    
    func fetchCustomers() async {
        do {
            customers = try await APIClient.shared.fetch("customers")
        } catch {
            print("Error fetching customers: \(error)")
        }
    }
}

@MainActor
class VendorsViewModel: ObservableObject {
    @Published var vendors: [Vendor] = []
    
    func fetchVendors() async {
        do {
            vendors = try await APIClient.shared.fetch("vendors")
        } catch {
            print("Error fetching vendors: \(error)")
        }
    }
}

@MainActor
class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    
    func fetchOrders() async {
        do {
            orders = try await APIClient.shared.fetch("orders")
        } catch {
            print("Error fetching orders: \(error)")
        }
    }
}
