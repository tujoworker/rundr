import XCTest
@testable import Rundr

final class ActiveSessionTimerAnimationRoutingTests: XCTestCase {

    func testNextPendingLapCountAdvancesByOne() {
        XCTAssertEqual(
            ActiveSessionTimerAnimationRouting.nextPendingLapCount(currentLapCount: 3),
            4
        )
    }

    func testCountChangeDoesNotAnimateAgainForPendingImmediateLap() {
        XCTAssertFalse(
            ActiveSessionTimerAnimationRouting.shouldAnimateOnLapCountChange(
                lapCount: 4,
                lastAnimatedLapCount: 3,
                pendingLapAnimationCount: 4
            )
        )
    }

    func testCountChangeStillAnimatesWhenNoPendingImmediateLapExists() {
        XCTAssertTrue(
            ActiveSessionTimerAnimationRouting.shouldAnimateOnLapCountChange(
                lapCount: 4,
                lastAnimatedLapCount: 3,
                pendingLapAnimationCount: nil
            )
        )
    }

    func testResolvedPendingLapCountClearsWhenExpectedLapArrives() {
        XCTAssertNil(
            ActiveSessionTimerAnimationRouting.resolvedPendingLapAnimationCount(
                lapCount: 4,
                pendingLapAnimationCount: 4
            )
        )
    }
}
