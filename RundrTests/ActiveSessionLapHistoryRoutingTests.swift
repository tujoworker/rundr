import XCTest
@testable import Rundr

final class ActiveSessionLapHistoryRoutingTests: XCTestCase {

    func testLatestLapIDReturnsNilForEmptyLapHistory() {
        XCTAssertNil(ActiveSessionLapHistoryRouting.latestLapID(in: []))
    }

    func testLatestLapIDReturnsRightmostLap() {
        let firstLap = Lap(
            index: 1,
            startedAt: .now.addingTimeInterval(-120),
            endedAt: .now.addingTimeInterval(-60),
            durationSeconds: 60,
            distanceMeters: 400,
            averageSpeedMetersPerSecond: 6.6,
            lapType: .active
        )
        let latestLap = Lap(
            index: 2,
            startedAt: .now.addingTimeInterval(-60),
            endedAt: .now,
            durationSeconds: 60,
            distanceMeters: 400,
            averageSpeedMetersPerSecond: 6.6,
            lapType: .active
        )

        XCTAssertEqual(
            ActiveSessionLapHistoryRouting.latestLapID(in: [firstLap, latestLap]),
            latestLap.id
        )
    }
}
