import XCTest
@testable import Rundr

final class ActionButtonCommandRouterTests: XCTestCase {

    func testStartWorkoutCommandRoutesToLapWhileActive() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .startWorkout,
                runState: .active
            ),
            .markLap
        )
    }

    func testStartWorkoutCommandRoutesToResumeWhilePaused() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .startWorkout,
                runState: .paused
            ),
            .resumeSession
        )
    }

    func testMarkLapCommandRoutesToLapWhileActive() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .markLap,
                runState: .active
            ),
            .markLap
        )
    }

    func testMarkLapCommandRoutesToResumeWhilePaused() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .markLap,
                runState: .paused
            ),
            .resumeSession
        )
    }

    func testMarkLapCommandDefersWhileWorkoutIsStarting() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .markLap,
                runState: .ready
            ),
            .deferUntilReady
        )
    }

    func testStartWorkoutCommandStartsWorkoutFromIdleState() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .startWorkout,
                runState: .idle
            ),
            .startWorkout
        )
    }

    func testStartWorkoutCommandStartsWorkoutFromReadyState() {
        XCTAssertEqual(
            ActionButtonCommandRouter.route(
                command: .startWorkout,
                runState: .ready
            ),
            .startWorkout
        )
    }
}
