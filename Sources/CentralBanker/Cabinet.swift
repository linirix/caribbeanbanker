import Foundation

package enum CabinetRequestType: String, Codable, CaseIterable {
    case cutRates
    case tightenControls
    case defendCurrency

    package var title: String {
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

package struct CabinetRequest: Codable {
    package var type: CabinetRequestType
    package var detail: String

    package var title: String { type.title }
}
