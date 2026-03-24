import XCTest
@testable import LapLog

@MainActor
final class WorkoutControllerTests: XCTestCase {

    private func makeController() -> WorkoutSessionController {
        let controller = WorkoutSessionController()
        return controller
    }

    private func makeConfiguredController(
        trackingMode: TrackingMode = .distanceDistance,
        distance: Double = 400,
        segments: [DistanceSegment] = [.default]
    ) -> WorkoutSessionController {
        let controller = makeController()
        controller.configure(
            trackingMode: trackingMode,
            distanceLapDistanceMeters: distance,
            distanceSegments: segments,
            healthKitManager: HealthKitManager()
        )
        return controller
    }

    private func makeStartedController(
        trackingMode: TrackingMode = .distanceDistance,
        distance: Double = 400,
        segments: [DistanceSegment] = [.default]
    ) -> WorkoutSessionController {
        let controller = makeConfiguredController(trackingMode: trackingMode, distance: distance, segments: segments)
        controller.minimumLapDuration = 0
        controller.startWithoutHealthKit()
        return controller
    }

    // MARK: - Initial State

    func testInitialState() {
        let controller = makeController()
        XCTAssertEqual(controller.runState, .idle)
        XCTAssertEqual(controller.elapsedSeconds, 0)
        XCTAssertNil(controller.currentHeartRate)
        XCTAssertEqual(controller.cumulativeDistanceMeters, 0)
        XCTAssertTrue(controller.completedLaps.isEmpty)
    }

    // MARK: - Get Ready

    func testGetReady() {
        let controller = makeController()
        controller.getReady()
        XCTAssertEqual(controller.runState, .ready)
    }

    // MARK: - Heart Rate Updates

    func testHeartRateUpdate() {
        let controller = makeController()
        controller.handleHeartRateUpdate(bpm: 145)
        XCTAssertEqual(controller.currentHeartRate, 145)
        controller.handleHeartRateUpdate(bpm: 160)
        XCTAssertEqual(controller.currentHeartRate, 160)
    }

    // MARK: - Distance Updates

    func testDistanceUpdate() {
        let controller = makeController()
        controller.handleDistanceUpdate(additionalMeters: 100)
        XCTAssertEqual(controller.cumulativeDistanceMeters, 100)
        controller.handleDistanceUpdate(additionalMeters: 50)
        XCTAssertEqual(controller.cumulativeDistanceMeters, 150)
    }

    // MARK: - Commit Final Lap

    func testCommitFinalLapFromRestStopsTimer() {
        let controller = makeStartedController()
        XCTAssertEqual(controller.runState, .active)

        controller.markLap()
        controller.startRest()
        XCTAssertEqual(controller.runState, .rest)

        let lapCountBefore = controller.completedLaps.count
        controller.commitFinalLap()
        XCTAssertEqual(controller.runState, .ending)
        XCTAssertEqual(controller.completedLaps.count, lapCountBefore + 1)
    }

    func testCommitFinalLapIgnoredWhenIdle() {
        let controller = makeController()
        controller.commitFinalLap()
        XCTAssertEqual(controller.runState, .idle)
        XCTAssertTrue(controller.completedLaps.isEmpty)
    }

    // MARK: - Distance Segments

    func testDefaultSegment() {
        let controller = makeConfiguredController()
        XCTAssertEqual(controller.currentTargetDistanceMeters, 400)
        XCTAssertEqual(controller.availableDistances, [400])
    }

