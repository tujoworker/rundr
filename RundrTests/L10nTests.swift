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

    func testShowMatchingSessionsLabelExistsForHistoryActionMenu() {
        XCTAssertEqual(L10n.showMatchingSessions, "Show Matching")
        XCTAssertEqual(L10n.matchingSessions, "Matching Sessions")
        XCTAssertEqual(L10n.noOtherMatchingSessionsYet, "No other matching sessions yet")
    }

    func testUseItNowLabelExistsForCompanionAdjustIntervalAction() {
        XCTAssertEqual(L10n.useItNow, "Use it now")
    }

    func testCompanionTransferLabelsExist() {
        XCTAssertEqual(L10n.sharePlan, "Share Plan")
        XCTAssertEqual(L10n.shareSession, "Share Session")
        XCTAssertEqual(L10n.importFile, "Import File")
        XCTAssertEqual(L10n.planImportedTitle, "Plan Imported")
        XCTAssertEqual(L10n.sessionImportedTitle, "Session Imported")
        XCTAssertEqual(L10n.newInterval, "New Interval")
        XCTAssertEqual(L10n.addInterval, "Add Interval")
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
        XCTAssertEqual(L10n.helpOverviewTitle, "Overview")
        XCTAssertEqual(L10n.helpSessionPlanTitle, "Session Plan")
        XCTAssertEqual(L10n.helpSharingTitle, "Sharing")
        XCTAssertEqual(L10n.helpSharingSendHeading, "Send")
        XCTAssertEqual(L10n.helpSharingReceiveHeading, "Receive")
        XCTAssertEqual(L10n.helpRestTitle, "Mark as Rest")
        XCTAssertEqual(L10n.helpAutoRestTitle, "How Auto-detect Works")
        XCTAssertEqual(L10n.helpTrackingModeTitle, "Tracking Mode")
        XCTAssertEqual(L10n.helpDistanceTypeFixedHeading, "Fixed")
        XCTAssertEqual(L10n.helpTrackingModeDualHeading, "Dual")
    }

    func testMoreLabelExistsForCompanionOverflowTab() {
        XCTAssertEqual(L10n.more, "More")
    }

    func testCompanionLegalLabelsExist() {
        XCTAssertEqual(L10n.privacyPolicy, "Privacy Policy")
        XCTAssertEqual(L10n.termsOfUse, "Terms of Use")
        XCTAssertEqual(L10n.privacyWhatRundrStoresTitle, "What Rundr Stores")
        XCTAssertEqual(L10n.termsResponsibilityTitle, "Your Responsibility")
    }

    func testCompanionAppearanceSyncLabelsExist() {
        XCTAssertEqual(L10n.syncAppearanceMode, "Sync Light/Dark Mode")
        XCTAssertEqual(
            L10n.syncAppearanceModeDetail,
            "When off, iPhone and Apple Watch keep separate appearance settings."
        )
    }

    func testUsedCountFormatsAsCompactBadgeText() {
        XCTAssertEqual(L10n.usedCount(3), "3x")
    }
}
