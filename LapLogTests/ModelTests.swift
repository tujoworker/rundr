import XCTest
@testable import LapLog

final class ModelTests: XCTestCase {

    // MARK: - TrackingMode

    func testTrackingModeDisplayNames() {
        XCTAssertEqual(TrackingMode.gps.displayName, "GPS")
        XCTAssertEqual(TrackingMode.distanceDistance.displayName, "Distance")
    }

    func testTrackingModeAllCases() {
        XCTAssertEqual(TrackingMode.allCases.count, 2)
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

    // MARK: - WorkoutRunState

    func testWorkoutRunStateCases() {
        let states: [WorkoutRunState] = [.idle, .ready, .active, .rest, .ending, .ended]
        XCTAssertEqual(states.count, 6)
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
    }

    // MARK: - DistanceSegment

    func testDistanceSegmentDefaults() {
        let segment = DistanceSegment()
        XCTAssertEqual(segment.distanceMeters, 400)
        XCTAssertNil(segment.repeatCount)
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

    func testDistanceSegmentDefault() {
        let d = DistanceSegment.default
        XCTAssertEqual(d.distanceMeters, 400)
        XCTAssertNil(d.repeatCount)
    }
}
