import Foundation

enum LapType: String, Codable, CaseIterable, Identifiable {
    case active
    case rest
    case jog

    var id: String { rawValue }

    var isRecovery: Bool {
        self != .active
    }

    var displayName: String {
        switch self {
        case .active:
            return String(localized: "Activity", comment: "Lap type")
        case .rest:
            return String(localized: "Rest", comment: "Lap type")
        case .jog:
            return L10n.jog
        }
    }
}
