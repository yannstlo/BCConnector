import Foundation

struct Customer: Identifiable, Codable {
    // Use 'no' as a stable identifier if there is no explicit 'id' from the API
    var id: String { no }

    let no: String
    let displayNameOrName: String
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

    enum CodingKeys: String, CodingKey {
        case no
        case displayNameOrName = "displayName" // change to "name" if your API returns name instead
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
