import Foundation

enum DistanceUnit: String, CaseIterable, Identifiable {
    case km
    case miles

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .km: return L10n.kilometers
        case .miles: return L10n.miles
        }
    }
}
