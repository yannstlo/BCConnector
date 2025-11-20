import Foundation

struct OrderDTO: Codable, Identifiable {
    let id: String
    let customerName: String?
    let orderDate: String?
    let totalAmountExcludingTax: Decimal?
}

extension Order {
    init(dto: OrderDTO) {
        // Attempt to parse ISO8601 date string; fall back to Date.distantPast
        let parsedDate: Date
        if let str = dto.orderDate {
            let iso = ISO8601DateFormatter()
            parsedDate = iso.date(from: str) ?? Date.distantPast
        } else {
            parsedDate = Date.distantPast
        }
        self.init(
            id: dto.id,
            customerName: dto.customerName ?? "",
            orderDate: parsedDate,
            totalAmount: (dto.totalAmountExcludingTax ?? 0)
        )
    }
}
