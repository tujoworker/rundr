import XCTest
@testable import Rundr

final class ActiveSessionTimerBadgeContentTests: XCTestCase {

    func testStatusTextReturnsPausedLabelForPausedState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, restDurationSeconds: 30),
            L10n.workoutPaused
        )
    }

    func testStatusTextReturnsRestCountdownForRestStateWithDuration() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, restDurationSeconds: 45),
            L10n.restDuration(45)
        )
    }

    func testStatusTextReturnsRestingLabelForRestStateWithoutDuration() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, restDurationSeconds: nil),
            L10n.restModeStatus
        )
    }

    func testStatusTextReturnsNilOutsideRestAndPause() {
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .active, restDurationSeconds: 10))
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .ready, restDurationSeconds: nil))
    }
}
