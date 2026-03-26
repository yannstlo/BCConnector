import Foundation
import SwiftUI

extension Notification.Name {
    static let refreshCustomers = Notification.Name("RefreshCustomers")
    static let refreshVendors = Notification.Name("RefreshVendors")
}

struct CustomerCreateBody: Encodable {
    let displayName: String?
    let addressLine1: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    let phoneNumber: String?
    let email: String?
}

struct VendorCreateBody: Encodable {
    let displayName: String?
    let addressLine1: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    let phoneNumber: String?
    let email: String?
}

struct CreateCustomerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var addressLine1 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Identity") {
                    TextField("Display Name", text: $displayName)
                }
                Section("Address") {
                    TextField("Address", text: $addressLine1)
                    TextField("City", text: $city)
                    TextField("State / Province", text: $state)
                    TextField("Postal Code", text: $postalCode)
                    TextField("Country", text: $country)
                }
                Section("Contact") {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("New Customer")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "Saving..." : "Create") {
                        Task { await save() }
                    }
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let body = CustomerCreateBody(
                displayName: displayName.nilIfBlank,
                addressLine1: addressLine1.nilIfBlank,
                city: city.nilIfBlank,
                state: state.nilIfBlank,
                postalCode: postalCode.nilIfBlank,
                country: country.nilIfBlank,
                phoneNumber: phoneNumber.nilIfBlank,
                email: email.nilIfBlank
            )
            let _: CustomerDTO = try await APIClient.shared.post(APIClient.shared.companiesPath("customers"), body: body)
            NotificationCenter.default.post(name: .refreshCustomers, object: nil)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = userFacingMessage(for: error) }
        }
    }
}

struct CreateVendorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var addressLine1 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Identity") {
                    TextField("Display Name", text: $displayName)
                }
                Section("Address") {
                    TextField("Address", text: $addressLine1)
                    TextField("City", text: $city)
                    TextField("State / Province", text: $state)
                    TextField("Postal Code", text: $postalCode)
                    TextField("Country", text: $country)
                }
                Section("Contact") {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("New Vendor")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "Saving..." : "Create") {
                        Task { await save() }
                    }
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let body = VendorCreateBody(
                displayName: displayName.nilIfBlank,
                addressLine1: addressLine1.nilIfBlank,
                city: city.nilIfBlank,
                state: state.nilIfBlank,
                postalCode: postalCode.nilIfBlank,
                country: country.nilIfBlank,
                phoneNumber: phoneNumber.nilIfBlank,
                email: email.nilIfBlank
            )
            let _: VendorDTO = try await APIClient.shared.post(APIClient.shared.companiesPath("vendors"), body: body)
            NotificationCenter.default.post(name: .refreshVendors, object: nil)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = userFacingMessage(for: error) }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func userFacingMessage(for error: Error) -> String {
    guard let apiError = error as? APIError else {
        return error.localizedDescription
    }

    switch apiError {
    case .invalidURL:
        return "The request URL is invalid."
    case .noData:
        return "The server returned no data."
    case .decodingError(let message):
        return "The server response could not be read. \(message)"
    case .authenticationError(let response):
        return response?.error.message ?? "Authentication failed for this request."
    case .networkError(let message):
        return message
    case .httpError(_, let response):
        return response?.error.message ?? "The server rejected the request."
    case .tokenResponseError(let message):
        return message
    }
}
