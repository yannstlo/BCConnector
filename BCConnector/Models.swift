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
