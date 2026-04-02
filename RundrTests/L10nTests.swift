import XCTest
@testable import Rundr

final class L10nTests: XCTestCase {

    func testLapCardPlaceholderUsesDoubleDash() {
        XCTAssertEqual(L10n.lapCardPlaceholder, "--")
    }

    func testUseSessionSettingsLabelUsesSessionPlanWording() {
        XCTAssertEqual(L10n.useSessionSettings, "Use Session Plan")
    }

    func testUseActivityConfirmationTitleUsesShortPlanWording() {
        XCTAssertEqual(L10n.useActivityConfirmationTitle, "Use this plan?")
    }

    func testRedoActivityLabelUsesReuseSessionPlanWording() {
        XCTAssertEqual(L10n.redoActivity, "Reuse Session Plan")
    }

    func testReusePlanLabelExistsForWatchActionMenu() {
        XCTAssertEqual(L10n.reusePlan, "Reuse Plan")
    }

    func testThisSessionLabelExistsForActionMenuTitle() {
        XCTAssertEqual(L10n.thisSession, "This Session")
    }

    func testYesLabelExistsForConfirmationActions() {
        XCTAssertEqual(L10n.yes, "Yes")
    }
}
