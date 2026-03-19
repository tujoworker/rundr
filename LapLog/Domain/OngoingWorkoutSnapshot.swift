import Foundation

struct OngoingWorkoutLapSnapshot: Codable, Equatable, Identifiable {
    var id: UUID
    var index: Int
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var distanceMeters: Double
    var gpsDistanceMeters: Double?
    var averageSpeedMetersPerSecond: Double
    var averageHeartRateBPM: Double?
    var lapType: LapType
    var source: LapSource

    init(lap: Lap) {
        id = lap.id
        index = lap.index
        startedAt = lap.startedAt
        endedAt = lap.endedAt
        durationSeconds = lap.durationSeconds
        distanceMeters = lap.distanceMeters
        gpsDistanceMeters = lap.gpsDistanceMeters
        averageSpeedMetersPerSecond = lap.averageSpeedMetersPerSecond
        averageHeartRateBPM = lap.averageHeartRateBPM
        lapType = lap.lapType
        source = lap.source
    }

    func makeLap() -> Lap {
        Lap(
            id: id,
            index: index,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            gpsDistanceMeters: gpsDistanceMeters,
            averageSpeedMetersPerSecond: averageSpeedMetersPerSecond,
            averageHeartRateBPM: averageHeartRateBPM,
            lapType: lapType,
            source: source
        )
    }
}

struct OngoingWorkoutSnapshot: Codable, Equatable {
    var savedAt: Date
    var sessionStartDate: Date
    var currentLapStartDate: Date
    var elapsedSeconds: Double
    var lapElapsedSeconds: Double
    var trackingMode: TrackingMode
    var distanceLapDistanceMeters: Double
    var distanceSegments: [DistanceSegment]
    var restMode: RestMode
    var completedLaps: [OngoingWorkoutLapSnapshot]
    var cumulativeDistanceMeters: Double
    var currentLapDistanceMeters: Double
    var cumulativeGPSDistanceMeters: Double
    var currentLapGPSDistanceMeters: Double
    var currentHeartRate: Double?
    var currentSegmentIndex: Int
    var currentSegmentRepeatsDone: Int
    var resumeRunState: WorkoutRunState
    var restElapsedSeconds: Int?
    var restDurationSeconds: Int?
    var pauseStartedAt: Date?

    var workoutPlan: WorkoutPlanSnapshot {
        WorkoutPlanSnapshot(
            trackingMode: trackingMode,
            distanceLapDistanceMeters: trackingMode.usesManualIntervals ? distanceLapDistanceMeters : nil,
            distanceSegments: distanceSegments,
            restMode: restMode
        )
    }

    var activeLapCount: Int {
        completedLaps.filter { $0.lapType == .active }.count
    }

    var effectivePauseStartedAt: Date {
        pauseStartedAt ?? savedAt
    }
}