import Foundation

struct DistanceSegment: Codable, Identifiable, Equatable {
    var id: UUID
    var distanceMeters: Double
    /// Number of repeats for this segment. `nil` means unlimited (open-ended).
    var repeatCount: Int?
    /// Rest duration in seconds after completing this segment's repeats. `nil` means manual (user ends rest).
    var restSeconds: Int?

    init(id: UUID = UUID(), distanceMeters: Double = 400, repeatCount: Int? = nil, restSeconds: Int? = nil) {
        self.id = id
        self.distanceMeters = distanceMeters
        self.repeatCount = repeatCount
        self.restSeconds = restSeconds
    }

    static let `default` = DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: nil)
}
