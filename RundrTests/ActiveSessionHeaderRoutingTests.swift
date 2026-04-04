import XCTest
@testable import Rundr

final class ActiveSessionHeaderRoutingTests: XCTestCase {

    func testShowsSessionCompletionIndicatorWhenNoPlannedIntervalsRemain() {
        XCTAssertTrue(
            ActiveSessionHeaderRouting.showsSessionCompletionIndicator(remainingPlannedIntervals: 0)
        )
    }

    func testHidesSessionCompletionIndicatorWhenIntervalsRemain() {
        XCTAssertFalse(
            ActiveSessionHeaderRouting.showsSessionCompletionIndicator(remainingPlannedIntervals: 1)
        )
    }

    func testHidesSessionCompletionIndicatorForOpenEndedPlans() {
        XCTAssertFalse(
            ActiveSessionHeaderRouting.showsSessionCompletionIndicator(remainingPlannedIntervals: nil)
        )
    }
}