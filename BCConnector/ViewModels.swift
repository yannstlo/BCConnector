import Foundation
import SwiftUI

@MainActor
class CustomersViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    
    @ObservedObject private var settings = SettingsManager.shared
    
    @Published var errorMessage: String?

    func fetchCustomers() async {
        do {
            let path = "api/v2.0/companies(\(settings.companyId))/customers"
            let response: BusinessCentralResponse<CustomerDTO> = try await APIClient.shared.fetch(path)
            customers = response.value.map(Customer.init(dto:))
            errorMessage = nil
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
        print(errorMessage ?? "No error")
    }
    
    private func handleAPIError(_ error: APIError) {
        switch error {
        case .authenticationError:
            errorMessage = "Authentication error: Please check your credentials and try logging in again."
        case .invalidURL:
            errorMessage = "Invalid URL: Please check your Business Central settings."
        case .networkError(let message):
            errorMessage = "Network error: \(message)"
        case .httpError(let statusCode, let errorResponse):
            switch statusCode {
            case 403:
                errorMessage = "Authorization error: You might not have permission to access customer data."
            case 404:
                errorMessage = "Not Found error: The customer data resource might not exist."
            default:
                errorMessage = "HTTP error: Status code \(statusCode)"
            }
            if let errorDetails = errorResponse?.error {
                errorMessage! += " - \(errorDetails.message)"
            }
        case .decodingError(let message):
            errorMessage = "Decoding error: \(message). Please check if the API response structure has changed."
        default:
            errorMessage = "Unknown error: \(error.localizedDescription)"
        }
    }

    func searchCustomers(query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            await fetchCustomers()
            return
        }
        do {
            let esc = q.replacingOccurrences(of: "'", with: "''")
            // Search in displayName, number, city
            let filter = "$filter=contains(displayName,'\(esc)') or contains(number,'\(esc)') or contains(city,'\(esc)')"
            let path = "api/v2.0/companies(\(settings.companyId))/customers?\(filter)&$top=50"
            let response: BusinessCentralResponse<CustomerDTO> = try await APIClient.shared.fetch(path)
            customers = response.value.map(Customer.init(dto:))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
class VendorsViewModel: ObservableObject {
    @Published var vendors: [Vendor] = []
    @Published var errorMessage: String?
    
    @ObservedObject private var settings = SettingsManager.shared

    func fetchVendors() async {
        do {
            let path = "api/v2.0/companies(\(settings.companyId))/vendors"
            let response: BusinessCentralResponse<VendorDTO> = try await APIClient.shared.fetch(path)
            vendors = response.value.map(Vendor.init(dto:))
            errorMessage = nil
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
        print(errorMessage ?? "No error")
    }
    
    private func handleAPIError(_ error: APIError) {
        switch error {
        case .authenticationError:
            errorMessage = "Authentication error: Please check your credentials and try logging in again."
        case .invalidURL:
            errorMessage = "Invalid URL: Please check your Business Central settings."
        case .networkError(let message):
            errorMessage = "Network error: \(message)"
        case .httpError(let statusCode, let errorResponse):
            switch statusCode {
            case 403:
                errorMessage = "Authorization error: You might not have permission to access vendor data."
            case 404:
                errorMessage = "Not Found error: The vendor data resource might not exist."
            default:
                errorMessage = "HTTP error: Status code \(statusCode)"
            }
            if let errorDetails = errorResponse?.error {
                errorMessage! += " - \(errorDetails.message)"
            }
        case .decodingError(let message):
            errorMessage = "Decoding error: \(message). Please check if the API response structure has changed."
        default:
            errorMessage = "Unknown error: \(error.localizedDescription)"
        }
    }

    func searchVendors(query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            await fetchVendors()
            return
        }
        do {
            let esc = q.replacingOccurrences(of: "'", with: "''")
            let filter = "$filter=contains(displayName,'\(esc)') or contains(number,'\(esc)')"
            let path = "api/v2.0/companies(\(settings.companyId))/vendors?\(filter)&$top=50"
            let response: BusinessCentralResponse<VendorDTO> = try await APIClient.shared.fetch(path)
            vendors = response.value.map(Vendor.init(dto:))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
class OrdersViewModel: ObservableObject {
    @Published var orders: [OrderDTO] = []
    
    @ObservedObject private var settings = SettingsManager.shared
    
    func fetchOrders() async {
        do {
            let select = "$select=id,number,status,orderDate,totalAmountIncludingTax,totalAmountExcludingTax,customerName,fullyShipped"
            let orderBy = "$orderby=orderDate desc"
            let path = "api/v2.0/companies(\(settings.companyId))/salesOrders?\(select)&\(orderBy)&$top=50"
            let dtos: [OrderDTO] = try await APIClient.shared.fetchPaged(path)
            orders = dtos
        } catch {
            print("Error fetching orders: \(error)")
        }
    }

    func searchOrders(query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            await fetchOrders()
            return
        }
        do {
            let esc = q.replacingOccurrences(of: "'", with: "''")
            let select = "$select=id,number,status,orderDate,totalAmountIncludingTax,totalAmountExcludingTax,customerName,fullyShipped"
            let filter = "$filter=contains(number,'\(esc)') or contains(customerName,'\(esc)') or contains(status,'\(esc)')"
            let orderBy = "$orderby=orderDate desc"
            let path = "api/v2.0/companies(\(settings.companyId))/salesOrders?\(select)&\(filter)&\(orderBy)&$top=50"
            let dtos: [OrderDTO] = try await APIClient.shared.fetchPaged(path)
            orders = dtos
        } catch {
            print("Error searching orders: \(error)")
        }
    }
}

@MainActor
class ItemsSearchAdapter: ObservableObject {
    @ObservedObject private var settings = SettingsManager.shared
    func searchItems(query: String) async throws -> [ItemDTO] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return [] }
        let esc = q.replacingOccurrences(of: "'", with: "''")
        let select = "$select=id,number,displayName"
        let filter = "$filter=contains(displayName,'\(esc)') or contains(number,'\(esc)')"
        let path = "api/v2.0/companies(\(settings.companyId))/items?\(select)&\(filter)&$top=50"
        let resp: BusinessCentralResponse<ItemDTO> = try await APIClient.shared.fetch(path)
        return resp.value
    }
}

@MainActor
class ItemsViewModel: ObservableObject {
    @Published var items: [ItemDTO] = []
    @ObservedObject private var settings = SettingsManager.shared
    @Published var errorMessage: String?

    func fetchItems() async {
        do {
            let select = "$select=id,number,displayName"
            let path = "api/v2.0/companies(\(settings.companyId))/items?\(select)&$top=100"
            let resp: BusinessCentralResponse<ItemDTO> = try await APIClient.shared.fetch(path)
            items = resp.value
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
