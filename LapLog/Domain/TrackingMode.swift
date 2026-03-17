import Foundation

enum TrackingMode: String, Codable, CaseIterable, Identifiable {
    case gps
    case distanceDistance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gps:
            return String(localized: "GPS", comment: "Tracking mode")
        case .distanceDistance:
            return String(localized: "Distance", comment: "Tracking mode")
        }
    }
}
