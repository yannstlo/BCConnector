import Foundation
import SwiftUI

@MainActor
class CustomersViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    
    @ObservedObject private var settings = SettingsManager.shared
    
    @Published var errorMessage: String?

    func fetchCustomers() async {
        do {
            let response: BusinessCentralResponse<Customer> = try await APIClient.shared.fetch("companies(\(settings.companyId))/customers")
            customers = response.value
            errorMessage = nil
        } catch let error as APIError {
            switch error {
            case .authenticationError:
                errorMessage = "Authentication error: Please check your credentials and try logging in again."
            case .invalidURL:
                errorMessage = "Invalid URL: Please check your Business Central settings."
            case .networkError(let message):
                errorMessage = "Network error: \(message)"
            case .httpError(let statusCode):
                switch statusCode {
                case 403:
                    errorMessage = "Authorization error: You might not have permission to access customer data."
                case 404:
                    errorMessage = "Not Found error: The customer data resource might not exist."
                default:
                    errorMessage = "HTTP error: Status code \(statusCode)"
                }
            case .decodingError(let message):
                errorMessage = "Decoding error: \(message)"
            default:
                errorMessage = "Unknown error: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
        print(errorMessage ?? "No error")
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
