import XCTest
@testable import Rundr

final class SessionHistoryLapRowRoutingTests: XCTestCase {

    func testShowsLapBadgeForActiveLaps() {
        XCTAssertTrue(SessionHistoryLapRowRouting.showsLapBadge(for: .active))
    }

    func testHidesLapBadgeForRecoveryLaps() {
        XCTAssertFalse(SessionHistoryLapRowRouting.showsLapBadge(for: .rest))
        XCTAssertFalse(SessionHistoryLapRowRouting.showsLapBadge(for: .activeRecovery))
    }
}