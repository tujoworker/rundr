import Foundation

enum LapType: String, Codable, CaseIterable, Identifiable {
    case active
    case rest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:
            return String(localized: "Activity", comment: "Lap type")
        case .rest:
            return String(localized: "Rest", comment: "Lap type")
        }
    }
}
