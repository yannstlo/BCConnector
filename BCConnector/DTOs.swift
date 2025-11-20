import Foundation

struct CustomerDTO: Codable, Identifiable {
    let id: String
    let number: String?
    let displayName: String?
    let type: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let state: String?
    let country: String?
    let postalCode: String?
    let phoneNumber: String?
    let email: String?
    let website: String?
    let salespersonCode: String?
    let balanceDue: Double?
    let creditLimit: Double?
    let paymentTermsId: String?
    let lastModifiedDateTime: String?
}

// Items
struct ItemDTO: Codable, Identifiable {
    let id: String
    let number: String?
    let displayName: String?
    let description: String?
}

// Rich item detail DTO (optional fields mapped if available)
struct ItemDetailDTO: Codable, Identifiable {
    let id: String
    let number: String?
    let displayName: String?
    let type: String?
    let itemCategoryCode: String?
    let blocked: Bool?
    let baseUnitOfMeasureId: String?
    let baseUnitOfMeasure: String?
    let gtin: String?
    let unitPrice: Decimal?
    let unitCost: Decimal?
    let inventory: Decimal?
    let grossWeight: Decimal?
    let netWeight: Decimal?
    let shelfNo: String?
    let createdDateTime: String?
    let lastModifiedDateTime: String?
}

extension Customer {
    init(dto: CustomerDTO) {
        self.init(
            bcId: dto.id,
            no: dto.number ?? "",
            displayNameOrName: dto.displayName ?? "",
            address: dto.addressLine1 ?? "",
            city: dto.city ?? "",
            county: dto.state ?? "",
            postCode: dto.postalCode ?? "",
            countryRegionCode: dto.country ?? "",
            balance: dto.balanceDue ?? 0,
            creditLimitLCY: dto.creditLimit ?? 0,
            paymentTermsCode: dto.paymentTermsId ?? "",
            salespersonCode: dto.salespersonCode ?? "",
            customerPostingGroup: "",
            genBusPostingGroup: ""
        )
    }
}
