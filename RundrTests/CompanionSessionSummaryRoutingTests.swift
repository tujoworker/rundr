import XCTest
@testable import Rundr

final class CompanionSessionSummaryRoutingTests: XCTestCase {

    func testSectionsIncludeActiveRecoverySummaryAndTotalDistance() {
        let activeLap = Lap(
            index: 1,
            startedAt: .now.addingTimeInterval(-180),
            endedAt: .now.addingTimeInterval(-60),
            durationSeconds: 120,
            distanceMeters: 400,
            gpsDistanceMeters: 418,
            averageSpeedMetersPerSecond: 3.33,
            lapType: .active
        )
        let activeRecoveryLap = Lap(
            index: 0,
            startedAt: .now.addingTimeInterval(-60),
            endedAt: .now,
            durationSeconds: 60,
            distanceMeters: 0,
            gpsDistanceMeters: 100,
            averageSpeedMetersPerSecond: 1.67,
            lapType: .activeRecovery
        )
        let session = makeSession(
            mode: .dual,
            totalDistanceMeters: 400,
            totalGPSDistanceMeters: 418,
            laps: [activeLap, activeRecoveryLap]
        )

        let sections = CompanionSessionSummaryRouting.sections(for: session, distanceUnit: .km)

        XCTAssertEqual(sections.map(\.title), [L10n.summary, L10n.activeRecovery])
        XCTAssertTrue(sections[0].items.contains(where: { $0.label == L10n.totalDistanceLabel && $0.value == Formatters.distanceString(meters: 500, unit: .km) }))
        XCTAssertEqual(sections[1].items.map(\.label), [L10n.distance, L10n.averagePaceLabel])
        XCTAssertEqual(sections[1].items[0].value, Formatters.distanceString(meters: 100, unit: .km))
        XCTAssertEqual(
            sections[1].items[1].value,
            Formatters.paceString(distanceMeters: 100, durationSeconds: 60, unit: .km)
        )
    }

    func testSectionsStaySingleWhenSessionHasNoActiveRecovery() {
        let activeLap = Lap(
            index: 1,
            startedAt: .now.addingTimeInterval(-120),
            endedAt: .now,
            durationSeconds: 120,
            distanceMeters: 400,
            gpsDistanceMeters: 400,
            averageSpeedMetersPerSecond: 3.33,
            lapType: .active
        )
        let session = makeSession(
            mode: .dual,
            totalDistanceMeters: 400,
            totalGPSDistanceMeters: 400,
            laps: [activeLap]
        )

        let sections = CompanionSessionSummaryRouting.sections(for: session, distanceUnit: .km)

        XCTAssertEqual(sections.map(\.title), [L10n.summary])
        XCTAssertFalse(sections[0].items.contains(where: { $0.label == L10n.totalDistanceLabel }))
    }

    private func makeSession(
        mode: TrackingMode,
        totalDistanceMeters: Double,
        totalGPSDistanceMeters: Double?,
        laps: [Lap]
    ) -> Session {
        Session(
            startedAt: .now.addingTimeInterval(-600),
            endedAt: .now,
            durationSeconds: 600,
            mode: mode,
            totalDistanceMeters: totalDistanceMeters,
            totalGPSDistanceMeters: totalGPSDistanceMeters,
            averageSpeedMetersPerSecond: 0,
            totalLaps: laps.count,
            laps: laps,
            snapshotTrackingMode: mode,
            snapshotWorkoutPlan: WorkoutPlanSnapshot(
                trackingMode: mode,
                distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 1)]
            )
        )
    }
}