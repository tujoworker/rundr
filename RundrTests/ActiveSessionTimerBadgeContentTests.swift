import XCTest
@testable import Rundr

final class ActiveSessionTimerBadgeContentTests: XCTestCase {

    func testStatusTextReturnsCombinedLabelForPausedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: true),
            L10n.restModePausedStatus
        )
    }

    func testStatusTextIncludesDurationForPausedTimedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: true, restDurationSeconds: 75),
            L10n.restModePausedStatusWithDuration("1\(L10n.minutesAbbrev) 15\(L10n.secondsAbbrev)")
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

    func testStatusTextIncludesSecondsForTimedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, restDurationSeconds: 15),
            L10n.restModeStatusWithDuration("15\(L10n.secondsAbbrev)")
        )
    }

    func testStatusTextIncludesMinutesAndSecondsForTimedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, restDurationSeconds: 75),
            L10n.restModeStatusWithDuration("1\(L10n.minutesAbbrev) 15\(L10n.secondsAbbrev)")
        )
    }

    func testStatusTextReturnsNilOutsideRestAndPause() {
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .active, willResumeIntoRest: false))
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .ready, willResumeIntoRest: false))
    }
}
