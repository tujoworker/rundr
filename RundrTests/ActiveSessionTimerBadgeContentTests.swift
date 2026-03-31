import XCTest
@testable import Rundr

final class ActiveSessionTimerBadgeContentTests: XCTestCase {

    func testStatusTextReturnsCombinedLabelForPausedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: true),
            L10n.restModePausedStatus
        )
    }

    func testStatusTextReturnsPausedLabelForPausedState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: false),
            L10n.workoutPaused
        )
    }

    func testStatusTextReturnsRestingLabelForRestStateWithoutDuration() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false),
            L10n.restModeStatus
        )
    }

    func testStatusTextReturnsNilOutsideRestAndPause() {
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .active, willResumeIntoRest: false))
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .ready, willResumeIntoRest: false))
    }
}
