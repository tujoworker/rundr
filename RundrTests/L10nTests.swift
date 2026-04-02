import XCTest
@testable import Rundr

final class L10nTests: XCTestCase {

    func testLapCardPlaceholderUsesDoubleDash() {
        XCTAssertEqual(L10n.lapCardPlaceholder, "--")
    }

    func testUseSessionSettingsLabelUsesSessionPlanWording() {
        XCTAssertEqual(L10n.useSessionSettings, "Use Session Plan")
    }

    func testRedoActivityLabelUsesReuseSessionPlanWording() {
        XCTAssertEqual(L10n.redoActivity, "Reuse Session Plan")
    }
}
