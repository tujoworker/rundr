import Foundation

enum TrackingMode: String, Codable, CaseIterable, Identifiable {
    case gps
    case distanceDistance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gps: return L10n.gps
        case .distanceDistance: return L10n.distanceMode
        }
    }
}
