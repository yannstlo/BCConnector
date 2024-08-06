import Foundation
import SwiftUI

@MainActor
class CustomersViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    
    @ObservedObject private var settings = SettingsManager.shared
    
    func fetchCustomers() async {
        do {
            let response: BusinessCentralResponse<Customer> = try await APIClient.shared.fetch("companies(\(settings.companyId))/customers")
            customers = response.value
        } catch let error as APIError {
            switch error {
            case .authenticationError:
                print("Authentication error: Please check your credentials and try logging in again.")
            case .invalidURL:
                print("Invalid URL: Please check your Business Central settings.")
            case .networkError(let message):
                print("Network error: \(message)")
            case .httpError(let statusCode):
                print("HTTP error: Status code \(statusCode)")
            case .decodingError(let message):
                print("Decoding error: \(message)")
            default:
                print("Unknown error: \(error.localizedDescription)")
            }
        } catch {
            print("Unexpected error: \(error.localizedDescription)")
        }
    }
}

struct CustomerResponse: Codable {
    let value: [Customer]
}

@MainActor
class VendorsViewModel: ObservableObject {
    @Published var vendors: [Vendor] = []
    
    @ObservedObject private var settings = SettingsManager.shared
    
    func fetchVendors() async {
        do {
            let response: BusinessCentralResponse<Vendor> = try await APIClient.shared.fetch("companies(\(settings.companyId))/vendors")
            vendors = response.value
        } catch {
            print("Error fetching vendors: \(error)")
        }
    }
}

@MainActor
class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    
    @ObservedObject private var settings = SettingsManager.shared
    
    func fetchOrders() async {
        do {
            let response: BusinessCentralResponse<Order> = try await APIClient.shared.fetch("companies(\(settings.companyId))/salesOrders")
            orders = response.value
        } catch {
            print("Error fetching orders: \(error)")
        }
    }
}
