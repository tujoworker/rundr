import XCTest
@testable import Rundr

final class ActiveSessionLapEditorRoutingTests: XCTestCase {

    func testLapEditorLayoutUsesExtraLeadingPaddingForLapTypeRow() {
        XCTAssertGreaterThan(
            ActiveSessionLapEditorLayout.lapTypeLeadingPadding,
            ActiveSessionLapEditorLayout.lapTypeTrailingPadding
        )
    }

    func testSourceSegmentResolvesTimedActiveLap() {
        let segment = DistanceSegment(
            distanceMeters: 0,
            distanceGoalMode: .open,
            targetTimeSeconds: 60
        )
        let lap = Lap(
            index: 1,
            startedAt: .now.addingTimeInterval(-60),
            endedAt: .now,
            durationSeconds: 60,
            distanceMeters: 0,
            gpsDistanceMeters: 280,
            averageSpeedMetersPerSecond: 4.6,
            lapType: .active
        )

        let sourceSegment = ActiveSessionLapEditorRouting.sourceSegment(
            for: lap,
            laps: [lap],
            distanceSegments: [segment],
            trackingMode: .dual
        )

        XCTAssertEqual(sourceSegment, segment)
        XCTAssertFalse(ActiveSessionLapEditorRouting.sourceAllowsDistanceInput(for: sourceSegment))
    }

    func testSourceSegmentResolvesRecoveryLapFromPreviousActiveInterval() {
        let segment = DistanceSegment(
            distanceMeters: 0,
            recoveryType: .activeRecovery,
            restSeconds: 60,
            distanceGoalMode: .open,
            targetTimeSeconds: 120
        )
        let activeLap = Lap(
            index: 1,
            startedAt: .now.addingTimeInterval(-180),
            endedAt: .now.addingTimeInterval(-60),
            durationSeconds: 120,
            distanceMeters: 0,
            gpsDistanceMeters: 540,
            averageSpeedMetersPerSecond: 4.5,
            lapType: .active
        )
        let recoveryLap = Lap(
            index: 0,
            startedAt: .now.addingTimeInterval(-60),
            endedAt: .now,
            durationSeconds: 60,
            distanceMeters: 0,
            gpsDistanceMeters: 160,
            averageSpeedMetersPerSecond: 2.6,
            lapType: .activeRecovery
        )

        let sourceSegment = ActiveSessionLapEditorRouting.sourceSegment(
            for: recoveryLap,
            laps: [activeLap, recoveryLap],
            distanceSegments: [segment],
            trackingMode: .dual
        )

        XCTAssertEqual(sourceSegment, segment)
        XCTAssertFalse(ActiveSessionLapEditorRouting.sourceAllowsDistanceInput(for: sourceSegment))
    }

    func testEditableLapTypePreservesActiveRecovery() {
        let lap = Lap(
            index: 2,
            startedAt: .now.addingTimeInterval(-90),
            endedAt: .now,
            durationSeconds: 90,
            distanceMeters: 0,
            gpsDistanceMeters: 126,
            averageSpeedMetersPerSecond: 1.4,
            lapType: .activeRecovery
        )

        XCTAssertEqual(ActiveSessionLapEditorRouting.editableLapType(for: lap), .activeRecovery)
        XCTAssertTrue(ActiveSessionLapEditorRouting.usesDistanceInput(for: .activeRecovery))
    }

    func testRestLapDoesNotUseDistanceInput() {
        XCTAssertFalse(ActiveSessionLapEditorRouting.usesDistanceInput(for: .rest))
    }

    func testEditableDistancePrefersTrackedGPSDistance() {
        let lap = Lap(
            index: 1,
            startedAt: .now.addingTimeInterval(-100),
            endedAt: .now,
            durationSeconds: 100,
            distanceMeters: 400,
            gpsDistanceMeters: 418,
            averageSpeedMetersPerSecond: 4.18,
            lapType: .active
        )

        XCTAssertEqual(ActiveSessionLapEditorRouting.editableDistanceMeters(for: lap), 418)
    }
}