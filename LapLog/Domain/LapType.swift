import Foundation

enum LapType: String, Codable, CaseIterable, Identifiable {
    case active
    case rest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: return L10n.activity
        case .rest: return L10n.restLap
        }
    }
}
