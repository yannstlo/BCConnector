import Foundation

public struct CustomerCustomer: Codable, Identifiable {
    public let id: String
    public let number: String?
    public let displayName: String?
    public let type: String?

    // Address
    public let addressLine1: String?
    public let addressLine2: String?
    public let city: String?
    public let state: String?
    public let country: String?
    public let postalCode: String?

    // Contact
    public let phoneNumber: String?
    public let email: String?
    public let website: String?

    // Sales
    public let salespersonCode: String?
    public let balanceDue: Double?
    public let creditLimit: Double?

    // Tax
    public let taxLiable: Bool?
    public let taxAreaId: String?
    public let taxAreaDisplayName: String?
    public let taxRegistrationNumber: String?

    // Currency & terms
    public let currencyId: String?
    public let currencyCode: String?
    public let paymentTermsId: String?
    public let shipmentMethodId: String?
    public let paymentMethodId: String?

    // Misc
    public let blocked: String?
    public let lastModifiedDateTime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case displayName = "display_name"
        case type

        case addressLine1 = "address_line_1"
        case addressLine2 = "address_line_2"
        case city
        case state
        case country
        case postalCode = "postal_code"

        case phoneNumber = "phone_number"
        case email
        case website

        case salespersonCode = "salesperson_code"
        case balanceDue = "balance_due"
        case creditLimit = "credit_limit"

        case taxLiable = "tax_liable"
        case taxAreaId = "tax_area_id"
        case taxAreaDisplayName = "tax_area_display_name"
        case taxRegistrationNumber = "tax_registration_number"

        case currencyId = "currency_id"
        case currencyCode = "currency_code"
        case paymentTermsId = "payment_terms_id"
        case shipmentMethodId = "shipment_method_id"
        case paymentMethodId = "payment_method_id"

        case blocked
        case lastModifiedDateTime = "last_modified_date_time"
    }
}
