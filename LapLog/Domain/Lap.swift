import Foundation
import SwiftData

@Model
final class Lap {
    @Attribute(.unique) var id: UUID
    var index: Int
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var distanceMeters: Double
    var averageSpeedMetersPerSecond: Double
    var averageHeartRateBPM: Double?
    var lapTypeRaw: String
    var sourceRaw: String

    @Relationship(inverse: \Session.laps)
    var session: Session?

    var lapType: LapType {
        get { LapType(rawValue: lapTypeRaw) ?? .active }
        set { lapTypeRaw = newValue.rawValue }
    }

    var source: LapSource {
        get { LapSource(rawValue: sourceRaw) ?? .distanceTap }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        index: Int,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Double,
        distanceMeters: Double,
        averageSpeedMetersPerSecond: Double,
        averageHeartRateBPM: Double? = nil,
        lapType: LapType = .active,
        source: LapSource = .distanceTap
    ) {
        self.id = id
        self.index = index
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.averageHeartRateBPM = averageHeartRateBPM
        self.lapTypeRaw = lapType.rawValue
        self.sourceRaw = source.rawValue
    }
}
