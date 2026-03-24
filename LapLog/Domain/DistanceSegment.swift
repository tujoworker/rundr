import Foundation

enum DistanceGoalMode: String, Codable, Equatable {
    case fixed
    case open
}

struct DistanceSegment: Codable, Identifiable, Equatable {
    var id: UUID
    var distanceMeters: Double
    var distanceGoalMode: DistanceGoalMode
    /// Number of repeats for this segment. `nil` means unlimited (open-ended).
    var repeatCount: Int?
    /// Rest duration in seconds after completing this segment's repeats. `nil` means manual (user ends rest).
    var restSeconds: Int?
    /// Target pace in seconds per kilometer. `nil` means no pace target.
    var targetPaceSecondsPerKm: Double?
    /// Target time in seconds for the segment distance. `nil` means no time target.
    var targetTimeSeconds: Double?

    init(id: UUID = UUID(), distanceMeters: Double = 400, repeatCount: Int? = nil, restSeconds: Int? = nil,
         distanceGoalMode: DistanceGoalMode = .fixed,
         targetPaceSecondsPerKm: Double? = nil, targetTimeSeconds: Double? = nil) {
        self.id = id
        self.distanceMeters = distanceMeters
        self.distanceGoalMode = distanceGoalMode
        self.repeatCount = repeatCount
        self.restSeconds = restSeconds
        self.targetPaceSecondsPerKm = targetPaceSecondsPerKm
        self.targetTimeSeconds = targetTimeSeconds
    }

    var usesOpenDistance: Bool {
        distanceGoalMode == .open
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
        case distanceMeters
        case distanceGoalMode
        case repeatCount
        case restSeconds
        case targetPaceSecondsPerKm
        case targetTimeSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters) ?? DistanceSegment.default.distanceMeters
        distanceGoalMode = try container.decodeIfPresent(DistanceGoalMode.self, forKey: .distanceGoalMode) ?? .fixed
        repeatCount = try container.decodeIfPresent(Int.self, forKey: .repeatCount)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
        targetPaceSecondsPerKm = try container.decodeIfPresent(Double.self, forKey: .targetPaceSecondsPerKm)
        targetTimeSeconds = try container.decodeIfPresent(Double.self, forKey: .targetTimeSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(distanceMeters, forKey: .distanceMeters)
        try container.encode(distanceGoalMode, forKey: .distanceGoalMode)
        try container.encodeIfPresent(repeatCount, forKey: .repeatCount)
        try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
        try container.encodeIfPresent(targetPaceSecondsPerKm, forKey: .targetPaceSecondsPerKm)
        try container.encodeIfPresent(targetTimeSeconds, forKey: .targetTimeSeconds)
    }

    static let `default` = DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: nil)
}
