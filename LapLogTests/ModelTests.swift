import XCTest
@testable import LapLog

final class ModelTests: XCTestCase {

    // MARK: - TrackingMode

    func testTrackingModeDisplayNames() {
        XCTAssertEqual(TrackingMode.gps.displayName, "GPS")
        XCTAssertEqual(TrackingMode.dual.displayName, "Dual")
        XCTAssertEqual(TrackingMode.distanceDistance.displayName, "Distance")
    }

    func testTrackingModeAllCases() {
        XCTAssertEqual(TrackingMode.allCases.count, 3)
    }

    func testTrackingModeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for mode in TrackingMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(TrackingMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - LapType

    func testLapTypeDisplayNames() {
        XCTAssertEqual(LapType.active.displayName, "Activity")
        XCTAssertEqual(LapType.rest.displayName, "Rest")
    }

    func testLapTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for lapType in LapType.allCases {
            let data = try encoder.encode(lapType)
            let decoded = try decoder.decode(LapType.self, from: data)
            XCTAssertEqual(decoded, lapType)
        }
    }

    // MARK: - LapSource

    func testLapSourceCases() {
        XCTAssertEqual(LapSource.allCases.count, 4)
        XCTAssertNotNil(LapSource(rawValue: "distanceTap"))
        XCTAssertNotNil(LapSource(rawValue: "actionButton"))
        XCTAssertNotNil(LapSource(rawValue: "autoDistance"))
        XCTAssertNotNil(LapSource(rawValue: "sessionEndSplit"))
    }

    // MARK: - RestMode

    func testRestModeDisplayNames() {
        XCTAssertEqual(RestMode.manual.displayName, L10n.restManual)
        XCTAssertEqual(RestMode.autoDetect.displayName, L10n.restAutoDetect)
    }

    func testRestModeAllCases() {
        XCTAssertEqual(RestMode.allCases.count, 2)
        XCTAssertTrue(RestMode.allCases.contains(.manual))
        XCTAssertTrue(RestMode.allCases.contains(.autoDetect))
    }

    func testRestModeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for mode in RestMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(RestMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - WorkoutRunState

    func testWorkoutRunStateCases() {
        let states: [WorkoutRunState] = [.idle, .ready, .active, .rest, .paused, .ending, .ended]
        XCTAssertEqual(states.count, 7)
        XCTAssertEqual(WorkoutRunState.idle, WorkoutRunState.idle)
        XCTAssertNotEqual(WorkoutRunState.idle, WorkoutRunState.active)
        XCTAssertNotEqual(WorkoutRunState.ending, WorkoutRunState.ended)
    }

    // MARK: - Lap Initialization

    func testLapCreation() {
        let now = Date()
        let later = now.addingTimeInterval(90)
        let lap = Lap(
            index: 1,
            startedAt: now,
            endedAt: later,
            durationSeconds: 90,
            distanceMeters: 400,
            averageSpeedMetersPerSecond: 4.44,
            averageHeartRateBPM: 155,
            lapType: .active,
            source: .distanceTap
        )
        XCTAssertEqual(lap.index, 1)
        XCTAssertEqual(lap.distanceMeters, 400)
        XCTAssertEqual(lap.durationSeconds, 90)
        XCTAssertEqual(lap.lapType, .active)
        XCTAssertEqual(lap.source, .distanceTap)
        XCTAssertEqual(lap.averageHeartRateBPM, 155)
    }

    func testLapCreationNoHeartRate() {
        let now = Date()
        let lap = Lap(
            index: 2,
            startedAt: now,
            endedAt: now.addingTimeInterval(60),
            durationSeconds: 60,
            distanceMeters: 200,
            averageSpeedMetersPerSecond: 3.33
        )
        XCTAssertNil(lap.averageHeartRateBPM)
        XCTAssertEqual(lap.lapType, .active)
        XCTAssertEqual(lap.source, .distanceTap)
    }

    func testLapTypeRawMapping() {
        let lap = Lap(
            index: 1,
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 10,
            distanceMeters: 0,
            averageSpeedMetersPerSecond: 0,
            lapType: .rest,
            source: .sessionEndSplit
        )
        XCTAssertEqual(lap.lapTypeRaw, "rest")
        XCTAssertEqual(lap.sourceRaw, "sessionEndSplit")
        lap.lapType = .active
        XCTAssertEqual(lap.lapTypeRaw, "active")
    }

    // MARK: - Session Initialization

    func testSessionCreation() {
        let start = Date()
        let end = start.addingTimeInterval(1200)
        let session = Session(
            startedAt: start,
            endedAt: end,
            durationSeconds: 1200,
            mode: .gps,
            totalDistanceMeters: 5000,
            averageSpeedMetersPerSecond: 4.17,
            totalLaps: 12,
            snapshotTrackingMode: .gps
        )
        XCTAssertEqual(session.mode, .gps)
        XCTAssertEqual(session.totalDistanceMeters, 5000)
        XCTAssertEqual(session.totalLaps, 12)
        XCTAssertEqual(session.snapshotTrackingMode, .gps)
        XCTAssertNil(session.distanceLapDistanceMeters)
        XCTAssertNil(session.healthKitWorkoutUUID)
    }

    func testSessionDistanceMode() {
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            averageSpeedMetersPerSecond: 3.33,
            totalLaps: 5,
            snapshotTrackingMode: .distanceDistance,
            snapshotDistanceDistanceMeters: 400
        )
        XCTAssertEqual(session.mode, .distanceDistance)
        XCTAssertEqual(session.distanceLapDistanceMeters, 400)
        XCTAssertEqual(session.snapshotDistanceDistanceMeters, 400)
    }

