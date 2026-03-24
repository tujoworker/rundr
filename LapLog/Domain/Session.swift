import Foundation
import SwiftData

struct WorkoutPlanSnapshot: Codable, Equatable {
    var trackingMode: TrackingMode
    var distanceLapDistanceMeters: Double?
    var distanceSegments: [DistanceSegment]
    var restMode: RestMode

    init(
        trackingMode: TrackingMode,
        distanceLapDistanceMeters: Double? = nil,
        distanceSegments: [DistanceSegment] = [.default],
        restMode: RestMode = .manual
    ) {
        let normalizedSegments = distanceSegments.isEmpty ? [.default] : distanceSegments
        if trackingMode == .distanceDistance, normalizedSegments.contains(where: \.usesOpenDistance) {
            self.trackingMode = .dual
        } else {
            self.trackingMode = trackingMode
        }
        self.distanceLapDistanceMeters = self.trackingMode.usesManualIntervals
            ? (distanceLapDistanceMeters ?? normalizedSegments.first?.distanceMeters ?? DistanceSegment.default.distanceMeters)
            : nil
        self.distanceSegments = normalizedSegments
        self.restMode = restMode
    }
}

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var modeRaw: String
    var sportVariantRaw: String?
    var distanceLapDistanceMeters: Double?
    var totalDistanceMeters: Double
    var totalGPSDistanceMeters: Double?
    var averageSpeedMetersPerSecond: Double
    var totalLaps: Int
    @Relationship(deleteRule: .cascade)
    var laps: [Lap]
    var deviceSource: String
    var healthKitWorkoutUUID: UUID?
    var createdAt: Date
    var updatedAt: Date

    // Settings snapshot
    var snapshotTrackingModeRaw: String
    var snapshotDistanceDistanceMeters: Double?
    var snapshotWorkoutPlanJSON: String = ""

    var mode: TrackingMode {
        get { TrackingMode(rawValue: modeRaw) ?? .gps }
        set { modeRaw = newValue.rawValue }
    }

    var snapshotTrackingMode: TrackingMode {
        get { TrackingMode(rawValue: snapshotTrackingModeRaw) ?? .gps }
        set { snapshotTrackingModeRaw = newValue.rawValue }
    }

    var snapshotWorkoutPlan: WorkoutPlanSnapshot {
        get {
            guard !snapshotWorkoutPlanJSON.isEmpty,
                  let data = snapshotWorkoutPlanJSON.data(using: .utf8),
                  let snapshot = try? JSONDecoder().decode(WorkoutPlanSnapshot.self, from: data) else {
                let fallbackDistance = snapshotDistanceDistanceMeters
                    ?? distanceLapDistanceMeters
                    ?? DistanceSegment.default.distanceMeters
                let fallbackSegments: [DistanceSegment]
                if snapshotTrackingMode.usesManualIntervals {
                    fallbackSegments = [DistanceSegment(distanceMeters: fallbackDistance)]
                } else {
                    fallbackSegments = [.default]
                }

                return WorkoutPlanSnapshot(
                    trackingMode: snapshotTrackingMode,
                    distanceLapDistanceMeters: snapshotDistanceDistanceMeters,
                    distanceSegments: fallbackSegments,
                    restMode: .manual
                )
            }
            return snapshot
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                snapshotWorkoutPlanJSON = ""
                return
            }
            snapshotWorkoutPlanJSON = json
        }
    }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Double,
        mode: TrackingMode,
        sportVariantRaw: String? = nil,
        distanceLapDistanceMeters: Double? = nil,
        totalDistanceMeters: Double,
        totalGPSDistanceMeters: Double? = nil,
        averageSpeedMetersPerSecond: Double,
        totalLaps: Int,
        laps: [Lap] = [],
        deviceSource: String = "",
        healthKitWorkoutUUID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        snapshotTrackingMode: TrackingMode,
        snapshotDistanceDistanceMeters: Double? = nil,
        snapshotWorkoutPlan: WorkoutPlanSnapshot? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.modeRaw = mode.rawValue
        self.sportVariantRaw = sportVariantRaw
        self.distanceLapDistanceMeters = distanceLapDistanceMeters
        self.totalDistanceMeters = totalDistanceMeters
        self.totalGPSDistanceMeters = totalGPSDistanceMeters
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.totalLaps = totalLaps
        self.laps = laps
        self.deviceSource = deviceSource
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.snapshotTrackingModeRaw = snapshotTrackingMode.rawValue
        self.snapshotDistanceDistanceMeters = snapshotDistanceDistanceMeters
        self.snapshotWorkoutPlan = snapshotWorkoutPlan ?? WorkoutPlanSnapshot(
            trackingMode: snapshotTrackingMode,
            distanceLapDistanceMeters: snapshotDistanceDistanceMeters,
            distanceSegments: snapshotTrackingMode.usesManualIntervals
                ? [DistanceSegment(distanceMeters: snapshotDistanceDistanceMeters ?? distanceLapDistanceMeters ?? DistanceSegment.default.distanceMeters)]
                : [.default],
            restMode: .manual
        )
    }
}
