import Foundation

enum DistanceUnit: String, CaseIterable, Identifiable, Codable {
    case km
    case miles

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .km:
            return String(localized: "Kilometers", comment: "Unit")
        case .miles:
            return String(localized: "Miles", comment: "Unit")
        }
    }
}
