import Foundation

enum TrackingMode: String, Codable, CaseIterable, Identifiable {
    case gps
    case dual
    case distanceDistance

    static var allCases: [TrackingMode] {
        [.distanceDistance, .dual, .gps]
    }

    var id: String { rawValue }

    var usesGPSDistance: Bool {
        switch self {
        case .gps, .dual:
            return true
        case .distanceDistance:
            return false
        }
    }

    var usesManualIntervals: Bool {
        switch self {
        case .gps:
            return false
        case .dual, .distanceDistance:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .gps:
            return String(localized: "GPS", comment: "Tracking mode")
        case .dual:
            return String(localized: "Dual", comment: "Tracking mode")
        case .distanceDistance:
            return String(localized: "Manual", comment: "Tracking mode")
        }
    }
}
