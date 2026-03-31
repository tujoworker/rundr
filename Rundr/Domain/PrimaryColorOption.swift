import SwiftUI

enum PrimaryColorOption: String, CaseIterable, Identifiable, Codable {
    case blue
    case green
    case yellow
    case red
    case pink
    case violet
    case dark = "black"

    static var allCases: [PrimaryColorOption] {
        [.blue, .green, .yellow, .red, .pink, .violet, .dark]
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return L10n.blue
        case .green: return L10n.green
        case .yellow: return L10n.yellow
        case .red: return L10n.red
        case .pink: return L10n.pink
        case .violet: return L10n.violet
        case .dark: return L10n.dark
        }
    }

    var color: Color {
        switch self {
        case .blue:
            return Color(red: 0, green: 101 / 255.0, blue: 219 / 255.0)  // #0065DB
        case .green:
            return Color(red: 0, green: 0x90 / 255.0, blue: 0x2F / 255.0)  // #00902F
        case .yellow:
            return Color(red: 0x7D / 255.0, green: 0x69 / 255.0, blue: 0x0E / 255.0)  // #7D690E
        case .red:
            return Color(red: 0xC1 / 255.0, green: 0x34 / 255.0, blue: 0)  // #C13400
        case .pink:
            return Color(red: 0x68 / 255.0, green: 0x0B / 255.0, blue: 0x37 / 255.0)  // #680B37
        case .violet:
            return Color(red: 0x37 / 255.0, green: 0x2A / 255.0, blue: 0x43 / 255.0)  // #372A43
        case .dark:
            return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }
}
