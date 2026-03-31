import XCTest
@testable import Rundr

final class L10nTests: XCTestCase {

    func testLapCardPlaceholderUsesDoubleDash() {
        XCTAssertEqual(L10n.lapCardPlaceholder, "--")
    }
}
