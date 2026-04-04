import XCTest
@testable import Rundr

final class ActiveSessionTimerBadgeContentTests: XCTestCase {

    func testStatusTextReturnsCombinedLabelForPausedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: true, willResumeIntoActiveRecovery: false, currentRecoveryType: .rest),
            L10n.restModePausedStatus
        )
    }

    func testStatusTextIncludesDurationForPausedTimedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: true, willResumeIntoActiveRecovery: false, currentRecoveryType: .rest, restDurationSeconds: 75),
            L10n.restModePausedStatusWithDuration("1\(L10n.minutesAbbrev) 15\(L10n.secondsAbbrev)")
        )
    }

    func testStatusTextReturnsPausedLabelForPausedState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: false, willResumeIntoActiveRecovery: false, currentRecoveryType: nil),
            L10n.workoutPaused
        )
    }

    func testStatusTextReturnsActiveRecoveryLabelForPausedActiveRecoveryState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .paused, willResumeIntoRest: true, willResumeIntoActiveRecovery: true, currentRecoveryType: .activeRecovery),
            L10n.activeRecoveryModePausedStatus
        )
    }

    func testStatusTextReturnsRestingLabelForRestStateWithoutDuration() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, willResumeIntoActiveRecovery: false, currentRecoveryType: .rest),
            L10n.restModeStatus
        )
    }

    func testStatusTextReturnsActiveRecoverygingLabelForActiveRecoveryRecovery() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, willResumeIntoActiveRecovery: false, currentRecoveryType: .activeRecovery),
            L10n.activeRecoveryModeStatus
        )
    }

    func testStatusTextIncludesSecondsForTimedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, willResumeIntoActiveRecovery: false, currentRecoveryType: .rest, restDurationSeconds: 15),
            L10n.restModeStatusWithDuration("15\(L10n.secondsAbbrev)")
        )
    }

    func testStatusTextIncludesMinutesAndSecondsForTimedRestState() {
        XCTAssertEqual(
            ActiveSessionTimerBadgeContent.statusText(runState: .rest, willResumeIntoRest: false, willResumeIntoActiveRecovery: false, currentRecoveryType: .rest, restDurationSeconds: 75),
            L10n.restModeStatusWithDuration("1\(L10n.minutesAbbrev) 15\(L10n.secondsAbbrev)")
        )
    }

    func testStatusTextReturnsNilOutsideRestAndPause() {
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .active, willResumeIntoRest: false, willResumeIntoActiveRecovery: false, currentRecoveryType: nil))
        XCTAssertNil(ActiveSessionTimerBadgeContent.statusText(runState: .ready, willResumeIntoRest: false, willResumeIntoActiveRecovery: false, currentRecoveryType: nil))
    }
}
