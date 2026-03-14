import XCTest
@testable import LapLog

@MainActor
final class WorkoutControllerTests: XCTestCase {

    private func makeController() -> WorkoutSessionController {
        let controller = WorkoutSessionController()
        return controller
    }

    // MARK: - Initial State

    func testInitialState() {
        let controller = makeController()
        XCTAssertEqual(controller.runState, .idle)
        XCTAssertEqual(controller.elapsedSeconds, 0)
        XCTAssertNil(controller.currentHeartRate)
        XCTAssertEqual(controller.cumulativeDistanceMeters, 0)
        XCTAssertTrue(controller.completedLaps.isEmpty)
    }

    // MARK: - Get Ready

    func testGetReady() {
        let controller = makeController()
        controller.getReady()
        XCTAssertEqual(controller.runState, .ready)
    }

    // MARK: - Heart Rate Updates

    func testHeartRateUpdate() {
        let controller = makeController()
        controller.handleHeartRateUpdate(bpm: 145)
        XCTAssertEqual(controller.currentHeartRate, 145)
        controller.handleHeartRateUpdate(bpm: 160)
        XCTAssertEqual(controller.currentHeartRate, 160)
    }

    // MARK: - Distance Updates

    func testDistanceUpdate() {
        let controller = makeController()
        controller.handleDistanceUpdate(additionalMeters: 100)
        XCTAssertEqual(controller.cumulativeDistanceMeters, 100)
        controller.handleDistanceUpdate(additionalMeters: 50)
        XCTAssertEqual(controller.cumulativeDistanceMeters, 150)
    }
}
