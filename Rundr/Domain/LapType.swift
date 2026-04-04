import Foundation

enum LapType: String, Codable, CaseIterable, Identifiable {
    case active
    case rest
    case activeRecovery

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
        case .activeRecovery:
            return L10n.activeRecovery
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.active.rawValue:
            self = .active
        case Self.rest.rawValue:
            self = .rest
        case Self.activeRecovery.rawValue, "jog":
            self = .activeRecovery
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid LapType value: \(rawValue)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
