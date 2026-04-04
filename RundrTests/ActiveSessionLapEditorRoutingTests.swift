import XCTest
@testable import Rundr

final class ActiveSessionLapEditorRoutingTests: XCTestCase {

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