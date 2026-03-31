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

enum WorkoutPlanSupport {
    static func normalizedSegments(_ input: [DistanceSegment]) -> [DistanceSegment] {
        let segments = input.isEmpty ? [.default] : input
        guard segments.count > 1 else { return segments }

        var normalized = segments
        for index in normalized.indices.dropLast() where normalized[index].repeatCount == nil {
            normalized[index].repeatCount = 1
        }
        return normalized
    }

    static func resolvedTrackingMode(
        requestedTrackingMode: TrackingMode,
        segments: [DistanceSegment],
        currentTrackingMode: TrackingMode? = nil
    ) -> TrackingMode {
        if requestedTrackingMode == .distanceDistance,
           segments.contains(where: \.usesOpenDistance) {
            return .dual
        }

        guard let currentTrackingMode,
              currentTrackingMode == .gps,
              requestedTrackingMode.usesManualIntervals else {
            return requestedTrackingMode
        }

        return .dual
    }

    static func makeWorkoutPlan(
        requestedTrackingMode: TrackingMode,
        currentTrackingMode: TrackingMode? = nil,
        fallbackDistance: Double? = nil,
        segments: [DistanceSegment],
        restMode: RestMode
    ) -> WorkoutPlanSnapshot {
        let normalizedSegments = normalizedSegments(segments)
        let trackingMode = resolvedTrackingMode(
            requestedTrackingMode: requestedTrackingMode,
            segments: normalizedSegments,
            currentTrackingMode: currentTrackingMode
        )
        let distance = normalizedSegments.first?.distanceMeters ?? fallbackDistance

        return WorkoutPlanSnapshot(
            trackingMode: trackingMode,
            distanceLapDistanceMeters: distance,
            distanceSegments: normalizedSegments,
            restMode: restMode
        )
    }
}

extension IntervalPreset {
    func displayTitle(unit: DistanceUnit) -> String {
        trimmedCustomTitle ?? workoutPlan.displayTitle(unit: unit)
    }
}

extension WorkoutPlanSnapshot {
    func displayTitle(unit: DistanceUnit) -> String {
        let normalizedSegments = WorkoutPlanSupport.normalizedSegments(distanceSegments)
        guard let firstSegment = normalizedSegments.first else {
            return Formatters.distanceString(meters: DistanceSegment.default.distanceMeters, unit: unit)
        }

        let distance = firstSegment.usesOpenDistance
            ? L10n.openDistance
            : Formatters.distanceString(meters: firstSegment.distanceMeters, unit: unit)

        if normalizedSegments.count == 1, let repeatCount = firstSegment.repeatCount {
            return "\(repeatCount) × \(distance)"
        }

        if normalizedSegments.count == 1 {
            return distance
        }

        return L10n.segmentCount(normalizedSegments.count)
    }

    func displayDetail(unit: DistanceUnit) -> String {
        WorkoutPlanSupport
            .normalizedSegments(distanceSegments)
            .map { segment in
                let distance = segment.usesOpenDistance
                    ? L10n.openDistance
                    : Formatters.distanceString(meters: segment.distanceMeters, unit: unit)

                if let repeatCount = segment.repeatCount {
                    return "\(repeatCount) × \(distance)"
                }

                return distance
            }
            .joined(separator: " • ")
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

    var activeLapCount: Int {
        laps.filter { $0.lapType == .active }.count
    }

    var activeDurationSeconds: Double {
        laps.filter { $0.lapType == .active }.reduce(0) { $0 + $1.durationSeconds }
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
