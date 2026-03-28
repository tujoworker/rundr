import Foundation

enum RestMode: String, CaseIterable, Identifiable, Codable {
    case manual
    case autoDetect

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual:
            return String(localized: "Manual", comment: "Rest mode: manual")
        case .autoDetect:
            return String(localized: "Auto-detect", comment: "Rest mode: auto detect")
        }
    }
}