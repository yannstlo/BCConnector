import Foundation

@MainActor
class CustomersViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    
    func fetchCustomers() async {
        do {
            let response: BusinessCentralResponse<Customer> = try await APIClient.shared.fetch("companies(YOUR_COMPANY_ID)/customers")
            customers = response.value
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
            let response: BusinessCentralResponse<Vendor> = try await APIClient.shared.fetch("companies(YOUR_COMPANY_ID)/vendors")
            vendors = response.value
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
            let response: BusinessCentralResponse<Order> = try await APIClient.shared.fetch("companies(YOUR_COMPANY_ID)/salesOrders")
            orders = response.value
        } catch {
            print("Error fetching orders: \(error)")
        }
    }
}
