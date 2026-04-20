import Foundation

enum CommunicationStance: String, Codable, CaseIterable {
    case hawkish
    case balanced
    case dovish
    case opaque

    var displayName: String { rawValue.capitalized }
    var dashboardLabel: String { rawValue.uppercased() }
}
