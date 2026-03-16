import Foundation

enum PauseMode: String, CaseIterable, Identifiable {
    case manual
    case autoDetect

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: return L10n.pauseManual
        case .autoDetect: return L10n.pauseAutoDetect
        }
    }
}
