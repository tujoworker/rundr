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

    func testCompanionEmptyStateLabelsExist() {
        XCTAssertEqual(L10n.noSyncedSessionsYet, "Start an interval session on Apple Watch.")
        XCTAssertEqual(L10n.noSavedIntervalsYet, "No saved sessions yet")
        XCTAssertEqual(
            L10n.savedIntervalsPlaceholderDetail,
            "Open a predefined session to save your own version."
        )
        XCTAssertEqual(L10n.noSessionPlanIntervalsTitle, "No intervals yet")
        XCTAssertEqual(L10n.noSessionPlanIntervalsDetail, "Tap + to add your first interval.")
    }

    func testUseItNowLabelExistsForCompanionAdjustIntervalAction() {
        XCTAssertEqual(L10n.useItNow, "Use it now")
    }

    func testCompanionTransferLabelsExist() {
        XCTAssertEqual(L10n.sharePlan, "Share Plan")
        XCTAssertEqual(L10n.shareSession, "Share Session")
        XCTAssertEqual(L10n.importFile, "Import File")
        XCTAssertEqual(L10n.planImportedTitle, "Plan Imported")
        XCTAssertEqual(L10n.planImportedMessage, "The plan was added to My Sessions.")
        XCTAssertEqual(L10n.sessionImportedTitle, "Session Imported")
        XCTAssertEqual(L10n.newInterval, "New Session")
        XCTAssertEqual(L10n.addInterval, "Add Session")
        XCTAssertEqual(L10n.myIntervals, "My Sessions")
        XCTAssertEqual(L10n.editInterval, "Edit Session")
        XCTAssertEqual(L10n.adjustSettings, "Adjust Session")
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
        XCTAssertEqual(L10n.helpActiveRecoveryTitle, "Active Recovery")
        XCTAssertEqual(L10n.helpActiveRecoveryTrackingHeading, "How Rundr Tracks It")
        XCTAssertEqual(L10n.helpActiveRecoveryUseHeading, "When to Use It")
        XCTAssertEqual(L10n.helpLastRestTitle, "Last Rest")
        XCTAssertEqual(L10n.helpLastRestWhenHeading, "When It Applies")
        XCTAssertEqual(L10n.helpLastRestWhyHeading, "Why Use It")
        XCTAssertEqual(L10n.helpIntervalTypeTitle, "Interval Type")
        XCTAssertEqual(L10n.helpDistanceTypeFixedHeading, "Distance")
        XCTAssertEqual(L10n.gpsAlsoEnabledSubtitle, "Time intervals use GPS to measure distance.")
    }

    func testIntervalTypeLabelsExist() {
        XCTAssertEqual(L10n.intervalType, "Interval Type")
        XCTAssertEqual(L10n.distanceInterval, "Distance")
        XCTAssertEqual(L10n.timeInterval, "Time")
        XCTAssertEqual(L10n.segmentName, "Title")
        XCTAssertEqual(L10n.optionalSegmentNamePlaceholder, "(optional)")
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
        XCTAssertEqual(L10n.syncAppearanceMode, "Sync")
        XCTAssertEqual(
            L10n.syncAppearanceModeDetail,
            "When off, iPhone and Apple Watch keep separate appearance settings."
        )
    }

    func testCompanionDescriptionPlaceholderExists() {
        XCTAssertEqual(L10n.optionalDescriptionPlaceholder, "Description (optional)")
    }

    func testPredefinedWorkoutTitlesExist() {
        XCTAssertEqual(L10n.predefinedFortyFiveFifteensTitle, "45/15")
        XCTAssertEqual(L10n.predefinedFourByFourTitle, "4x4 Intervals")
        XCTAssertEqual(L10n.predefinedThresholdSixesTitle, "Threshold 6-Min Reps")
        XCTAssertEqual(L10n.predefinedThousandRepeatsTitle, "6 x 1000 m")
        XCTAssertEqual(L10n.predefinedThirtyFifteensTitle, "30/15")
        XCTAssertEqual(L10n.predefinedOverUnderTitle, "Over/Under")
        XCTAssertEqual(L10n.predefinedPyramidTitle, "Pyramid")
        XCTAssertEqual(L10n.predefinedFourHundredRepeatsTitle, "10 x 400 m")
        XCTAssertEqual(L10n.predefinedFourHundredRepeatsNoRestTitle, "10 x 400 m without rest")
        XCTAssertEqual(L10n.predefinedStructuredFartlekTitle, "Structured Fartlek")
        XCTAssertEqual(L10n.predefinedLongTwelvesTitle, "Long Intervals")
    }

    func testPredefinedWorkoutDescriptionsExist() {
        XCTAssertEqual(L10n.predefinedFortyFiveFifteensDescription, "20-30 x (45s / 15s), continuous or 2 sets. Maximum threshold time with micro-recovery. High quality without full fatigue.")
        XCTAssertEqual(L10n.predefinedOverUnderDescription, "4 x 8 min alternating 1 min over / 1 min under. Trains lactate handling and pace changes.")
        XCTAssertEqual(L10n.predefinedFourHundredRepeatsDescription, "10 x 400 m / 90s active recovery, split sets optional. Speed plus running economy. Classic and effective.")
        XCTAssertEqual(L10n.predefinedFourHundredRepeatsNoRestDescription, "10 x 400 m continuous, no rest between reps. Trains pace control and relaxed form under accumulating fatigue.")
    }

    func testUsedCountFormatsAsCompactBadgeText() {
        XCTAssertEqual(L10n.usedCount(3), "3x")
    }
}
