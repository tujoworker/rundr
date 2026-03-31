import XCTest
@testable import Rundr

final class ActionButtonCommandStoreTests: XCTestCase {

    override func tearDown() {
        ActionButtonCommandStore.clearPendingCommand()
        super.tearDown()
    }

    func testQueueAndConsumePendingCommandRoundTrips() {
        ActionButtonCommandStore.queue(.markLap)

        XCTAssertEqual(ActionButtonCommandStore.pendingCommand(), .markLap)
        XCTAssertEqual(ActionButtonCommandStore.consumePendingCommand(), .markLap)
        XCTAssertNil(ActionButtonCommandStore.pendingCommand())
    }

    func testClearPendingCommandRemovesQueuedCommand() {
        ActionButtonCommandStore.queue(.startWorkout)

        ActionButtonCommandStore.clearPendingCommand()

        XCTAssertNil(ActionButtonCommandStore.pendingCommand())
    }
}
