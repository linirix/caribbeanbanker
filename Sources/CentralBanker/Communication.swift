import Foundation

package enum CommunicationStance: String, Codable, CaseIterable {
    case hawkish
    case balanced
    case dovish
    case opaque

    package var displayName: String { rawValue.capitalized }
    package var dashboardLabel: String { rawValue.uppercased() }
}