    func testMultipleSegments() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 2),
            DistanceSegment(distanceMeters: 800, repeatCount: 1)
        ]
        let controller = makeConfiguredController(segments: segments)
        XCTAssertEqual(controller.currentTargetDistanceMeters, 400)
        XCTAssertEqual(controller.availableDistances, [400, 800])
    }

    func testTotalPlannedIntervalsForFinitePlan() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 2),
            DistanceSegment(distanceMeters: 800, repeatCount: 3)
        ]
        let controller = makeConfiguredController(segments: segments)

        XCTAssertEqual(controller.totalPlannedIntervals, 5)
        XCTAssertEqual(controller.remainingPlannedIntervals, 5)
    }

    func testRemainingPlannedIntervalsIsNilForOpenEndedPlan() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 2),
            DistanceSegment(distanceMeters: 800, repeatCount: nil)
        ]
        let controller = makeConfiguredController(segments: segments)

        XCTAssertNil(controller.totalPlannedIntervals)
        XCTAssertNil(controller.remainingPlannedIntervals)
    }

    func testRemainingPlannedIntervalsDecrementsWithActiveLaps() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 2),
            DistanceSegment(distanceMeters: 800, repeatCount: 1)
        ]
        let controller = makeStartedController(segments: segments)

        XCTAssertEqual(controller.remainingPlannedIntervals, 3)

        controller.markLap()
        XCTAssertEqual(controller.remainingPlannedIntervals, 2)

        controller.markLap()
        XCTAssertEqual(controller.remainingPlannedIntervals, 1)
    }

    func testSegmentAdvancesAfterRepeats() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 2),
            DistanceSegment(distanceMeters: 800, repeatCount: nil)
        ]
        let controller = makeStartedController(segments: segments)

        // First two laps should be 400m (segment 0)
        XCTAssertEqual(controller.currentTargetDistanceMeters, 400)
        controller.markLap()
        XCTAssertEqual(controller.completedLaps.count, 1)
        XCTAssertEqual(controller.completedLaps[0].distanceMeters, 400)

        controller.markLap()
        // After second lap, should advance to segment 1 (800m)
        XCTAssertEqual(controller.completedLaps.count, 2)
        XCTAssertEqual(controller.currentTargetDistanceMeters, 800)

        controller.markLap()
        // Third lap should be 800m (unlimited)
        XCTAssertEqual(controller.completedLaps.count, 3)
        XCTAssertEqual(controller.completedLaps[2].distanceMeters, 800)
        XCTAssertEqual(controller.currentTargetDistanceMeters, 800)
    }

    func testUnlimitedSegmentStays() {
        let controller = makeStartedController()

        controller.markLap()
        controller.markLap()
        controller.markLap()

        XCTAssertEqual(controller.completedLaps.count, 3)
        XCTAssertEqual(controller.currentTargetDistanceMeters, 400)
        for lap in controller.completedLaps {
            XCTAssertEqual(lap.distanceMeters, 400)
        }
    }

    func testChangeLapDistance() {
        let controller = makeStartedController()
        controller.markLap()

        let lapID = controller.completedLaps[0].id
        XCTAssertEqual(controller.completedLaps[0].distanceMeters, 400)

        controller.changeLapDistance(id: lapID, newDistanceMeters: 200)
        XCTAssertEqual(controller.completedLaps[0].distanceMeters, 200)
        XCTAssertTrue(controller.completedLaps[0].averageSpeedMetersPerSecond > 0)
    }

    func testChangeLapDistanceUpdatesCumulativeDistance() {
        let controller = makeStartedController(trackingMode: .gps)
        controller.handleDistanceUpdate(additionalMeters: 500)
        controller.markLap()
        controller.handleDistanceUpdate(additionalMeters: 500)
        controller.markLap()

        let cumBefore = controller.cumulativeDistanceMeters
        let lapID = controller.completedLaps[0].id
        let oldDist = controller.completedLaps[0].distanceMeters
        controller.changeLapDistance(id: lapID, newDistanceMeters: 200)

        XCTAssertEqual(controller.cumulativeDistanceMeters, cumBefore - oldDist + 200)
    }

    func testRestLapDoesNotAdvanceSegment() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 2),
            DistanceSegment(distanceMeters: 800, repeatCount: nil)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        controller.startRest()
        controller.markLap()

        // Rest lap shouldn't count toward segment advancement
        XCTAssertEqual(controller.currentTargetDistanceMeters, 400)

        controller.markLap()
        // Now 2 active laps done, should advance to segment 1
        XCTAssertEqual(controller.currentTargetDistanceMeters, 800)
    }

    func testLastRestOverridesRestBetweenBlocks() {
        let controller = makeStartedController(
            segments: [
                DistanceSegment(distanceMeters: 400, repeatCount: 2, restSeconds: 30, lastRestSeconds: 90),
                DistanceSegment(distanceMeters: 800, repeatCount: 1, restSeconds: 45)
            ]
        )

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)
        XCTAssertEqual(controller.restDurationSeconds, 30)

        controller.markLap()
        XCTAssertEqual(controller.runState, .active)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)
        XCTAssertEqual(controller.restDurationSeconds, 90)
        XCTAssertEqual(controller.currentTargetDistanceMeters, 800)
    }

    func testFinalBlockFallsBackToRegularRestWhenLastRestMissing() {
        let controller = makeStartedController(
            segments: [
                DistanceSegment(distanceMeters: 400, repeatCount: 2, restSeconds: 30),
                DistanceSegment(distanceMeters: 800, repeatCount: 1, restSeconds: 45)
            ]
        )

        controller.markLap()
        XCTAssertEqual(controller.restDurationSeconds, 30)

        controller.markLap()
        controller.markLap()

        XCTAssertEqual(controller.runState, .rest)
        XCTAssertEqual(controller.restDurationSeconds, 30)
        XCTAssertEqual(controller.currentTargetDistanceMeters, 800)
    }

    func testEmptySegmentsDefaultsToDefault() {
        let controller = makeConfiguredController(segments: [])
        XCTAssertEqual(controller.currentTargetDistanceMeters, 400)
    }

    func testGPSModeTargetDistanceIsNil() {
        let controller = makeConfiguredController(trackingMode: .gps)
        XCTAssertNil(controller.currentTargetDistanceMeters)
    }

    func testDualModeTargetDistanceMatchesCurrentSegment() {
        let controller = makeConfiguredController(trackingMode: .dual)
        XCTAssertEqual(controller.currentTargetDistanceMeters, 400)
    }

    func testDualModeStoresGPSDistanceSeparately() {
        let controller = makeStartedController(trackingMode: .dual)

        controller.handleGPSDistanceUpdate(additionalMeters: 418)
        controller.markLap()

        XCTAssertEqual(controller.completedLaps.count, 1)
        XCTAssertEqual(controller.completedLaps[0].distanceMeters, 400)
        XCTAssertEqual(controller.completedLaps[0].gpsDistanceMeters, 418)
        XCTAssertEqual(controller.cumulativeGPSDistanceMeters, 418)
    }

    func testDualModeKeepsManualAndGPSDistanceTotalsSeparate() {
        let controller = makeStartedController(trackingMode: .dual)

        controller.handleDistanceUpdate(additionalMeters: 125)
        controller.handleGPSDistanceUpdate(additionalMeters: 418)

        XCTAssertEqual(controller.cumulativeDistanceMeters, 125)
        XCTAssertEqual(controller.currentLapDistanceMeters, 125)
        XCTAssertEqual(controller.cumulativeGPSDistanceMeters, 418)
        XCTAssertEqual(controller.currentLapGPSDistanceMeters, 418)
    }

    func testOpenIntervalUsesMeasuredGPSDistanceAndNoDistanceTarget() {
        let controller = makeStartedController(
            trackingMode: .distanceDistance,
            segments: [
                DistanceSegment(
                    distanceMeters: 400,
                    repeatCount: nil,
                    restSeconds: 15,
                    distanceGoalMode: .open,
                    targetTimeSeconds: 45
                )
            ]
        )

        XCTAssertEqual(controller.trackingMode, TrackingMode.dual)
        XCTAssertNil(controller.currentTargetDistanceMeters)
        XCTAssertEqual(controller.currentTargetTimeSeconds, 45)

        controller.handleGPSDistanceUpdate(additionalMeters: 212)
        controller.markLap()

        XCTAssertEqual(controller.completedLaps.count, 1)
        XCTAssertEqual(controller.completedLaps[0].distanceMeters, 212)
        XCTAssertEqual(controller.completedLaps[0].gpsDistanceMeters, 212)
        XCTAssertEqual(controller.runState, WorkoutRunState.rest)
        XCTAssertEqual(controller.restDurationSeconds, 15)
    }

    func testOpenIntervalAutoCompletesOnTargetTime() async {
        let controller = makeStartedController(
            trackingMode: .distanceDistance,
            segments: [
                DistanceSegment(
                    distanceMeters: 400,
                    repeatCount: nil,
                    restSeconds: nil,
                    distanceGoalMode: .open,
                    targetTimeSeconds: 1.05
                )
            ]
        )

        controller.handleGPSDistanceUpdate(additionalMeters: 180)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(controller.completedLaps.count, 1)
        XCTAssertEqual(controller.completedLaps[0].source, LapSource.autoTime)
        XCTAssertEqual(controller.completedLaps[0].distanceMeters, 180, accuracy: 0.001)
        XCTAssertEqual(controller.runState, WorkoutRunState.active)
    }

    func testManualLiveStateUsesCompletedLapDistance() {
        let controller = makeStartedController(trackingMode: .distanceDistance)
        let syncManager = WatchConnectivitySyncManager()
        controller.attachOngoingWorkoutStore(OngoingWorkoutStore())
        controller.attachSyncManager(syncManager)

        controller.handleDistanceUpdate(additionalMeters: 125)
        XCTAssertEqual(syncManager.liveWorkoutState?.cumulativeDistanceMeters, 0)

        controller.markLap()
        XCTAssertEqual(syncManager.liveWorkoutState?.cumulativeDistanceMeters, 400)

        controller.handleDistanceUpdate(additionalMeters: 80)
        XCTAssertEqual(syncManager.liveWorkoutState?.cumulativeDistanceMeters, 400)
    }

    func testDualLiveStateShowsLapBasedManualAndContinuousGPSDistance() {
        let controller = makeStartedController(trackingMode: .dual)
        let syncManager = WatchConnectivitySyncManager()
        controller.attachOngoingWorkoutStore(OngoingWorkoutStore())
        controller.attachSyncManager(syncManager)

        controller.handleDistanceUpdate(additionalMeters: 150)
        controller.handleGPSDistanceUpdate(additionalMeters: 173)

        XCTAssertEqual(syncManager.liveWorkoutState?.cumulativeDistanceMeters, 0)
        XCTAssertEqual(syncManager.liveWorkoutState?.cumulativeGPSDistanceMeters, 173)

        controller.markLap()
        XCTAssertEqual(syncManager.liveWorkoutState?.cumulativeDistanceMeters, 400)
        XCTAssertEqual(syncManager.liveWorkoutState?.cumulativeGPSDistanceMeters, 173)
    }

    func testGPSModeUsesGPSDistanceForLapDistance() {
        let controller = makeStartedController(trackingMode: .gps)

        controller.handleGPSDistanceUpdate(additionalMeters: 512)
        controller.markLap()

        XCTAssertEqual(controller.completedLaps.count, 1)
        XCTAssertEqual(controller.completedLaps[0].distanceMeters, 512)
        XCTAssertEqual(controller.completedLaps[0].gpsDistanceMeters, 512)
    }

    // MARK: - Rest Mode

    func testRestModeDefaultsToManual() {
        let controller = makeConfiguredController()
        XCTAssertEqual(controller.restMode, .manual)
    }

    func testRestModeCanBeConfigured() {
        let controller = makeController()
        controller.configure(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [.default],
            restMode: .autoDetect,
            healthKitManager: HealthKitManager()
        )
        XCTAssertEqual(controller.restMode, .autoDetect)
    }

    func testHealthKitLiveWorkoutSessionsAreDisabledDuringTests() {
        let manager = HealthKitManager()

        XCTAssertTrue(HealthKitManager.isRunningTests)
        XCTAssertFalse(manager.supportsLiveWorkoutSessions)
    }

    func testAutoDetectRestEntersRestAfterDelay() async {
        let controller = makeController()
        controller.configure(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [.default],
            restMode: .autoDetect,
            healthKitManager: HealthKitManager()
        )
        controller.autoRestDetectionDelay = .milliseconds(20)
        controller.startWithoutHealthKit()

        controller.handleAutoRestMotionPause()
        XCTAssertEqual(controller.runState, .active)

        try? await Task.sleep(for: .milliseconds(40))

        XCTAssertEqual(controller.runState, .rest)
    }

    func testAutoDetectRestResumeCancelsPendingTransition() async {
        let controller = makeController()
        controller.configure(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [.default],
            restMode: .autoDetect,
            healthKitManager: HealthKitManager()
        )
        controller.autoRestDetectionDelay = .milliseconds(40)
        controller.startWithoutHealthKit()

        controller.handleAutoRestMotionPause()
        controller.handleAutoRestMotionResume()

        try? await Task.sleep(for: .milliseconds(70))

        XCTAssertEqual(controller.runState, .active)
    }

    func testAutoDetectRestResumeExitsRestImmediately() {
        let controller = makeController()
        controller.configure(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [.default],
            restMode: .autoDetect,
            healthKitManager: HealthKitManager()
        )
        controller.startWithoutHealthKit()
        controller.startRest()

        controller.handleAutoRestMotionResume()

        XCTAssertEqual(controller.runState, .active)
    }

    func testRecoverySnapshotRestoresPausedWorkout() {
        let store = OngoingWorkoutStore()
        store.clear()

        let controller = makeStartedController(trackingMode: .dual)
        controller.attachOngoingWorkoutStore(store)
        controller.handleGPSDistanceUpdate(additionalMeters: 412)
        controller.markLap()
        controller.handleGPSDistanceUpdate(additionalMeters: 188)
        controller.persistRecoverySnapshotIfNeeded()

        guard let snapshot = store.snapshot else {
            return XCTFail("Expected recovery snapshot")
        }

        let restored = WorkoutSessionController()
        restored.attachOngoingWorkoutStore(store)
        restored.restore(snapshot: snapshot, healthKitManager: HealthKitManager())

        XCTAssertEqual(restored.runState, .paused)
        XCTAssertEqual(restored.completedLaps.count, 1)
        XCTAssertEqual(restored.completedLaps[0].distanceMeters, 400)
        XCTAssertEqual(restored.completedLaps[0].gpsDistanceMeters, 412)
        XCTAssertEqual(restored.currentLapGPSDistanceMeters, 188)

        restored.resumeSession()

        XCTAssertEqual(restored.runState, .active)
    }

    func testRecoverySnapshotPreservesRestState() {
        let store = OngoingWorkoutStore()
        store.clear()

        let controller = makeStartedController(
            trackingMode: .distanceDistance,
            segments: [DistanceSegment(distanceMeters: 400, repeatCount: 1, restSeconds: 30)]
        )
        controller.attachOngoingWorkoutStore(store)
        controller.markLap()
        controller.persistRecoverySnapshotIfNeeded()

        guard let snapshot = store.snapshot else {
            return XCTFail("Expected recovery snapshot")
        }

        let restored = WorkoutSessionController()
        restored.restore(snapshot: snapshot, healthKitManager: HealthKitManager())

        XCTAssertEqual(restored.runState, .paused)
        restored.resumeSession()
        XCTAssertEqual(restored.runState, .rest)
        XCTAssertEqual(restored.restDurationSeconds, 30)
    }

    func testStartingWithRecoveryStorePersistsSnapshotAndEndingClearsIt() async {
        let store = OngoingWorkoutStore()
        store.clear()

        let controller = makeConfiguredController(trackingMode: .dual)
        controller.attachOngoingWorkoutStore(store)
        controller.minimumLapDuration = 0
        controller.startWithoutHealthKit()

        XCTAssertNotNil(store.snapshot)
        XCTAssertEqual(store.snapshot?.resumeRunState, .active)

        _ = await controller.endSession()

        XCTAssertEqual(controller.runState, .ended)
        XCTAssertNil(store.snapshot)
        XCTAssertNil(store.startupSnapshot)
    }

    func testPauseSessionPersistsPausedRecoverySnapshot() {
        let store = OngoingWorkoutStore()
        store.clear()

        let controller = makeStartedController(trackingMode: .dual)
        controller.attachOngoingWorkoutStore(store)
        controller.handleGPSDistanceUpdate(additionalMeters: 123)

        controller.pauseSession()

        XCTAssertEqual(controller.runState, .paused)
        XCTAssertEqual(store.snapshot?.resumeRunState, .active)
        XCTAssertNotNil(store.snapshot?.pauseStartedAt)
        XCTAssertEqual(store.snapshot?.currentLapGPSDistanceMeters, 123)
    }

    func testThreeSegmentProgression() {
        let segments = [
            DistanceSegment(distanceMeters: 200, repeatCount: 1),
            DistanceSegment(distanceMeters: 400, repeatCount: 2),
            DistanceSegment(distanceMeters: 800, repeatCount: nil)
        ]
        let controller = makeStartedController(segments: segments)

        // Segment 0: 200m × 1
        XCTAssertEqual(controller.currentTargetDistanceMeters, 200)
        controller.markLap()
        XCTAssertEqual(controller.completedLaps.last?.distanceMeters, 200)

        // Segment 1: 400m × 2
        XCTAssertEqual(controller.currentTargetDistanceMeters, 400)
        controller.markLap()
        controller.markLap()
        XCTAssertEqual(controller.completedLaps.last?.distanceMeters, 400)

        // Segment 2: 800m × ∞
        XCTAssertEqual(controller.currentTargetDistanceMeters, 800)
        controller.markLap()
        controller.markLap()
        XCTAssertEqual(controller.currentTargetDistanceMeters, 800)
    }

    func testDeleteLapDoesNotAffectSegmentIndex() {
        let controller = makeStartedController()
        controller.markLap()
        controller.markLap()

        let lapID = controller.completedLaps[0].id
        controller.deleteLap(id: lapID)
        XCTAssertEqual(controller.completedLaps.count, 1)
        // Segment index should be unchanged
        XCTAssertEqual(controller.currentTargetDistanceMeters, 400)
    }

    // MARK: - Auto-Rest

    func testAutoRestTriggersAfterEachLap() {
        // Single segment with restSeconds → rest after every lap
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: 30)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)
        XCTAssertEqual(controller.restElapsedSeconds, 0)
        XCTAssertEqual(controller.restDurationSeconds, 30)
    }

    func testAutoRestTriggersOnSegmentAdvanceToo() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 1, restSeconds: 30),
            DistanceSegment(distanceMeters: 800, repeatCount: nil)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)
        XCTAssertEqual(controller.restDurationSeconds, 30)
    }

    func testManualRestHasNoCountdown() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 1, restSeconds: nil),
            DistanceSegment(distanceMeters: 800, repeatCount: nil)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .active)
        XCTAssertNil(controller.restElapsedSeconds)
    }

    func testCompletingFinitePlanEntersRestMode() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 1)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()

        XCTAssertEqual(controller.remainingPlannedIntervals, 0)
        XCTAssertEqual(controller.runState, .rest)
        XCTAssertNil(controller.restDurationSeconds)
    }

    func testCanContinueAddingLapsAfterFinitePlanEntersRestMode() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 1)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)

        controller.markLap()

        XCTAssertEqual(controller.runState, .active)
        XCTAssertEqual(controller.completedLaps.count, 2)
        XCTAssertEqual(controller.completedLaps.last?.lapType, .rest)
    }

    func testCancelRestClearsTimer() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: 60)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)
        XCTAssertNotNil(controller.restDurationSeconds)

        controller.cancelRest()
        XCTAssertEqual(controller.runState, .active)
        XCTAssertNil(controller.restElapsedSeconds)
        XCTAssertNil(controller.restDurationSeconds)
        XCTAssertFalse(controller.isRestWarningActive)
    }

    func testPauseSessionFreezesElapsedTimeAtEnd() async {
        let controller = makeStartedController(trackingMode: .gps)

        controller.pauseSession()
        XCTAssertEqual(controller.runState, .paused)

        try? await Task.sleep(for: .milliseconds(200))

        let session = await controller.endSession()

        XCTAssertNotNil(session)
        XCTAssertEqual(controller.runState, .ended)
        XCTAssertLessThan(session?.durationSeconds ?? 99, 1.1)
    }

    func testPausedSessionIgnoresDistanceUpdates() {
        let controller = makeStartedController(trackingMode: .gps)

        controller.pauseSession()
        controller.handleDistanceUpdate(additionalMeters: 125)

        XCTAssertEqual(controller.cumulativeDistanceMeters, 0)
        XCTAssertEqual(controller.currentLapDistanceMeters, 0)
    }

    func testResumeSessionFromRestRestoresTimedRest() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: 60)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)

        controller.pauseSession()
        XCTAssertEqual(controller.runState, .paused)

        controller.resumeSession()

        XCTAssertEqual(controller.runState, .rest)
        XCTAssertEqual(controller.restDurationSeconds, 60)
        XCTAssertNotNil(controller.restElapsedSeconds)
    }

    func testPrepareForSessionEndClearsRestWarningImmediately() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: 60)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)
        controller.isRestWarningActive = true
        XCTAssertNotNil(controller.restDurationSeconds)

        controller.prepareForSessionEnd()

        XCTAssertNil(controller.restElapsedSeconds)
        XCTAssertNil(controller.restDurationSeconds)
        XCTAssertFalse(controller.isRestWarningActive)
    }

    func testEndSessionFromRestClearsRestTimerState() async {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: 60)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)
        XCTAssertNotNil(controller.restElapsedSeconds)
        XCTAssertNotNil(controller.restDurationSeconds)

        let session = await controller.endSession()

        XCTAssertNotNil(session)
        XCTAssertEqual(controller.runState, .ended)
        XCTAssertNil(controller.restElapsedSeconds)
        XCTAssertNil(controller.restDurationSeconds)
        XCTAssertFalse(controller.isRestWarningActive)
    }

    func testAutoRestCreatesRestLapOnResume() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: 30)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)

        // User taps to resume → commits rest lap, goes active
        controller.markLap()
        XCTAssertEqual(controller.runState, .active)
        let restLaps = controller.completedLaps.filter { $0.lapType == .rest }
        XCTAssertGreaterThanOrEqual(restLaps.count, 1)

        // Next active markLap → auto-enters rest again
        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)
    }

    func testAutoRestDoesNotAutoResume() {
        // Verify that timed rest stays in rest — user must manually start next lap
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: 30)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .rest)
        XCTAssertEqual(controller.restDurationSeconds, 30)
        // State stays .rest — no auto-resume
        XCTAssertEqual(controller.runState, .rest)
    }

    func testNoAutoRestWithoutRestSeconds() {
        // No restSeconds configured → no auto-rest
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: nil)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertEqual(controller.runState, .active)
        XCTAssertNil(controller.restElapsedSeconds)
    }

    func testAutoRestAdvancesToCorrectSegment() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 1, restSeconds: 15),
            DistanceSegment(distanceMeters: 800, repeatCount: nil)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        // Now in rest → segment already advanced to 800m
        XCTAssertEqual(controller.currentTargetDistanceMeters, 800)
    }

    func testRestWarningInitiallyFalse() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: 30)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        XCTAssertFalse(controller.isRestWarningActive)
    }

    func testUpdateLapToRestRecalculatesDerivedState() {
        let segments = [
            DistanceSegment(distanceMeters: 400, repeatCount: 1),
            DistanceSegment(distanceMeters: 800, repeatCount: 1)
        ]
        let controller = makeStartedController(segments: segments)

        controller.markLap()
        controller.markLap()

        let secondLapID = controller.completedLaps[1].id
        controller.updateLap(id: secondLapID, newType: .rest, newDistanceMeters: 800)

        XCTAssertEqual(controller.completedLaps[1].lapType, .rest)
        XCTAssertEqual(controller.completedLaps[1].distanceMeters, 0)
        XCTAssertEqual(controller.completedLaps[1].index, 0)
        XCTAssertEqual(controller.cumulativeDistanceMeters, 400)
        XCTAssertEqual(controller.remainingPlannedIntervals, 1)
        XCTAssertEqual(controller.currentTargetDistanceMeters, 800)
    }

    func testUpdateRestLapToActiveRecalculatesDerivedState() {
        let controller = makeStartedController(trackingMode: .gps)

        controller.startRest()
        controller.markLap()

        let restLapID = controller.completedLaps[0].id
        controller.updateLap(id: restLapID, newType: .active, newDistanceMeters: 250)

        XCTAssertEqual(controller.completedLaps[0].lapType, .active)
        XCTAssertEqual(controller.completedLaps[0].distanceMeters, 250)
        XCTAssertEqual(controller.completedLaps[0].index, 1)
        XCTAssertEqual(controller.cumulativeDistanceMeters, 250)
        XCTAssertGreaterThan(controller.completedLaps[0].averageSpeedMetersPerSecond, 0)
    }
}