    func testSessionDualModeStoresSeparateGPSDistance() {
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .dual,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            totalGPSDistanceMeters: 2180,
            averageSpeedMetersPerSecond: 3.33,
            totalLaps: 5,
            snapshotTrackingMode: .dual,
            snapshotDistanceDistanceMeters: 400
        )

        XCTAssertEqual(session.mode, .dual)
        XCTAssertEqual(session.distanceLapDistanceMeters, 400)
        XCTAssertEqual(session.totalDistanceMeters, 2000)
        XCTAssertEqual(session.totalGPSDistanceMeters, 2180)
        XCTAssertEqual(session.snapshotTrackingMode, .dual)
    }

    func testSessionStoresWorkoutPlanSnapshot() {
        let snapshot = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [
                DistanceSegment(distanceMeters: 400, repeatCount: 4, restSeconds: 30),
                DistanceSegment(distanceMeters: 800, repeatCount: 2, restSeconds: 60)
            ],
            restMode: .autoDetect
        )
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            averageSpeedMetersPerSecond: 3.33,
            totalLaps: 5,
            snapshotTrackingMode: .distanceDistance,
            snapshotDistanceDistanceMeters: 400,
            snapshotWorkoutPlan: snapshot
        )

        XCTAssertEqual(session.snapshotWorkoutPlan, snapshot)
    }

    func testSessionWorkoutPlanFallbackForLegacySnapshot() {
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            averageSpeedMetersPerSecond: 3.33,
            totalLaps: 5,
            snapshotTrackingMode: .distanceDistance,
            snapshotDistanceDistanceMeters: 400
        )
        session.snapshotWorkoutPlanJSON = ""

        XCTAssertEqual(session.snapshotWorkoutPlan.trackingMode, .distanceDistance)
        XCTAssertEqual(session.snapshotWorkoutPlan.distanceLapDistanceMeters, 400)
        XCTAssertEqual(session.snapshotWorkoutPlan.distanceSegments.count, 1)
        XCTAssertEqual(session.snapshotWorkoutPlan.distanceSegments[0].distanceMeters, 400)
        XCTAssertEqual(session.snapshotWorkoutPlan.restMode, .manual)
    }

    func testSessionModeRawMapping() {
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 0,
            mode: .gps,
            totalDistanceMeters: 0,
            averageSpeedMetersPerSecond: 0,
            totalLaps: 0,
            snapshotTrackingMode: .gps
        )
        XCTAssertEqual(session.modeRaw, "gps")
        session.mode = .distanceDistance
        XCTAssertEqual(session.modeRaw, "distanceDistance")
        session.mode = .dual
        XCTAssertEqual(session.modeRaw, "dual")
    }

    // MARK: - DistanceSegment

    func testDistanceSegmentDefaults() {
        let segment = DistanceSegment()
        XCTAssertEqual(segment.distanceMeters, 400)
        XCTAssertNil(segment.repeatCount)
        XCTAssertNil(segment.restSeconds)
    }

    func testDistanceSegmentWithRepeatCount() {
        let segment = DistanceSegment(distanceMeters: 800, repeatCount: 3)
        XCTAssertEqual(segment.distanceMeters, 800)
        XCTAssertEqual(segment.repeatCount, 3)
    }

    func testDistanceSegmentUnlimited() {
        let segment = DistanceSegment(distanceMeters: 400, repeatCount: nil)
        XCTAssertNil(segment.repeatCount)
    }

    func testDistanceSegmentCodable() throws {
        let segments: [DistanceSegment] = [
            DistanceSegment(distanceMeters: 400, repeatCount: 5),
            DistanceSegment(distanceMeters: 800, repeatCount: nil),
            DistanceSegment(distanceMeters: 200, repeatCount: 10)
        ]
        let data = try JSONEncoder().encode(segments)
        let decoded = try JSONDecoder().decode([DistanceSegment].self, from: data)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].distanceMeters, 400)
        XCTAssertEqual(decoded[0].repeatCount, 5)
        XCTAssertEqual(decoded[1].distanceMeters, 800)
        XCTAssertNil(decoded[1].repeatCount)
        XCTAssertEqual(decoded[2].distanceMeters, 200)
        XCTAssertEqual(decoded[2].repeatCount, 10)
    }

    func testDistanceSegmentEquality() {
        let id = UUID()
        let a = DistanceSegment(id: id, distanceMeters: 400, repeatCount: 3)
        let b = DistanceSegment(id: id, distanceMeters: 400, repeatCount: 3)
        XCTAssertEqual(a, b)
    }

    func testDistanceSegmentWithRestSeconds() {
        let segment = DistanceSegment(distanceMeters: 400, repeatCount: 5, restSeconds: 30)
        XCTAssertEqual(segment.restSeconds, 30)
    }

    func testDistanceSegmentManualRest() {
        let segment = DistanceSegment(distanceMeters: 400, repeatCount: 3, restSeconds: nil)
        XCTAssertNil(segment.restSeconds)
    }

    func testDistanceSegmentCodableWithRest() throws {
        let segments: [DistanceSegment] = [
            DistanceSegment(distanceMeters: 400, repeatCount: 5, restSeconds: 30),
            DistanceSegment(distanceMeters: 800, repeatCount: nil, restSeconds: nil),
        ]
        let data = try JSONEncoder().encode(segments)
        let decoded = try JSONDecoder().decode([DistanceSegment].self, from: data)
        XCTAssertEqual(decoded[0].restSeconds, 30)
        XCTAssertNil(decoded[1].restSeconds)
    }

    func testDistanceSegmentDefault() {
        let d = DistanceSegment.default
        XCTAssertEqual(d.distanceMeters, 400)
        XCTAssertNil(d.repeatCount)
    }

    // MARK: - Interval Presets

    func testSettingsStoreStoresUniqueSessionPresetsOnly() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 300,
            distanceSegments: [DistanceSegment(distanceMeters: 300, repeatCount: 10, restSeconds: 30)],
            restMode: .manual
        )

        store.storeSessionIntervalPresetIfUnique(workoutPlan)
        store.storeSessionIntervalPresetIfUnique(workoutPlan)

        XCTAssertEqual(store.intervalPresets.count, 1)
        XCTAssertEqual(store.intervalPresets.first?.workoutPlan, workoutPlan)
    }

    func testSettingsStoreDoesNotStorePredefinedSessionPreset() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let workoutPlan = SettingsStore.predefinedIntervalPresets[0].workoutPlan

        store.storeSessionIntervalPresetIfUnique(workoutPlan)

        XCTAssertTrue(store.intervalPresets.isEmpty)
    }

    func testSettingsStoreAssignsGeneratedTitleWhenSavingPresetWithoutCustomTitle() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
            restMode: .manual
        )

        let preset = store.saveIntervalPreset(workoutPlan)

        XCTAssertEqual(preset?.trimmedCustomTitle, "6 × 400 m")
        XCTAssertEqual(store.intervalPresets.first?.trimmedCustomTitle, "6 × 400 m")
    }

    func testSettingsStoreReturnsPresetsSortedByMostRecentlyEdited() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let firstPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 4, restSeconds: 45)],
            restMode: .manual
        )
        let secondPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 1000,
            distanceSegments: [DistanceSegment(distanceMeters: 1000, repeatCount: 3, restSeconds: 90)],
            restMode: .manual
        )

        let firstPreset = store.saveIntervalPreset(firstPlan, customTitle: "400s")
        let secondPreset = store.saveIntervalPreset(secondPlan, customTitle: "Ks")
        _ = store.saveIntervalPreset(firstPlan, customTitle: "400s updated", existingPresetID: firstPreset?.id)

        XCTAssertEqual(store.intervalPresets.count, 2)
        XCTAssertEqual(store.intervalPresets.first?.id, firstPreset?.id)
        XCTAssertEqual(store.intervalPresets.first?.trimmedCustomTitle, "400s updated")
        XCTAssertEqual(store.intervalPresets.last?.id, secondPreset?.id)
    }

    func testSettingsStoreUpdatesExistingPresetWithoutDuplicating() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let originalPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
            restMode: .manual
        )
        let updatedPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 500,
            distanceSegments: [DistanceSegment(distanceMeters: 500, repeatCount: 5, restSeconds: 75)],
            restMode: .autoDetect
        )

        let preset = store.saveIntervalPreset(originalPlan, customTitle: "Track")
        let updatedPreset = store.saveIntervalPreset(updatedPlan, customTitle: "Tempo", existingPresetID: preset?.id)

        XCTAssertEqual(store.intervalPresets.count, 1)
        XCTAssertEqual(updatedPreset?.workoutPlan.trackingMode, updatedPlan.trackingMode)
        XCTAssertEqual(updatedPreset?.workoutPlan.distanceLapDistanceMeters, updatedPlan.distanceLapDistanceMeters)
        XCTAssertEqual(updatedPreset?.workoutPlan.distanceSegments, updatedPlan.distanceSegments)
        XCTAssertEqual(updatedPreset?.trimmedCustomTitle, "Tempo")
    }
}
