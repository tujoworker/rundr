import XCTest
@testable import Rundr

final class ActiveSessionTimerBadgeContentTests: XCTestCase {

    func testStatusTextReturnsCombinedLabelForPausedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: true, willResumeIntoJog: false, currentRecoveryType: .rest),
            L10n.restModePausedStatus
        )
    }

    func testStatusTextIncludesDurationForPausedTimedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: true, willResumeIntoJog: false, currentRecoveryType: .rest, restDurationSeconds: 75),
            L10n.restModePausedStatusWithDuration("1\(L10n.minutesAbbrev) 15\(L10n.secondsAbbrev)")
        )
    }

    func testStatusTextReturnsPausedLabelForPausedState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: false, willResumeIntoJog: false, currentRecoveryType: nil),
            L10n.workoutPaused
        )
    }

    func testStatusTextReturnsJogLabelForPausedJogState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: true, willResumeIntoJog: true, currentRecoveryType: .jog),
            L10n.jogModePausedStatus
        )
    }

    func testStatusTextReturnsRestingLabelForRestStateWithoutDuration() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, willResumeIntoJog: false, currentRecoveryType: .rest),
            L10n.restModeStatus
        )
    }

    func testStatusTextReturnsJoggingLabelForJogRecovery() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, willResumeIntoJog: false, currentRecoveryType: .jog),
            L10n.jogModeStatus
        )
    }

    func testStatusTextIncludesSecondsForTimedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, willResumeIntoJog: false, currentRecoveryType: .rest, restDurationSeconds: 15),
            L10n.restModeStatusWithDuration("15\(L10n.secondsAbbrev)")
        )
    }

    func testStatusTextIncludesMinutesAndSecondsForTimedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, willResumeIntoJog: false, currentRecoveryType: .rest, restDurationSeconds: 75),
            L10n.restModeStatusWithDuration("1\(L10n.minutesAbbrev) 15\(L10n.secondsAbbrev)")
        )
    }

    func testStatusTextReturnsNilOutsideRestAndPause() {
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .active, willResumeIntoRest: false, willResumeIntoJog: false, currentRecoveryType: nil))
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .ready, willResumeIntoRest: false, willResumeIntoJog: false, currentRecoveryType: nil))
    }
}
