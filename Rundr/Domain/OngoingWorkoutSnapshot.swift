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
    var sessionID: UUID
    var savedAt: Date
    var sessionStartDate: Date
    var currentLapStartDate: Date
    var elapsedSeconds: Double
    var lapElapsedSeconds: Double
    var trackingMode: TrackingMode
    var distanceLapDistanceMeters: Double
    var distanceSegments: [DistanceSegment]
    var restMode: RestMode
    var originPlanID: UUID? = nil
    var completedLaps: [OngoingWorkoutLapSnapshot]
    var cumulativeDistanceMeters: Double
    var currentLapDistanceMeters: Double
    var cumulativeGPSDistanceMeters: Double
    var currentLapGPSDistanceMeters: Double
    var currentHeartRate: Double?
    var currentSegmentIndex: Int
    var currentSegmentRepeatsDone: Int
    var resumeRunState: WorkoutRunState
    var currentRecoveryType: SegmentRecoveryType? = nil
    var restElapsedSeconds: Int?
    var restDurationSeconds: Int?
    var pendingRecoveryType: SegmentRecoveryType? = nil
    var pendingRecoveryDurationSeconds: Int?
    var pauseStartedAt: Date?

    var workoutPlan: WorkoutPlanSnapshot {
        WorkoutPlanSnapshot(
            trackingMode: trackingMode,
            distanceLapDistanceMeters: trackingMode.usesManualIntervals ? distanceLapDistanceMeters : nil,
            distanceSegments: distanceSegments,
            restMode: restMode,
            originPlanID: originPlanID
        )
    }

    var activeLapCount: Int {
        completedLaps.filter { $0.lapType == .active }.count
    }

    var effectivePauseStartedAt: Date {
        pauseStartedAt ?? savedAt
    }

    init(
        sessionID: UUID,
        savedAt: Date,
        sessionStartDate: Date,
        currentLapStartDate: Date,
        elapsedSeconds: Double,
        lapElapsedSeconds: Double,
        trackingMode: TrackingMode,
        distanceLapDistanceMeters: Double,
        distanceSegments: [DistanceSegment],
        restMode: RestMode,
        originPlanID: UUID? = nil,
        completedLaps: [OngoingWorkoutLapSnapshot],
        cumulativeDistanceMeters: Double,
        currentLapDistanceMeters: Double,
        cumulativeGPSDistanceMeters: Double,
        currentLapGPSDistanceMeters: Double,
        currentHeartRate: Double?,
        currentSegmentIndex: Int,
        currentSegmentRepeatsDone: Int,
        resumeRunState: WorkoutRunState,
        currentRecoveryType: SegmentRecoveryType? = nil,
        restElapsedSeconds: Int?,
        restDurationSeconds: Int?,
        pendingRecoveryType: SegmentRecoveryType? = nil,
        pendingRecoveryDurationSeconds: Int? = nil,
        pauseStartedAt: Date?
    ) {
        self.sessionID = sessionID
        self.savedAt = savedAt
        self.sessionStartDate = sessionStartDate
        self.currentLapStartDate = currentLapStartDate
        self.elapsedSeconds = elapsedSeconds
        self.lapElapsedSeconds = lapElapsedSeconds
        self.trackingMode = trackingMode
        self.distanceLapDistanceMeters = distanceLapDistanceMeters
        self.distanceSegments = distanceSegments
        self.restMode = restMode
        self.originPlanID = originPlanID
        self.completedLaps = completedLaps
        self.cumulativeDistanceMeters = cumulativeDistanceMeters
        self.currentLapDistanceMeters = currentLapDistanceMeters
        self.cumulativeGPSDistanceMeters = cumulativeGPSDistanceMeters
        self.currentLapGPSDistanceMeters = currentLapGPSDistanceMeters
        self.currentHeartRate = currentHeartRate
        self.currentSegmentIndex = currentSegmentIndex
        self.currentSegmentRepeatsDone = currentSegmentRepeatsDone
        self.resumeRunState = resumeRunState
        self.currentRecoveryType = currentRecoveryType
        self.restElapsedSeconds = restElapsedSeconds
        self.restDurationSeconds = restDurationSeconds
        self.pendingRecoveryType = pendingRecoveryType
        self.pendingRecoveryDurationSeconds = pendingRecoveryDurationSeconds
        self.pauseStartedAt = pauseStartedAt
    }

    init(
        sessionID: UUID,
        savedAt: Date,
        sessionStartDate: Date,
        currentLapStartDate: Date,
        elapsedSeconds: Double,
        lapElapsedSeconds: Double,
        trackingMode: TrackingMode,
        distanceLapDistanceMeters: Double,
        distanceSegments: [DistanceSegment],
        restMode: RestMode,
        originPlanID: UUID? = nil,
        completedLaps: [OngoingWorkoutLapSnapshot],
        cumulativeDistanceMeters: Double,
        currentLapDistanceMeters: Double,
        cumulativeGPSDistanceMeters: Double,
        currentLapGPSDistanceMeters: Double,
        currentHeartRate: Double?,
        currentSegmentIndex: Int,
        currentSegmentRepeatsDone: Int,
        resumeRunState: WorkoutRunState,
        restElapsedSeconds: Int?,
        restDurationSeconds: Int?,
        pendingRecoveryType: SegmentRecoveryType? = nil,
        pendingRecoveryDurationSeconds: Int? = nil,
        pauseStartedAt: Date?
    ) {
        self.init(
            sessionID: sessionID,
            savedAt: savedAt,
            sessionStartDate: sessionStartDate,
            currentLapStartDate: currentLapStartDate,
            elapsedSeconds: elapsedSeconds,
            lapElapsedSeconds: lapElapsedSeconds,
            trackingMode: trackingMode,
            distanceLapDistanceMeters: distanceLapDistanceMeters,
            distanceSegments: distanceSegments,
            restMode: restMode,
            originPlanID: originPlanID,
            completedLaps: completedLaps,
            cumulativeDistanceMeters: cumulativeDistanceMeters,
            currentLapDistanceMeters: currentLapDistanceMeters,
            cumulativeGPSDistanceMeters: cumulativeGPSDistanceMeters,
            currentLapGPSDistanceMeters: currentLapGPSDistanceMeters,
            currentHeartRate: currentHeartRate,
            currentSegmentIndex: currentSegmentIndex,
            currentSegmentRepeatsDone: currentSegmentRepeatsDone,
            resumeRunState: resumeRunState,
            currentRecoveryType: nil,
            restElapsedSeconds: restElapsedSeconds,
            restDurationSeconds: restDurationSeconds,
            pendingRecoveryType: pendingRecoveryType,
            pendingRecoveryDurationSeconds: pendingRecoveryDurationSeconds,
            pauseStartedAt: pauseStartedAt
        )
    }
}
