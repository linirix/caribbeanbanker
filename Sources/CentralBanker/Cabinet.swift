import Foundation

enum CabinetRequestType: String, Codable, CaseIterable {
    case cutRates
    case tightenControls
    case defendCurrency

    var title: String {
        switch self {
        case .cutRates:
            return "Cut Rates Now"
        case .tightenControls:
            return "Tighten Capital Controls"
        case .defendCurrency:
            return "Defend The Currency"
        }
    }
}

struct CabinetRequest: Codable {
    var type: CabinetRequestType
    var detail: String

    var title: String { type.title }
}
