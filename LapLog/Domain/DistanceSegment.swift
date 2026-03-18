import Foundation

struct DistanceSegment: Codable, Identifiable, Equatable {
    var id: UUID
    var distanceMeters: Double
    /// Number of repeats for this segment. `nil` means unlimited (open-ended).
    var repeatCount: Int?
    /// Rest duration in seconds after completing this segment's repeats. `nil` means manual (user ends rest).
    var restSeconds: Int?
    /// Target pace in seconds per kilometer. `nil` means no pace target.
    var targetPaceSecondsPerKm: Double?
    /// Target time in seconds for the segment distance. `nil` means no time target.
    var targetTimeSeconds: Double?

    init(id: UUID = UUID(), distanceMeters: Double = 400, repeatCount: Int? = nil, restSeconds: Int? = nil,
         targetPaceSecondsPerKm: Double? = nil, targetTimeSeconds: Double? = nil) {
        self.id = id
        self.distanceMeters = distanceMeters
        self.repeatCount = repeatCount
        self.restSeconds = restSeconds
        self.targetPaceSecondsPerKm = targetPaceSecondsPerKm
        self.targetTimeSeconds = targetTimeSeconds
    }

    /// Effective target time derived from either direct time or pace × distance.
    var effectiveTargetTimeSeconds: Double? {
        if let time = targetTimeSeconds { return time }
        if let pace = targetPaceSecondsPerKm {
            return pace * (distanceMeters / 1000.0)
        }
        return nil
    }

    static let `default` = DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: nil)
}
