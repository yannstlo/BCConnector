import Foundation
import SwiftUI

@MainActor
class CustomersViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    private var allCustomers: [Customer] = []
    
    @ObservedObject private var settings = SettingsManager.shared
    
    @Published var errorMessage: String?

    func fetchCustomers() async {
        do {
            let path = APIClient.shared.companiesPath("customers")
            let response: BusinessCentralResponse<CustomerDTO> = try await APIClient.shared.fetch(path)
            let mapped = response.value.map(Customer.init(dto:))
            allCustomers = mapped
            customers = mapped
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
            // Restore to full list without re-fetch to keep UI snappy
            customers = allCustomers
            errorMessage = nil
            return
        }
        do {
            let esc = q.replacingOccurrences(of: "'", with: "''")
            // Search in displayName, number, city
            let filter = "$filter=contains(displayName,'\(esc)') or contains(number,'\(esc)') or contains(city,'\(esc)')"
            let path = APIClient.shared.companiesPath("customers?\(filter)&$top=50")
            let response: BusinessCentralResponse<CustomerDTO> = try await APIClient.shared.fetch(path)
            customers = response.value.map(Customer.init(dto:))
            errorMessage = nil
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
    }

    // Instant local filter for better UX; remote search will refine results
    func applyLocalFilter(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { customers = allCustomers; return }
        let lower = q.lowercased()
        customers = allCustomers.filter { c in
            c.displayNameOrName.lowercased().contains(lower) ||
            c.no.lowercased().contains(lower) ||
            c.city.lowercased().contains(lower)
        }
    }
}

@MainActor
class VendorsViewModel: ObservableObject {
    @Published var vendors: [Vendor] = []
    private var allVendors: [Vendor] = []
    @Published var errorMessage: String?
    
    @ObservedObject private var settings = SettingsManager.shared

    func fetchVendors() async {
        do {
            let path = APIClient.shared.companiesPath("vendors")
            let response: BusinessCentralResponse<VendorDTO> = try await APIClient.shared.fetch(path)
            let mapped = response.value.map(Vendor.init(dto:))
            allVendors = mapped
            vendors = mapped
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
            vendors = allVendors
            errorMessage = nil
            return
        }
        do {
            let esc = q.replacingOccurrences(of: "'", with: "''")
            let filter = "$filter=contains(displayName,'\(esc)') or contains(number,'\(esc)') or contains(city,'\(esc)')"
            let path = APIClient.shared.companiesPath("vendors?\(filter)&$top=50")
            let response: BusinessCentralResponse<VendorDTO> = try await APIClient.shared.fetch(path)
            vendors = response.value.map(Vendor.init(dto:))
            errorMessage = nil
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
    }

    func applyLocalFilter(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { vendors = allVendors; return }
        let lower = q.lowercased()
        vendors = allVendors.filter { v in
            v.name.lowercased().contains(lower) ||
            v.no.lowercased().contains(lower) ||
            v.city.lowercased().contains(lower)
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
            let path = APIClient.shared.companiesPath("salesOrders?\(select)&\(orderBy)&$top=50")
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
            let path = APIClient.shared.companiesPath("salesOrders?\(select)&\(filter)&\(orderBy)&$top=50")
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
        let path = APIClient.shared.companiesPath("items?\(select)&\(filter)&$top=50")
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
            let path = APIClient.shared.companiesPath("items?\(select)&$top=100")
            let resp: BusinessCentralResponse<ItemDTO> = try await APIClient.shared.fetch(path)
            items = resp.value
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
class CustomerContactsViewModel: ObservableObject {
    @Published var contacts: [BCContactDTO] = []
    @Published var errorMessage: String?
    @ObservedObject private var settings = SettingsManager.shared

    func fetch(for customer: Customer) async {
        do {
            // Step 1: fetch business relations for this company/customer number
            let custNo = customer.no.replacingOccurrences(of: "'", with: "''")
            var rels: [ContactBusinessRelationDTO] = []
            if !custNo.isEmpty {
                let relPath = APIClient.shared.companiesPath("contactBusinessRelations?$filter=companyNumber eq '\(custNo)' or customerNumber eq '\(custNo)'&$select=id,contactNumber,contactId")
                let relResp: BusinessCentralResponse<ContactBusinessRelationDTO> = try await APIClient.shared.fetch(relPath)
                rels = relResp.value
            }

            // Step 2: fetch contacts for those relation contact numbers
            var contactsList: [BCContactDTO] = []
            let numbers = Array(Set(rels.compactMap { $0.contactNumber })).filter { !$0.isEmpty }
            if !numbers.isEmpty {
                let filt = numbers.map { "contactNumber eq '\($0.replacingOccurrences(of: "'", with: "''"))'" }.joined(separator: " or ")
                let path = APIClient.shared.companiesPath("contacts?$filter=\(filt)&$top=200")
                let resp: BusinessCentralResponse<BCContactDTO> = try await APIClient.shared.fetch(path)
                contactsList = resp.value
            } else if custNo.isEmpty == false {
                // Fallback: attempt to filter contacts by companyNumber when no relations found
                let path = APIClient.shared.companiesPath("contacts?$filter=companyNumber eq '\(custNo)'&$top=50")
                let resp: BusinessCentralResponse<BCContactDTO> = try await APIClient.shared.fetch(path)
                contactsList = resp.value
            }

            await MainActor.run {
                self.contacts = contactsList
                self.errorMessage = nil
            }

            // Cache count for this customer
            ContactCountCache.shared.setCount(contactsList.count, for: settings.companyId, customerNo: customer.no)
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Lightweight contact count cache
final class ContactCountCache {
    static let shared = ContactCountCache()
    private init() {}
    private let defaults = UserDefaults.standard
    private let ttl: TimeInterval = 6 * 60 * 60 // 6 hours

    private func key(_ companyId: String, _ customerNo: String) -> String { "contactCount::\(companyId)::\(customerNo)" }

    func getCount(for companyId: String, customerNo: String) -> Int? {
        let k = key(companyId, customerNo)
        guard let entry = defaults.object(forKey: k) as? [String: Any],
              let ts = entry["ts"] as? TimeInterval,
              let value = entry["count"] as? Int else { return nil }
        if Date().timeIntervalSince1970 - ts > ttl { return nil }
        return value
    }

    func setCount(_ count: Int, for companyId: String, customerNo: String) {
        let k = key(companyId, customerNo)
        defaults.set(["ts": Date().timeIntervalSince1970, "count": count], forKey: k)
    }

    func invalidate(for companyId: String, customerNo: String) {
        defaults.removeObject(forKey: key(companyId, customerNo))
    }
}
