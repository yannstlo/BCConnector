import Foundation

struct Customer: Identifiable, Codable {
    let no: String
    let displayName: String?
    let name: String?
    let phoneNumber: String?
    let email: String?
    
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
    }
}

struct Vendor: Identifiable, Codable {
    let id: String
    let displayName: String
    let email: String
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
