import SwiftUI

enum PrimaryColorOption: String, CaseIterable, Identifiable {
    case blue
    case green
    case yellow
    case orange
    case pink
    case white
    case dark = "black"

    static var allCases: [PrimaryColorOption] {
        [.blue, .green, .yellow, .orange, .pink, .white, .dark]
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return L10n.blue
        case .green: return L10n.green
        case .yellow: return L10n.yellow
        case .orange: return L10n.orange
        case .pink: return L10n.pink
        case .white: return L10n.white
        case .dark: return L10n.dark
        }
    }

    var color: Color {
        switch self {
        case .blue:
            return Color(red: 0.09, green: 0.48, blue: 0.93)
        case .green:
            return Color(red: 0.14, green: 0.72, blue: 0.33)
        case .yellow:
            return Color(red: 0.67, green: 0.57, blue: 0.12)
        case .orange:
            return Color(red: 0.79, green: 0.32, blue: 0.15)
        case .pink:
            return Color(red: 0.79, green: 0.18, blue: 0.47)
        case .white:
            return Color.white
        case .dark:
            return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }
}
