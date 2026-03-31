import XCTest
@testable import Rundr

final class ActionButtonCommandRouterTests: XCTestCase {

    func testMarkLapCommandRoutesToLapWhileActiveSessionIsShowing() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .markLap,
                runState: .active,
                currentScreen: .home,
                isShowingActiveSession: false
            ),
            .markLap
        )
    }

    func testMarkLapCommandRoutesToResumeWhilePausedActiveSessionIsShowing() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .markLap,
                runState: .paused,
                currentScreen: .home,
                isShowingActiveSession: false
            ),
            .resumeSession
        )
    }

    func testStartWorkoutCommandStartsWorkoutFromPreStart() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .startWorkout,
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
                currentScreen: .home,
                isShowingActiveSession: false
            ),
            .resumeSession
        )
    }

    func testMarkLapCommandDefersWhileWorkoutIsStarting() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .markLap,
                runState: .ready,
                currentScreen: .preStart,
                isShowingActiveSession: true
            ),
            .deferUntilReady
        )
    }

    func testStartWorkoutCommandIsIgnoredOutsidePreStartWhenSessionIsNotShowing() {
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
