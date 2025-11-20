import Foundation

struct Customer: Identifiable {
    // Use 'no' as a stable identifier for UI list identity; store BC GUID separately
    var id: String { no }

    let bcId: String
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

    // No Codable conformance: this model is built from DTOs
}
