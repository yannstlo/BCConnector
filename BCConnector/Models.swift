import Foundation

struct Customer: Identifiable, Codable {
    let no: String
    let displayName: String?
    let name: String?
    let phoneNumber: String?
    let email: String?
    let address: String
    let city: String
    let county: String
    let postCode: String
    let countryRegionCode: String
    let balance: Double
    let creditLimitLCY: Double
    let paymentTermsCode: String
    let salespersonCode: String
    let customerPostingGroup: String
    let genBusPostingGroup: String
    
    var id: String { no }
    
    var displayNameOrName: String {
        displayName ?? name ?? "Unknown"
    }
    
    enum CodingKeys: String, CodingKey {
        case no
        case displayName
        case name
        case phoneNumber
        case email
        case address
        case city
        case county
        case postCode
        case countryRegionCode
        case balance
        case creditLimitLCY
        case paymentTermsCode
        case salespersonCode
        case customerPostingGroup
        case genBusPostingGroup
    }
}

struct Vendor: Identifiable, Codable {
    let no: String
    let displayName: String
    let name: String?
    let address: String
    let city: String
    let county: String
    let postCode: String
    let countryRegionCode: String
    let phoneNumber: String?
    let email: String?
    
    var id: String { no }
    
    enum CodingKeys: String, CodingKey {
        case no
        case displayName
        case name
        case address
        case city
        case county
        case postCode
        case countryRegionCode
        case phoneNumber
        case email
    }
}

struct Order: Identifiable, Codable {
    let id: String
    let customerName: String
    let orderDate: Date
    let totalAmount: Decimal
}
struct BusinessCentralResponse<T: Codable>: Codable {
    let odataContext: String
    let value: [T]
    
    enum CodingKeys: String, CodingKey {
        case odataContext = "@odata.context"
        case value
    }
}
