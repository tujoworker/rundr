import Foundation

enum PauseMode: String, CaseIterable, Identifiable, Codable {
    case manual
    case autoDetect

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual:
            return String(localized: "Manual", comment: "Pause mode: manual")
        case .autoDetect:
            return String(localized: "Auto", comment: "Pause mode: auto detect")
        }
    }
}
