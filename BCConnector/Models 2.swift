import Foundation

struct Customer: Identifiable {
    // Use 'no' as a stable identifier for UI list identity; store BC GUID separately
    var id: String { no }

    let bcId: String
    let no: String
    let displayNameOrName: String
    var address: String
    var city: String
    var county: String
    var postCode: String
    var countryRegionCode: String
    let balance: Double
    let creditLimitLCY: Double
    let paymentTermsCode: String
    let salespersonCode: String
    let customerPostingGroup: String
    let genBusPostingGroup: String
    var phoneNumber: String?
    var email: String?

    // No Codable conformance: this model is built from DTOs
}
