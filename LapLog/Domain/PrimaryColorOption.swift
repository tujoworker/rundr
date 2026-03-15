import SwiftUI

enum PrimaryColorOption: String, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case pink
    case white

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue:
            return "Blue"
        case .green:
            return "Green"
        case .orange:
            return "Orange"
        case .pink:
            return "Pink"
        case .white:
            return "White"
        }
    }

    var color: Color {
        switch self {
        case .blue:
            return Color(red: 0.09, green: 0.48, blue: 0.93)
        case .green:
            return Color(red: 0.14, green: 0.72, blue: 0.33)
        case .orange:
            return Color(red: 0.95, green: 0.51, blue: 0.17)
        case .pink:
            return Color(red: 0.96, green: 0.27, blue: 0.62)
        case .white:
            return Color.white
        }
    }
}
