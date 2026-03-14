import Foundation

enum TrackingMode: String, Codable, CaseIterable, Identifiable {
    case gps
    case distanceDistance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gps: return "GPS"
        case .distanceDistance: return "Distance"
        }
    }
}
