import Foundation

enum TrackingMode: String, Codable, CaseIterable, Identifiable {
    case gps
    case dual
    case distanceDistance

    static var allCases: [TrackingMode] {
        [.distanceDistance, .dual, .gps]
    }

    static var visibleCases: [TrackingMode] {
        [.distanceDistance, .dual]
    }

    var id: String { rawValue }

    var visibleSelection: TrackingMode {
        switch self {
        case .gps:
            return .dual
        case .dual, .distanceDistance:
            return self
        }
    }

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
            return L10n.dual
        case .dual:
            return L10n.dual
        case .distanceDistance:
            return L10n.distanceMode
        }
    }
}
