import Foundation

enum SegmentRecoveryType: String, Codable, Equatable, Hashable {
    case none
    case rest
    case activeRecovery

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.none.rawValue:
            self = .none
        case Self.rest.rawValue:
            self = .rest
        case Self.activeRecovery.rawValue, "jog":
            self = .activeRecovery
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid SegmentRecoveryType value: \(rawValue)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum DistanceGoalMode: String, Codable, Equatable, Hashable {
    case distance
    case time

    static var fixed: Self { .distance }
    static var open: Self { .time }

    var isTimeBased: Bool {
        self == .time
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.distance.rawValue, "fixed":
            self = .distance
        case Self.time.rawValue, "open":
            self = .time
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid DistanceGoalMode value: \(rawValue)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct DistanceSegment: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String?
    var distanceMeters: Double
    var distanceGoalMode: DistanceGoalMode
    /// Number of repeats for this segment. `nil` means unlimited (open-ended).
    var repeatCount: Int?
    /// Recovery type after each active repeat. `.none` disables inserted recovery laps.
    var recoveryType: SegmentRecoveryType
    /// Recovery duration in seconds after non-final repeats in this segment. `nil` means manual.
    var restSeconds: Int?
    /// Optional final recovery duration before the next segment begins. Used for any enabled recovery type.
    var lastRestSeconds: Int?
    /// Target pace in seconds per kilometer. `nil` means no pace target.
    var targetPaceSecondsPerKm: Double?
    /// Target time in seconds for the segment distance. `nil` means no time target.
    var targetTimeSeconds: Double?

    init(id: UUID = UUID(), name: String? = nil, distanceMeters: Double = 400, repeatCount: Int? = nil,
         recoveryType: SegmentRecoveryType? = nil, restSeconds: Int? = nil,
         lastRestSeconds: Int? = nil,
         distanceGoalMode: DistanceGoalMode = .fixed,
         targetPaceSecondsPerKm: Double? = nil, targetTimeSeconds: Double? = nil) {
        let resolvedRecoveryType = recoveryType ?? ((restSeconds != nil || lastRestSeconds != nil) ? .rest : .none)
        self.id = id
        self.name = SegmentEditorValueRules.normalizedName(name)
        self.distanceMeters = distanceMeters
        self.distanceGoalMode = distanceGoalMode
        self.repeatCount = repeatCount
        self.recoveryType = resolvedRecoveryType
        self.restSeconds = restSeconds
        self.lastRestSeconds = resolvedRecoveryType == .none ? nil : lastRestSeconds
        self.targetPaceSecondsPerKm = targetPaceSecondsPerKm
        self.targetTimeSeconds = targetTimeSeconds
    }

    init(id: UUID = UUID(), name: String? = nil, distanceMeters: Double = 400, repeatCount: Int? = nil,
         restSeconds: Int? = nil,
         lastRestSeconds: Int? = nil,
         distanceGoalMode: DistanceGoalMode = .fixed,
         targetPaceSecondsPerKm: Double? = nil, targetTimeSeconds: Double? = nil) {
        self.init(
            id: id,
            name: name,
            distanceMeters: distanceMeters,
            repeatCount: repeatCount,
            recoveryType: nil,
            restSeconds: restSeconds,
            lastRestSeconds: lastRestSeconds,
            distanceGoalMode: distanceGoalMode,
            targetPaceSecondsPerKm: targetPaceSecondsPerKm,
            targetTimeSeconds: targetTimeSeconds
        )
    }

    var trimmedName: String? {
        SegmentEditorValueRules.normalizedName(name)
    }

    var usesOpenDistance: Bool {
        distanceGoalMode.isTimeBased
    }

    var usesRecovery: Bool {
        recoveryType != .none
    }

    var usesRestRecovery: Bool {
        recoveryType == .rest
    }

    var usesActiveRecovery: Bool {
        recoveryType == .activeRecovery
    }

    var intervalRowPrimaryLabel: String {
        usesOpenDistance ? L10n.time : L10n.distance
    }

    var intervalRowShowsPrimaryMetricInDetails: Bool {
        trimmedName != nil
    }

    func intervalRowPrimaryValue(unit: DistanceUnit) -> String {
        if usesOpenDistance {
            return effectiveTargetTimeSeconds.map { Formatters.compactTimeString(from: $0) } ?? L10n.time
        }

        return Formatters.distanceString(meters: distanceMeters, unit: unit)
    }

    func intervalRowHeadline(unit: DistanceUnit) -> String {
        trimmedName ?? intervalRowPrimaryValue(unit: unit)
    }

    /// Effective target time derived from either direct time or pace × distance.
    var effectiveTargetTimeSeconds: Double? {
        if let time = targetTimeSeconds { return time }
        guard !usesOpenDistance else { return nil }
        if let pace = targetPaceSecondsPerKm {
            return pace * (distanceMeters / 1000.0)
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case distanceMeters
        case distanceGoalMode
        case repeatCount
        case recoveryType
        case restSeconds
        case lastRestSeconds
        case targetPaceSecondsPerKm
        case targetTimeSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = SegmentEditorValueRules.normalizedName(try container.decodeIfPresent(String.self, forKey: .name))
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters) ?? DistanceSegment.default.distanceMeters
        distanceGoalMode = try container.decodeIfPresent(DistanceGoalMode.self, forKey: .distanceGoalMode) ?? .fixed
        repeatCount = try container.decodeIfPresent(Int.self, forKey: .repeatCount)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
        lastRestSeconds = try container.decodeIfPresent(Int.self, forKey: .lastRestSeconds)
        recoveryType = try container.decodeIfPresent(SegmentRecoveryType.self, forKey: .recoveryType)
            ?? ((restSeconds != nil || lastRestSeconds != nil) ? .rest : .none)
        if recoveryType == .none {
            lastRestSeconds = nil
        }
        targetPaceSecondsPerKm = try container.decodeIfPresent(Double.self, forKey: .targetPaceSecondsPerKm)
        targetTimeSeconds = try container.decodeIfPresent(Double.self, forKey: .targetTimeSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(trimmedName, forKey: .name)
        try container.encode(distanceMeters, forKey: .distanceMeters)
        try container.encode(distanceGoalMode, forKey: .distanceGoalMode)
        try container.encodeIfPresent(repeatCount, forKey: .repeatCount)
        try container.encode(recoveryType, forKey: .recoveryType)
        try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
        try container.encodeIfPresent(lastRestSeconds, forKey: .lastRestSeconds)
        try container.encodeIfPresent(targetPaceSecondsPerKm, forKey: .targetPaceSecondsPerKm)
        try container.encodeIfPresent(targetTimeSeconds, forKey: .targetTimeSeconds)
    }

    static let `default` = DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: nil)
}
