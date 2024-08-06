import Foundation

struct Customer: Identifiable, Codable {
    let id: String
    let displayName: String
    let email: String
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
