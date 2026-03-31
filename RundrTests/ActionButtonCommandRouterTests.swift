import XCTest
@testable import Rundr

final class ActionButtonCommandRouterTests: XCTestCase {

    func testStartWorkoutCommandRoutesToLapWhileActiveSessionIsShowing() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .startWorkout,
                runState: .active,
                currentScreen: .preStart,
                isShowingActiveSession: true
            ),
            .markLap
        )
    }

    func testStartWorkoutCommandRoutesToResumeWhilePausedActiveSessionIsShowing() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .startWorkout,
                runState: .paused,
                currentScreen: .preStart,
                isShowingActiveSession: true
            ),
            .resumeSession
        )
    }

    func testMarkLapCommandStillStartsWorkoutFromPreStart() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .markLap,
                runState: .ready,
                currentScreen: .preStart,
                isShowingActiveSession: false
            ),
            .startWorkoutFromPreStart
        )
    }

    func testMarkLapCommandResumesPausedActiveSession() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .markLap,
                runState: .paused,
                currentScreen: .preStart,
                isShowingActiveSession: true
            ),
            .resumeSession
        )
    }

    func testCommandsAreIgnoredOutsidePreStartWhenSessionIsNotShowing() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .startWorkout,
                runState: .ready,
                currentScreen: .home,
                isShowingActiveSession: false
            ),
            .noOp
        )
    }
}
