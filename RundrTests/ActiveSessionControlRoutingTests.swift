import XCTest
@testable import Rundr

final class ActiveSessionControlRoutingTests: XCTestCase {

    func testRestButtonActionStartsRestFromIdleReadyActiveAndEndingStates() {
        XCTAssertEqual(ActiveSessionControlRouting.restButtonAction(for: .idle), .startRest)
        XCTAssertEqual(ActiveSessionControlRouting.restButtonAction(for: .ready), .startRest)
        XCTAssertEqual(ActiveSessionControlRouting.restButtonAction(for: .active), .startRest)
        XCTAssertEqual(ActiveSessionControlRouting.restButtonAction(for: .ending), .startRest)
    }

    func testRestButtonActionCancelsRestFromRestAndTogglesWhilePaused() {
        XCTAssertEqual(ActiveSessionControlRouting.restButtonAction(for: .rest, currentRecoveryType: .rest), .cancelRest)
        XCTAssertEqual(ActiveSessionControlRouting.restButtonAction(for: .paused), .toggleRestWhilePaused)
    }

    func testRestButtonActionStartsRestFromActiveRecovery() {
        XCTAssertEqual(
            ActiveSessionControlRouting.restButtonAction(for: .rest, currentRecoveryType: .activeRecovery),
            .startRest
        )
    }

    func testPauseResumeActionMapsPausedToResumeAndOthersToPause() {
        XCTAssertEqual(ActiveSessionControlRouting.pauseResumeAction(for: .paused), .resume)
        XCTAssertEqual(ActiveSessionControlRouting.pauseResumeAction(for: .active), .pause)
        XCTAssertEqual(ActiveSessionControlRouting.pauseResumeAction(for: .rest), .pause)
    }

    func testPageTransitionDelayMatchesCurrentControlsTiming() {
        XCTAssertEqual(ActiveSessionControlRouting.pageTransitionDelay, .milliseconds(140))
    }

    func testPauseResumeActionTreatsEndingStatesAsPause() {
        XCTAssertEqual(ActiveSessionControlRouting.pauseResumeAction(for: .ending), .pause)
        XCTAssertEqual(ActiveSessionControlRouting.pauseResumeAction(for: .ended), .pause)
    }
}
