import Foundation

package enum PolicyChange: Equatable {
    case rate(Double)       // fractional (e.g. 0.125 for 12.5%)
    case reserve(Double)    // fractional
    case controls(Double)   // 0...1
}

extension PolicyChange {
    package var summaryLabel: String {
        switch self {
        case .rate(let value):
            return String(format: "rate %.2f%%", value * 100)
        case .reserve(let value):
            return String(format: "reserve %.1f%%", value * 100)
        case .controls(let value):
            return String(format: "controls %.0f/10", value * 10)
        }
    }
}
