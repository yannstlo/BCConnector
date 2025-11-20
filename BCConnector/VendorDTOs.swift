import Foundation

struct VendorDTO: Codable, Identifiable {
    let id: String?
    let number: String?
    let displayName: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let state: String?
    let country: String?
    let postalCode: String?
    let phoneNumber: String?
    let email: String?
    let paymentTermsId: String?
    let balanceDue: Double?
}

extension Vendor {
    init(dto: VendorDTO) {
        self.init(
            no: dto.number ?? "",
            name: dto.displayName ?? "",
            address: dto.addressLine1 ?? "",
            address2: dto.addressLine2 ?? "",
            city: dto.city ?? "",
            county: dto.state ?? "",
            postCode: dto.postalCode ?? "",
            countryRegionCode: dto.country ?? "",
            phoneNo: dto.phoneNumber ?? "",
            balance: dto.balanceDue ?? 0,
            paymentTermsCode: dto.paymentTermsId ?? "",
            contact: dto.email ?? ""
        )
    }
}
