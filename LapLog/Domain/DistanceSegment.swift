import Foundation

struct DistanceSegment: Codable, Identifiable, Equatable {
    var id: UUID
    var distanceMeters: Double
    /// Number of repeats for this segment. `nil` means unlimited (open-ended).
    var repeatCount: Int?

    init(id: UUID = UUID(), distanceMeters: Double = 400, repeatCount: Int? = nil) {
        self.id = id
        self.distanceMeters = distanceMeters
        self.repeatCount = repeatCount
    }

    static let `default` = DistanceSegment(distanceMeters: 400, repeatCount: nil)
}
