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

extension Customer {
    init(dto: CustomerDTO) {
        self.init(
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
