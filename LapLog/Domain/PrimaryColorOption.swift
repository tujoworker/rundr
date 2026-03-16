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
        case .blue:
            return "Blue"
        case .green:
            return "Green"
        case .yellow:
            return "Yellow"
        case .orange:
            return "Orange"
        case .pink:
            return "Pink"
        case .white:
            return "White"
        case .dark:
            return "Dark"
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
            return Color(red: 0.22, green: 0.22, blue: 0.25)
        }
    }
}
