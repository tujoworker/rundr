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

    func testDeletePlanStringsExistForCompanionEditorMenu() {
        XCTAssertEqual(L10n.deletePlan, "Delete Plan")
        XCTAssertEqual(L10n.deletePlanConfirmMessage, "This plan will be permanently deleted.")
    }

    func testCompanionHelpLabelsExist() {
        XCTAssertEqual(L10n.help, "Help")
        XCTAssertEqual(L10n.helpSessionPlanTitle, "Session Plan")
        XCTAssertEqual(L10n.helpTrackingModeTitle, "Tracking Mode")
        XCTAssertEqual(L10n.helpDistanceTypeFixedHeading, "Fixed")
        XCTAssertEqual(L10n.helpTrackingModeDualHeading, "Dual")
    }

    func testMoreLabelExistsForCompanionOverflowTab() {
        XCTAssertEqual(L10n.more, "More")
    }

    func testUsedCountFormatsAsCompactBadgeText() {
        XCTAssertEqual(L10n.usedCount(3), "3x")
    }
}
