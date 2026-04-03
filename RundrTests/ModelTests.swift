import XCTest
@testable import Rundr

final class ModelTests: XCTestCase {

    // MARK: - Health Access Error Messages

    func testHealthAccessErrorMapsMissingEntitlementMessage() {
        XCTAssertEqual(
            HealthKitManager.presentableAuthorizationError(from: "Missing com.apple.developer.healthkit entitlement."),
            L10n.healthAccessMissingEntitlement
        )
    }

    func testHealthAccessErrorPreservesUnknownMessage() {
        XCTAssertEqual(
            HealthKitManager.presentableAuthorizationError(from: "Some other HealthKit failure."),
            "Some other HealthKit failure."
        )
    }

    func testWorkoutAuthorizationRetryWaitsForDelayedGrant() async {
        var callCount = 0

        let isAuthorized = await HealthKitManager.waitForWorkoutAuthorization(
            maxAttempts: 3,
            retryDelay: .milliseconds(1)
        ) {
            callCount += 1
            return callCount >= 3 ? .sharingAuthorized : .notDetermined
        }

        XCTAssertTrue(isAuthorized)
        XCTAssertEqual(callCount, 3)
    }

    func testWorkoutAuthorizationRetryReturnsFalseWhenGrantNeverArrives() async {
        var callCount = 0

        let isAuthorized = await HealthKitManager.waitForWorkoutAuthorization(
            maxAttempts: 2,
            retryDelay: .milliseconds(1)
        ) {
            callCount += 1
            return .notDetermined
        }

        XCTAssertFalse(isAuthorized)
        XCTAssertEqual(callCount, 2)
    }

    // MARK: - Health Access Policy

    func testInitialHealthPromptShowsWhenAccessIsPending() {
        XCTAssertTrue(
            HealthAccessPolicy.shouldShowInitialPrompt(
                hasCompletedInitialPrompt: false,
                hasDismissedPromptThisLaunch: false,
                isAuthorized: false
            )
        )
    }

    func testInitialHealthPromptStaysHiddenWhenAlreadyAuthorized() {
        XCTAssertFalse(
            HealthAccessPolicy.shouldShowInitialPrompt(
                hasCompletedInitialPrompt: false,
                hasDismissedPromptThisLaunch: false,
                isAuthorized: true
            )
        )
    }

    func testInitialHealthPromptStaysHiddenAfterLaunchDismissal() {
        XCTAssertFalse(
            HealthAccessPolicy.shouldShowInitialPrompt(
                hasCompletedInitialPrompt: false,
                hasDismissedPromptThisLaunch: true,
                isAuthorized: false
            )
        )
    }

    func testInitialHealthPromptStaysIncompleteWhenAuthorizationIsNotGranted() {
        XCTAssertFalse(
            HealthAccessPolicy.shouldCompleteInitialPromptAfterRequest(isAuthorized: false)
        )
    }

    func testInitialHealthPromptCompletesWhenAuthorizationIsGranted() {
        XCTAssertTrue(
            HealthAccessPolicy.shouldCompleteInitialPromptAfterRequest(isAuthorized: true)
        )
    }

    func testInitialHealthPromptDismissesForCurrentLaunchWhenAuthorizationIsNotGranted() {
        XCTAssertTrue(
            HealthAccessPolicy.shouldDismissInitialPromptForCurrentLaunchAfterRequest(
                isAuthorized: false,
                authorizationError: nil
            )
        )
    }

    func testInitialHealthPromptStaysVisibleWhenAuthorizationReturnsError() {
        XCTAssertFalse(
            HealthAccessPolicy.shouldDismissInitialPromptForCurrentLaunchAfterRequest(
                isAuthorized: false,
                authorizationError: L10n.healthAccessMissingEntitlement
            )
        )
    }

    func testInitialHealthPromptDoesNotDismissForCurrentLaunchWhenAuthorizationIsGranted() {
        XCTAssertFalse(
            HealthAccessPolicy.shouldDismissInitialPromptForCurrentLaunchAfterRequest(
                isAuthorized: true,
                authorizationError: nil
            )
        )
    }

    // MARK: - TrackingMode

    func testTrackingModeDisplayNames() {
        XCTAssertEqual(TrackingMode.gps.displayName, "GPS")
        XCTAssertEqual(TrackingMode.dual.displayName, "Dual")
        XCTAssertEqual(TrackingMode.distanceDistance.displayName, "Manual")
    }

    func testCompanionAboutStringsExistForInfoScreens() {
        XCTAssertEqual(L10n.aboutRundr, "About Rundr")
        XCTAssertEqual(L10n.intro, "Intro")
        XCTAssertEqual(L10n.about, "About")
        XCTAssertEqual(L10n.introPageLabel(2, 3), "Page 2 of 3")
    }

    func testTrackingModeAllCases() {
        XCTAssertEqual(TrackingMode.allCases.count, 3)
        XCTAssertEqual(TrackingMode.allCases.last, .gps)
    }

    func testTrackingModeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for mode in TrackingMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(TrackingMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testResolvedTrackingModeForcesDualWhenOpenDistanceExists() {
        let resolved = WorkoutPlanSupport.resolvedTrackingMode(
            requestedTrackingMode: .distanceDistance,
            segments: [DistanceSegment(distanceMeters: 0, distanceGoalMode: .open)]
        )

        XCTAssertEqual(resolved, .dual)
    }

    func testResolvedTrackingModeKeepsGPSContextWhenSwitchingToManualIntervals() {
        let resolved = WorkoutPlanSupport.resolvedTrackingMode(
            requestedTrackingMode: .distanceDistance,
            segments: [.default],
            currentTrackingMode: .gps
        )

        XCTAssertEqual(resolved, .dual)
    }

    // MARK: - LapType

    func testLapTypeDisplayNames() {
        XCTAssertEqual(LapType.active.displayName, "Activity")
        XCTAssertEqual(LapType.rest.displayName, "Rest")
    }

    func testLapTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for lapType in LapType.allCases {
            let data = try encoder.encode(lapType)
            let decoded = try decoder.decode(LapType.self, from: data)
            XCTAssertEqual(decoded, lapType)
        }
    }

    // MARK: - LapSource

    func testLapSourceCases() {
        XCTAssertEqual(LapSource.allCases.count, 5)
        XCTAssertNotNil(LapSource(rawValue: "distanceTap"))
        XCTAssertNotNil(LapSource(rawValue: "actionButton"))
        XCTAssertNotNil(LapSource(rawValue: "autoDistance"))
        XCTAssertNotNil(LapSource(rawValue: "autoTime"))
        XCTAssertNotNil(LapSource(rawValue: "sessionEndSplit"))
    }

    // MARK: - RestMode

    func testRestModeDisplayNames() {
        XCTAssertEqual(RestMode.manual.displayName, L10n.restManual)
        XCTAssertEqual(RestMode.autoDetect.displayName, L10n.restAutoDetect)
    }

    func testRestModeAllCases() {
        XCTAssertEqual(RestMode.allCases.count, 2)
        XCTAssertTrue(RestMode.allCases.contains(.manual))
        XCTAssertTrue(RestMode.allCases.contains(.autoDetect))
    }

    func testRestModeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for mode in RestMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(RestMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testDistanceSegmentCodablePreservesLastRestSeconds() throws {
        let segment = DistanceSegment(
            distanceMeters: 400,
            repeatCount: 4,
            restSeconds: 30,
            lastRestSeconds: 90,
            targetTimeSeconds: 75
        )

        let data = try JSONEncoder().encode(segment)
        let decoded = try JSONDecoder().decode(DistanceSegment.self, from: data)

        XCTAssertEqual(decoded.lastRestSeconds, 90)
        XCTAssertEqual(decoded.restSeconds, 30)
        XCTAssertEqual(decoded.targetTimeSeconds, 75)
    }

    func testDistanceSegmentDecodesLegacyPayloadWithoutLastRestSeconds() throws {
        let payload = """
        {
          \"distanceMeters\": 400,
          \"distanceGoalMode\": \"fixed\",
          \"repeatCount\": 4,
          \"restSeconds\": 30
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(DistanceSegment.self, from: payload)

        XCTAssertEqual(decoded.restSeconds, 30)
        XCTAssertNil(decoded.lastRestSeconds)
    }

    func testSegmentEditSheetSectionOrderForFixedDistancePlacesLastRestAfterRest() {
        XCTAssertEqual(
            SegmentEditSheetSection.orderedSections(for: false),
            [.rest, .lastRest, .repeats, .paceTarget, .timeTarget]
        )
    }

    func testSegmentEditSheetSectionOrderForOpenDistancePlacesLastRestAfterRest() {
        XCTAssertEqual(
            SegmentEditSheetSection.orderedSections(for: true),
            [.timeTarget, .rest, .lastRest, .repeats]
        )
    }

    func testLastRestAvailabilityDependsOnRepeatCountNotRest() {
        XCTAssertTrue(
            SegmentEditSheetRules.canConfigureLastRest(repeatCount: 3, restSeconds: 0)
        )
        XCTAssertFalse(
            SegmentEditSheetRules.canConfigureLastRest(repeatCount: 0, restSeconds: 45)
        )
    }

    func testAddLastRestButtonVisibilityDependsOnLastRestValue() {
        XCTAssertTrue(
            SegmentEditSheetRules.shouldShowAddLastRestButton(lastRestSeconds: 0)
        )
        XCTAssertFalse(
            SegmentEditSheetRules.shouldShowAddLastRestButton(lastRestSeconds: 45)
        )
    }

    func testAddLastRestTapActionShowsInfoWhenRepeatsAreMissing() {
        XCTAssertEqual(
            SegmentEditSheetRules.addLastRestAction(repeatCount: 0),
            .showRepeatsInfo
        )
        XCTAssertEqual(
            SegmentEditSheetRules.addLastRestAction(repeatCount: 3),
            .addValue
        )
    }

    func testLastRestNormalizationClearsValueWhenRepeatsBecomeOpenEnded() {
        XCTAssertEqual(
            SegmentEditSheetRules.normalizedLastRestSeconds(60, repeatCount: 3),
            60
        )
        XCTAssertEqual(
            SegmentEditSheetRules.normalizedLastRestSeconds(60, repeatCount: 0),
            0
        )
    }

    func testSegmentEditInputParserParsesDurationFormats() {
        XCTAssertEqual(SegmentEditInputParser.parseDurationSeconds(from: "75"), 75)
        XCTAssertEqual(SegmentEditInputParser.parseDurationSeconds(from: "1:15"), 75)
        XCTAssertEqual(SegmentEditInputParser.parseDurationSeconds(from: "1:02:03"), 3723)
        XCTAssertEqual(SegmentEditInputParser.parseDurationSeconds(from: "1:99"), 0)
        XCTAssertEqual(SegmentEditInputParser.parseDurationSeconds(from: ""), 0)
    }

    func testSegmentEditInputParserAppliesDurationKeys() {
        var text = ""

        SegmentEditInputParser.applyDurationKey("0", to: &text)
        SegmentEditInputParser.applyDurationKey("1", to: &text)

        XCTAssertEqual(text, "01:")

        SegmentEditInputParser.applyDurationKey("⌫", to: &text)
        SegmentEditInputParser.applyDurationKey("⌫", to: &text)
        SegmentEditInputParser.applyDurationKey("⌫", to: &text)
        XCTAssertEqual(text, "")

        SegmentEditInputParser.applyDurationKey("1", to: &text)
        SegmentEditInputParser.applyDurationKey("5", to: &text)

        XCTAssertEqual(text, "15:")

        SegmentEditInputParser.applyDurationKey("3", to: &text)
        SegmentEditInputParser.applyDurationKey("0", to: &text)

        XCTAssertEqual(text, "15:30")

        SegmentEditInputParser.applyDurationKey(":", to: &text)
        SegmentEditInputParser.applyDurationKey("4", to: &text)
        SegmentEditInputParser.applyDurationKey("5", to: &text)

        XCTAssertEqual(text, "15:30")

        SegmentEditInputParser.applyDurationKey(":", to: &text)
        XCTAssertEqual(text, "15:30")

        SegmentEditInputParser.applyDurationKey("⌫", to: &text)
        XCTAssertEqual(text, "15:3")

        SegmentEditInputParser.applyDurationKey("9", to: &text)
        XCTAssertEqual(text, "15:39")

        SegmentEditInputParser.applyDurationKey("9", to: &text)
        XCTAssertEqual(text, "15:39")
    }

    func testSegmentEditInputParserCapsDurationInputAtNinetyNineNinetyNine() {
        var text = ""

        SegmentEditInputParser.applyDurationKey("9", to: &text)
        SegmentEditInputParser.applyDurationKey("9", to: &text)
        SegmentEditInputParser.applyDurationKey("9", to: &text)
        SegmentEditInputParser.applyDurationKey("9", to: &text)
        SegmentEditInputParser.applyDurationKey("9", to: &text)

        XCTAssertEqual(text, "99:99")
    }

    func testSegmentEditInputParserParsesRepeatCounts() {
        XCTAssertEqual(SegmentEditInputParser.parseRepeatCount(from: "12"), 12)
        XCTAssertEqual(SegmentEditInputParser.parseRepeatCount(from: " 7 "), 7)
        XCTAssertEqual(SegmentEditInputParser.parseRepeatCount(from: ""), 0)
    }

    func testSegmentEditInputParserAppliesRepeatKeys() {
        var text = ""

        SegmentEditInputParser.applyRepeatKey("0", to: &text)
        SegmentEditInputParser.applyRepeatKey("1", to: &text)
        XCTAssertEqual(text, "01")

        SegmentEditInputParser.applyRepeatKey("8", to: &text)
        XCTAssertEqual(text, "018")

        SegmentEditInputParser.applyRepeatKey("⌫", to: &text)
        XCTAssertEqual(text, "01")

        SegmentEditInputParser.applyRepeatKey("1", to: &text)
        SegmentEditInputParser.applyRepeatKey("2", to: &text)
        XCTAssertEqual(text, "0112")

        SegmentEditInputParser.applyRepeatKey("∞", to: &text)
        XCTAssertEqual(text, "")
    }

    func testSegmentEditInputParserAppliesDistanceKeys() {
        var text = ""

        SegmentEditInputParser.applyDistanceKey("0", to: &text)
        SegmentEditInputParser.applyDistanceKey("1", to: &text)
        XCTAssertEqual(text, "01")

        SegmentEditInputParser.applyDistanceKey(".", to: &text)
        XCTAssertEqual(text, "01.")

        SegmentEditInputParser.applyDistanceKey(".", to: &text)
        XCTAssertEqual(text, "01.")

        SegmentEditInputParser.applyDistanceKey("5", to: &text)
        XCTAssertEqual(text, "01.5")

        SegmentEditInputParser.applyDistanceKey("⌫", to: &text)
        XCTAssertEqual(text, "01.")
    }

    func testCompanionSegmentEditorRulesCanOpenEditor() {
        XCTAssertTrue(
            CompanionSegmentEditorRules.canOpenEditor(
                field: .time,
                lastRestSeconds: nil
            )
        )
        XCTAssertTrue(
            CompanionSegmentEditorRules.canOpenEditor(
                field: .pace,
                lastRestSeconds: nil
            )
        )
        XCTAssertTrue(
            CompanionSegmentEditorRules.canOpenEditor(
                field: .lastRest,
                lastRestSeconds: 15
            )
        )
        XCTAssertFalse(
            CompanionSegmentEditorRules.canOpenEditor(
                field: .lastRest,
                lastRestSeconds: 0
            )
        )
    }

    func testCompanionSegmentEditorRulesEmptyDisplayValue() {
        XCTAssertEqual(
            CompanionSegmentEditorRules.emptyDisplayValue(for: .time),
            L10n.off
        )
        XCTAssertEqual(
            CompanionSegmentEditorRules.emptyDisplayValue(for: .pace),
            L10n.off
        )
        XCTAssertNil(
            CompanionSegmentEditorRules.emptyDisplayValue(for: .distance)
        )
    }

    func testSegmentEditorValueRulesClearLastRestWhenRepeatsAreUnlimited() {
        XCTAssertEqual(
            SegmentEditorValueRules.normalizedLastRestSeconds(lastRestSeconds: 45, repeatCount: nil),
            nil
        )
        XCTAssertEqual(
            SegmentEditorValueRules.normalizedLastRestSeconds(lastRestSeconds: 45, repeatCount: 0),
            nil
        )
        XCTAssertEqual(
            SegmentEditorValueRules.normalizedLastRestSeconds(lastRestSeconds: 45, repeatCount: 3),
            45
        )
    }

    func testSegmentEditorValueRulesClearPaceForOpenDistance() {
        XCTAssertEqual(
            SegmentEditorValueRules.normalizedTargetPace(
                for: .open,
                targetPaceSecondsPerKm: 320
            ),
            nil
        )
        XCTAssertEqual(
            SegmentEditorValueRules.normalizedTargetPace(
                for: .fixed,
                targetPaceSecondsPerKm: 320
            ),
            320
        )
    }

    func testSegmentEditorValueRulesSettingTimeClearsPaceOnlyWhenTimeIsSet() {
        let withTime = SegmentEditorValueRules.updatedTargetsAfterSettingTime(
            seconds: 95,
            currentPaceSecondsPerKm: 300
        )
        XCTAssertEqual(withTime.targetTimeSeconds, 95)
        XCTAssertNil(withTime.targetPaceSecondsPerKm)

        let clearedTime = SegmentEditorValueRules.updatedTargetsAfterSettingTime(
            seconds: 0,
            currentPaceSecondsPerKm: 300
        )
        XCTAssertNil(clearedTime.targetTimeSeconds)
        XCTAssertEqual(clearedTime.targetPaceSecondsPerKm, 300)
    }

    func testSegmentEditorValueRulesSettingPaceClearsTimeOnlyWhenPaceIsSet() {
        let withPace = SegmentEditorValueRules.updatedTargetsAfterSettingPace(
            secondsPerKm: 280,
            currentTargetTimeSeconds: 90
        )
        XCTAssertNil(withPace.targetTimeSeconds)
        XCTAssertEqual(withPace.targetPaceSecondsPerKm, 280)

        let clearedPace = SegmentEditorValueRules.updatedTargetsAfterSettingPace(
            secondsPerKm: 0,
            currentTargetTimeSeconds: 90
        )
        XCTAssertEqual(clearedPace.targetTimeSeconds, 90)
        XCTAssertNil(clearedPace.targetPaceSecondsPerKm)
    }

    // MARK: - WorkoutRunState

    func testWorkoutRunStateCases() {
        let states: [WorkoutRunState] = [.idle, .ready, .active, .rest, .paused, .ending, .ended]
        XCTAssertEqual(states.count, 7)
        XCTAssertEqual(WorkoutRunState.idle, WorkoutRunState.idle)
        XCTAssertNotEqual(WorkoutRunState.idle, WorkoutRunState.active)
        XCTAssertNotEqual(WorkoutRunState.ending, WorkoutRunState.ended)
    }

    func testLiveWorkoutStateTerminalStateDetection() {
        let activeState = LiveWorkoutStateRecord(
            sessionID: UUID(),
            startedAt: Date(),
            updatedAt: Date(),
            runState: .active,
            trackingMode: .gps,
            elapsedSeconds: 120,
            lapElapsedSeconds: 60,
            completedLapCount: 2,
            cumulativeDistanceMeters: 800,
            cumulativeGPSDistanceMeters: 800,
            currentHeartRate: 150,
            currentTargetDistanceMeters: nil,
            restElapsedSeconds: nil,
            restDurationSeconds: nil,
            isGPSActive: true
        )
        let endedState = LiveWorkoutStateRecord(
            sessionID: UUID(),
            startedAt: Date(),
            updatedAt: Date(),
            runState: .ended,
            trackingMode: .gps,
            elapsedSeconds: 240,
            lapElapsedSeconds: 0,
            completedLapCount: 4,
            cumulativeDistanceMeters: 1600,
            cumulativeGPSDistanceMeters: 1600,
            currentHeartRate: nil,
            currentTargetDistanceMeters: nil,
            restElapsedSeconds: nil,
            restDurationSeconds: nil,
            isGPSActive: false
        )

        XCTAssertFalse(activeState.isTerminalState)
        XCTAssertTrue(endedState.isTerminalState)
    }

    // MARK: - Lap Initialization

    func testLapCreation() {
        let now = Date()
        let later = now.addingTimeInterval(90)
        let lap = Lap(
            index: 1,
            startedAt: now,
            endedAt: later,
            durationSeconds: 90,
            distanceMeters: 400,
            averageSpeedMetersPerSecond: 4.44,
            averageHeartRateBPM: 155,
            lapType: .active,
            source: .distanceTap
        )
        XCTAssertEqual(lap.index, 1)
        XCTAssertEqual(lap.distanceMeters, 400)
        XCTAssertEqual(lap.durationSeconds, 90)
        XCTAssertEqual(lap.lapType, .active)
        XCTAssertEqual(lap.source, .distanceTap)
        XCTAssertEqual(lap.averageHeartRateBPM, 155)
    }

    func testLapCreationNoHeartRate() {
        let now = Date()
        let lap = Lap(
            index: 2,
            startedAt: now,
            endedAt: now.addingTimeInterval(60),
            durationSeconds: 60,
            distanceMeters: 200,
            averageSpeedMetersPerSecond: 3.33
        )
        XCTAssertNil(lap.averageHeartRateBPM)
        XCTAssertEqual(lap.lapType, .active)
        XCTAssertEqual(lap.source, .distanceTap)
    }

    func testLapTypeRawMapping() {
        let lap = Lap(
            index: 1,
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 10,
            distanceMeters: 0,
            averageSpeedMetersPerSecond: 0,
            lapType: .rest,
            source: .sessionEndSplit
        )
        XCTAssertEqual(lap.lapTypeRaw, "rest")
        XCTAssertEqual(lap.sourceRaw, "sessionEndSplit")
        lap.lapType = .active
        XCTAssertEqual(lap.lapTypeRaw, "active")
    }

    // MARK: - Session Initialization

    func testSessionCreation() {
        let start = Date()
        let end = start.addingTimeInterval(1200)
        let session = Session(
            startedAt: start,
            endedAt: end,
            durationSeconds: 1200,
            mode: .gps,
            totalDistanceMeters: 5000,
            averageSpeedMetersPerSecond: 4.17,
            totalLaps: 12,
            snapshotTrackingMode: .gps
        )
        XCTAssertEqual(session.mode, .gps)
        XCTAssertEqual(session.totalDistanceMeters, 5000)
        XCTAssertEqual(session.totalLaps, 12)
        XCTAssertEqual(session.snapshotTrackingMode, .gps)
        XCTAssertNil(session.sportVariantRaw)
        XCTAssertNil(session.distanceLapDistanceMeters)
        XCTAssertNil(session.healthKitWorkoutUUID)
    }

    func testSessionDistanceMode() {
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            averageSpeedMetersPerSecond: 3.33,
            totalLaps: 5,
            snapshotTrackingMode: .distanceDistance,
            snapshotDistanceDistanceMeters: 400
        )
        XCTAssertEqual(session.mode, .distanceDistance)
        XCTAssertEqual(session.distanceLapDistanceMeters, 400)
        XCTAssertEqual(session.snapshotDistanceDistanceMeters, 400)
    }

    func testSessionDualModeStoresSeparateGPSDistance() {
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .dual,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            totalGPSDistanceMeters: 2180,
            averageSpeedMetersPerSecond: 3.33,
            totalLaps: 5,
            snapshotTrackingMode: .dual,
            snapshotDistanceDistanceMeters: 400
        )

        XCTAssertEqual(session.mode, .dual)
        XCTAssertEqual(session.distanceLapDistanceMeters, 400)
        XCTAssertEqual(session.totalDistanceMeters, 2000)
        XCTAssertEqual(session.totalGPSDistanceMeters, 2180)
        XCTAssertEqual(session.snapshotTrackingMode, .dual)
    }

    func testSessionStoresWorkoutPlanSnapshot() {
        let snapshot = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [
                DistanceSegment(distanceMeters: 400, repeatCount: 4, restSeconds: 30),
                DistanceSegment(distanceMeters: 800, repeatCount: 2, restSeconds: 60)
            ],
            restMode: .autoDetect
        )
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            averageSpeedMetersPerSecond: 3.33,
            totalLaps: 5,
            snapshotTrackingMode: .distanceDistance,
            snapshotDistanceDistanceMeters: 400,
            snapshotWorkoutPlan: snapshot
        )

        XCTAssertEqual(session.snapshotWorkoutPlan, snapshot)
    }

    func testSessionWorkoutPlanFallbackForLegacySnapshot() {
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            averageSpeedMetersPerSecond: 3.33,
            totalLaps: 5,
            snapshotTrackingMode: .distanceDistance,
            snapshotDistanceDistanceMeters: 400
        )
        session.snapshotWorkoutPlanJSON = ""

        XCTAssertEqual(session.snapshotWorkoutPlan.trackingMode, .distanceDistance)
        XCTAssertEqual(session.snapshotWorkoutPlan.distanceLapDistanceMeters, 400)
        XCTAssertEqual(session.snapshotWorkoutPlan.distanceSegments.count, 1)
        XCTAssertEqual(session.snapshotWorkoutPlan.distanceSegments[0].distanceMeters, 400)
        XCTAssertEqual(session.snapshotWorkoutPlan.restMode, .manual)
    }

    func testOngoingWorkoutSnapshotRoundTrip() throws {
        let sessionID = UUID()
        let lap = Lap(
            index: 1,
            startedAt: Date(),
            endedAt: Date().addingTimeInterval(75),
            durationSeconds: 75,
            distanceMeters: 400,
            gpsDistanceMeters: 412,
            averageSpeedMetersPerSecond: 5.33,
            averageHeartRateBPM: 152,
            lapType: .active,
            source: .distanceTap
        )
        let snapshot = OngoingWorkoutSnapshot(
            sessionID: sessionID,
            savedAt: Date(),
            sessionStartDate: Date().addingTimeInterval(-180),
            currentLapStartDate: Date().addingTimeInterval(-20),
            elapsedSeconds: 180,
            lapElapsedSeconds: 20,
            trackingMode: .dual,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 45)],
            restMode: .manual,
            completedLaps: [OngoingWorkoutLapSnapshot(lap: lap)],
            cumulativeDistanceMeters: 400,
            currentLapDistanceMeters: 0,
            cumulativeGPSDistanceMeters: 412,
            currentLapGPSDistanceMeters: 0,
            currentHeartRate: 150,
            currentSegmentIndex: 0,
            currentSegmentRepeatsDone: 1,
            resumeRunState: .active,
            restElapsedSeconds: nil,
            restDurationSeconds: nil,
            pauseStartedAt: nil
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(OngoingWorkoutSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.sessionID, sessionID)
        XCTAssertEqual(decoded.completedLaps.first?.makeLap().gpsDistanceMeters, 412)
    }

    func testOngoingWorkoutSnapshotComputedProperties() {
        let savedAt = Date()
        let pauseStartedAt = savedAt.addingTimeInterval(-12)
        let activeLap = Lap(
            index: 1,
            startedAt: savedAt.addingTimeInterval(-90),
            endedAt: savedAt.addingTimeInterval(-30),
            durationSeconds: 60,
            distanceMeters: 400,
            gpsDistanceMeters: 415,
            averageSpeedMetersPerSecond: 6.67,
            averageHeartRateBPM: 155,
            lapType: .active,
            source: .distanceTap
        )
        let restLap = Lap(
            index: 0,
            startedAt: savedAt.addingTimeInterval(-30),
            endedAt: savedAt,
            durationSeconds: 30,
            distanceMeters: 0,
            averageSpeedMetersPerSecond: 0,
            lapType: .rest,
            source: .distanceTap
        )
        let snapshot = OngoingWorkoutSnapshot(
            sessionID: UUID(),
            savedAt: savedAt,
            sessionStartDate: savedAt.addingTimeInterval(-180),
            currentLapStartDate: savedAt.addingTimeInterval(-10),
            elapsedSeconds: 180,
            lapElapsedSeconds: 10,
            trackingMode: .dual,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 45)],
            restMode: .autoDetect,
            completedLaps: [OngoingWorkoutLapSnapshot(lap: activeLap), OngoingWorkoutLapSnapshot(lap: restLap)],
            cumulativeDistanceMeters: 400,
            currentLapDistanceMeters: 0,
            cumulativeGPSDistanceMeters: 415,
            currentLapGPSDistanceMeters: 0,
            currentHeartRate: 150,
            currentSegmentIndex: 0,
            currentSegmentRepeatsDone: 1,
            resumeRunState: .rest,
            restElapsedSeconds: 5,
            restDurationSeconds: 45,
            pauseStartedAt: pauseStartedAt
        )

        XCTAssertEqual(snapshot.activeLapCount, 1)
        XCTAssertEqual(snapshot.workoutPlan.trackingMode, .dual)
        XCTAssertEqual(snapshot.workoutPlan.distanceLapDistanceMeters, 400)
        XCTAssertEqual(snapshot.workoutPlan.distanceSegments.count, 1)
        XCTAssertEqual(snapshot.workoutPlan.restMode, .autoDetect)
        XCTAssertEqual(snapshot.effectivePauseStartedAt, pauseStartedAt)
    }

    func testSessionSyncRecordRoundTripPreservesIdentityAndPlan() {
        let session = Session(
            id: UUID(),
            startedAt: Date().addingTimeInterval(-600),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .dual,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            totalGPSDistanceMeters: 2080,
            averageSpeedMetersPerSecond: 3.33,
            totalLaps: 5,
            laps: [
                Lap(index: 1, startedAt: Date().addingTimeInterval(-600), endedAt: Date().addingTimeInterval(-510), durationSeconds: 90, distanceMeters: 400, gpsDistanceMeters: 412, averageSpeedMetersPerSecond: 4.44, averageHeartRateBPM: 155, lapType: .active, source: .distanceTap)
            ],
            deviceSource: "Apple Watch – Rundr v1.0",
            createdAt: Date().addingTimeInterval(-600),
            updatedAt: Date(),
            snapshotTrackingMode: .dual,
            snapshotDistanceDistanceMeters: 400,
            snapshotWorkoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 400,
                distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 5, restSeconds: 30)],
                restMode: .manual
            )
        )

        let record = SessionSyncRecord(session: session)
        let rebuilt = record.makeModel()

        XCTAssertEqual(rebuilt.id, session.id)
        XCTAssertEqual(rebuilt.totalGPSDistanceMeters, session.totalGPSDistanceMeters)
        XCTAssertEqual(rebuilt.snapshotWorkoutPlan, session.snapshotWorkoutPlan)
        XCTAssertEqual(rebuilt.laps.count, 1)
        XCTAssertEqual(rebuilt.laps.first?.id, session.laps.first?.id)
    }

    @MainActor
    func testPersistenceManagerUpsertSessionRecordInsertsAndReplacesNewerPayload() {
        let persistence = PersistenceManager(inMemory: true)
        let sessionID = UUID()
        let older = SessionSyncRecord(
            id: sessionID,
            startedAt: Date().addingTimeInterval(-600),
            endedAt: Date().addingTimeInterval(-300),
            durationSeconds: 300,
            mode: .gps,
            sportVariantRaw: nil,
            distanceLapDistanceMeters: nil,
            totalDistanceMeters: 1200,
            totalGPSDistanceMeters: 1200,
            averageSpeedMetersPerSecond: 4,
            totalLaps: 3,
            laps: [
                LapSyncRecord(lap: Lap(index: 1, startedAt: Date().addingTimeInterval(-600), endedAt: Date().addingTimeInterval(-500), durationSeconds: 100, distanceMeters: 400, gpsDistanceMeters: 400, averageSpeedMetersPerSecond: 4, averageHeartRateBPM: nil, lapType: .active, source: .autoDistance))
            ],
            deviceSource: "Apple Watch – Rundr v1.0",
            healthKitWorkoutUUID: nil,
            createdAt: Date().addingTimeInterval(-600),
            updatedAt: Date().addingTimeInterval(-200),
            snapshotWorkoutPlan: WorkoutPlanSnapshot(trackingMode: .gps)
        )
        let newer = SessionSyncRecord(
            id: sessionID,
            startedAt: older.startedAt,
            endedAt: Date(),
            durationSeconds: 600,
            mode: .dual,
            sportVariantRaw: nil,
            distanceLapDistanceMeters: 400,
            totalDistanceMeters: 2000,
            totalGPSDistanceMeters: 2080,
            averageSpeedMetersPerSecond: 3.5,
            totalLaps: 5,
            laps: [
                LapSyncRecord(lap: Lap(index: 1, startedAt: Date().addingTimeInterval(-600), endedAt: Date().addingTimeInterval(-510), durationSeconds: 90, distanceMeters: 400, gpsDistanceMeters: 412, averageSpeedMetersPerSecond: 4.44, averageHeartRateBPM: 155, lapType: .active, source: .distanceTap)),
                LapSyncRecord(lap: Lap(index: 2, startedAt: Date().addingTimeInterval(-500), endedAt: Date().addingTimeInterval(-410), durationSeconds: 90, distanceMeters: 400, gpsDistanceMeters: 416, averageSpeedMetersPerSecond: 4.44, averageHeartRateBPM: 156, lapType: .active, source: .distanceTap))
            ],
            deviceSource: "Apple Watch – Rundr v1.0",
            healthKitWorkoutUUID: nil,
            createdAt: older.createdAt,
            updatedAt: Date(),
            snapshotWorkoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 400,
                distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 5, restSeconds: 30)],
                restMode: .manual
            )
        )

        persistence.upsertSessionRecord(older)
        persistence.upsertSessionRecord(newer)

        let storedSession = persistence.fetchSession(id: sessionID)
        XCTAssertNotNil(storedSession)
        XCTAssertEqual(storedSession?.mode, .dual)
        XCTAssertEqual(storedSession?.totalLaps, 5)
        XCTAssertEqual(storedSession?.laps.count, 2)
        XCTAssertEqual(storedSession?.totalGPSDistanceMeters, 2080)
    }

    func testCompletedSessionTransferStoreTracksPendingSessionIDs() {
        let suiteName = "CompletedSessionTransferStoreTests-\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = CompletedSessionTransferStore(
            userDefaults: userDefaults,
            manifestKey: "pendingTransfers"
        )
        let firstID = UUID()
        let secondID = UUID()

        store.markPending(firstID)
        store.markPending(secondID)
        store.markPending(firstID)

        XCTAssertEqual(store.pendingSessionIDs, [firstID, secondID])

        store.clearPending(firstID)

        XCTAssertEqual(store.pendingSessionIDs, [secondID])
    }

    func testCompletedSessionAcknowledgementStoreKeepsRecentUniqueSessionIDs() {
        let suiteName = "CompletedSessionAcknowledgementStoreTests-\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = CompletedSessionAcknowledgementStore(
            userDefaults: userDefaults,
            manifestKey: "completedAcknowledgements",
            maxStoredSessionCount: 2
        )
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()

        store.markAcknowledged(firstID)
        store.markAcknowledged(secondID)
        store.markAcknowledged(firstID)
        store.markAcknowledged(thirdID)

        XCTAssertEqual(store.acknowledgedSessionIDs, [firstID, thirdID])
    }

    func testSessionModeRawMapping() {
        let session = Session(
            startedAt: Date(),
            endedAt: Date(),
            durationSeconds: 0,
            mode: .gps,
            totalDistanceMeters: 0,
            averageSpeedMetersPerSecond: 0,
            totalLaps: 0,
            snapshotTrackingMode: .gps
        )
        XCTAssertEqual(session.modeRaw, "gps")
        session.mode = .distanceDistance
        XCTAssertEqual(session.modeRaw, "distanceDistance")
        session.mode = .dual
        XCTAssertEqual(session.modeRaw, "dual")
    }

    func testSessionLapTargetResolverAssignsSegmentsAcrossRepeatsAndRestLaps() {
        let segmentA = DistanceSegment(distanceMeters: 400, repeatCount: 2, targetTimeSeconds: 90)
        let segmentB = DistanceSegment(distanceMeters: 800, repeatCount: 1, targetPaceSecondsPerKm: 240)
        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .dual,
            distanceLapDistanceMeters: 400,
            distanceSegments: [segmentA, segmentB],
            restMode: .manual
        )
        let laps = [
            Lap(index: 1, startedAt: Date(), endedAt: Date(), durationSeconds: 90, distanceMeters: 400, averageSpeedMetersPerSecond: 4, lapType: .active),
            Lap(index: 0, startedAt: Date(), endedAt: Date(), durationSeconds: 30, distanceMeters: 0, averageSpeedMetersPerSecond: 0, lapType: .rest),
            Lap(index: 2, startedAt: Date(), endedAt: Date(), durationSeconds: 91, distanceMeters: 400, averageSpeedMetersPerSecond: 4, lapType: .active),
            Lap(index: 3, startedAt: Date(), endedAt: Date(), durationSeconds: 192, distanceMeters: 800, averageSpeedMetersPerSecond: 4.16, lapType: .active)
        ]

        let targets = SessionLapTargetResolver.targetSegments(for: laps, workoutPlan: workoutPlan, trackingMode: .dual)

        XCTAssertEqual(targets[laps[0].id]?.targetTimeSeconds, 90)
        XCTAssertNil(targets[laps[1].id])
        XCTAssertEqual(targets[laps[2].id]?.targetTimeSeconds, 90)
        XCTAssertEqual(targets[laps[3].id]?.targetPaceSecondsPerKm, 240)
    }

    // MARK: - DistanceSegment

    func testDistanceSegmentDefaults() {
        let segment = DistanceSegment()
        XCTAssertEqual(segment.distanceMeters, 400)
        XCTAssertEqual(segment.distanceGoalMode, .fixed)
        XCTAssertNil(segment.repeatCount)
        XCTAssertNil(segment.restSeconds)
    }

    func testDistanceSegmentWithRepeatCount() {
        let segment = DistanceSegment(distanceMeters: 800, repeatCount: 3)
        XCTAssertEqual(segment.distanceMeters, 800)
        XCTAssertEqual(segment.repeatCount, 3)
    }

    func testDistanceSegmentUnlimited() {
        let segment = DistanceSegment(distanceMeters: 400, repeatCount: nil)
        XCTAssertNil(segment.repeatCount)
    }

    func testDistanceSegmentCodable() throws {
        let segments: [DistanceSegment] = [
            DistanceSegment(distanceMeters: 400, repeatCount: 5),
            DistanceSegment(distanceMeters: 800, repeatCount: nil),
            DistanceSegment(distanceMeters: 200, repeatCount: 10)
        ]
        let data = try JSONEncoder().encode(segments)
        let decoded = try JSONDecoder().decode([DistanceSegment].self, from: data)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].distanceMeters, 400)
        XCTAssertEqual(decoded[0].repeatCount, 5)
        XCTAssertEqual(decoded[1].distanceMeters, 800)
        XCTAssertNil(decoded[1].repeatCount)
        XCTAssertEqual(decoded[2].distanceMeters, 200)
        XCTAssertEqual(decoded[2].repeatCount, 10)
    }

    func testDistanceSegmentEquality() {
        let id = UUID()
        let a = DistanceSegment(id: id, distanceMeters: 400, repeatCount: 3)
        let b = DistanceSegment(id: id, distanceMeters: 400, repeatCount: 3)
        XCTAssertEqual(a, b)
    }

    func testDistanceSegmentHashableUsesFullSegmentIdentity() {
        let id = UUID()
        let a = DistanceSegment(id: id, distanceMeters: 400, repeatCount: 3, restSeconds: 30)
        let b = DistanceSegment(id: id, distanceMeters: 400, repeatCount: 3, restSeconds: 30)
        let c = DistanceSegment(id: id, distanceMeters: 800, repeatCount: 3, restSeconds: 30)

        XCTAssertEqual(Set([a, b]).count, 1)
        XCTAssertEqual(Set([a, c]).count, 2)
    }

    func testDistanceSegmentWithRestSeconds() {
        let segment = DistanceSegment(distanceMeters: 400, repeatCount: 5, restSeconds: 30)
        XCTAssertEqual(segment.restSeconds, 30)
    }

    func testDistanceSegmentManualRest() {
        let segment = DistanceSegment(distanceMeters: 400, repeatCount: 3, restSeconds: nil)
        XCTAssertNil(segment.restSeconds)
    }

    func testDistanceSegmentCodableWithRest() throws {
        let segments: [DistanceSegment] = [
            DistanceSegment(distanceMeters: 400, repeatCount: 5, restSeconds: 30),
            DistanceSegment(distanceMeters: 800, repeatCount: nil, restSeconds: nil),
        ]
        let data = try JSONEncoder().encode(segments)
        let decoded = try JSONDecoder().decode([DistanceSegment].self, from: data)
        XCTAssertEqual(decoded[0].restSeconds, 30)
        XCTAssertNil(decoded[1].restSeconds)
    }

    func testDistanceSegmentDecodesLegacyPayloadWithoutDistanceMode() throws {
        let data = """
        [{"id":"00000000-0000-0000-0000-000000000001","distanceMeters":400,"repeatCount":4}]
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([DistanceSegment].self, from: data)
        XCTAssertEqual(decoded[0].distanceGoalMode, .fixed)
        XCTAssertFalse(decoded[0].usesOpenDistance)
    }

    func testOpenDistanceSegmentDisablesPaceDerivedTargetTime() {
        let segment = DistanceSegment(
            distanceMeters: 400,
            distanceGoalMode: .open,
            targetPaceSecondsPerKm: 300
        )
        XCTAssertNil(segment.effectiveTargetTimeSeconds)
    }

    func testDistanceSegmentDefault() {
        let d = DistanceSegment.default
        XCTAssertEqual(d.distanceMeters, 400)
        XCTAssertNil(d.repeatCount)
    }

    func testIntervalPresetNormalizesOpenEndedIntermediateSegments() {
        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [
                DistanceSegment(distanceMeters: 400, repeatCount: nil, restSeconds: 30),
                DistanceSegment(distanceMeters: 800, repeatCount: nil, restSeconds: 60)
            ],
            restMode: .autoDetect
        )

        let normalized = IntervalPreset.normalizedWorkoutPlan(workoutPlan)

        XCTAssertEqual(normalized.distanceSegments[0].repeatCount, 1)
        XCTAssertNil(normalized.distanceSegments[1].repeatCount)
        XCTAssertEqual(normalized.distanceLapDistanceMeters, 400)
        XCTAssertEqual(normalized.restMode, .manual)
    }

    // MARK: - Interval Presets

    func testSettingsStoreStoresUniqueSessionPresetsOnly() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 300,
            distanceSegments: [DistanceSegment(distanceMeters: 300, repeatCount: 10, restSeconds: 30)],
            restMode: .manual
        )

        store.storeSessionIntervalPresetIfUnique(workoutPlan)
        store.storeSessionIntervalPresetIfUnique(workoutPlan)

        XCTAssertEqual(store.intervalPresets.count, 1)
        XCTAssertEqual(store.intervalPresets.first?.workoutPlan, workoutPlan)
    }

    func testSettingsStoreApplyUpgradesGPSOnlyToDualWhenLoadingManualIntervals() {
        UserDefaults.standard.removeObject(forKey: "trackingMode")
        UserDefaults.standard.removeObject(forKey: "distanceDistanceMeters")
        UserDefaults.standard.removeObject(forKey: "distanceSegmentsJSON")
        UserDefaults.standard.removeObject(forKey: "restMode")
        UserDefaults.standard.removeObject(forKey: "pauseMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "trackingMode")
            UserDefaults.standard.removeObject(forKey: "distanceDistanceMeters")
            UserDefaults.standard.removeObject(forKey: "distanceSegmentsJSON")
            UserDefaults.standard.removeObject(forKey: "restMode")
            UserDefaults.standard.removeObject(forKey: "pauseMode")
        }

        let store = SettingsStore()
        store.trackingMode = .gps

        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 300,
            distanceSegments: [DistanceSegment(distanceMeters: 300, repeatCount: 8, restSeconds: 30)],
            restMode: .autoDetect
        )

        store.apply(workoutPlan: workoutPlan)

        XCTAssertEqual(store.trackingMode, .dual)
        XCTAssertEqual(store.distanceDistanceMeters, 300)
        XCTAssertEqual(store.distanceSegments, workoutPlan.distanceSegments)
        XCTAssertEqual(store.restMode, .autoDetect)
    }

    func testSettingsStoreApplyUpgradesGPSOnlyToDualForOpenIntervals() {
        UserDefaults.standard.removeObject(forKey: "trackingMode")
        UserDefaults.standard.removeObject(forKey: "distanceDistanceMeters")
        UserDefaults.standard.removeObject(forKey: "distanceSegmentsJSON")
        UserDefaults.standard.removeObject(forKey: "restMode")
        UserDefaults.standard.removeObject(forKey: "pauseMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "trackingMode")
            UserDefaults.standard.removeObject(forKey: "distanceDistanceMeters")
            UserDefaults.standard.removeObject(forKey: "distanceSegmentsJSON")
            UserDefaults.standard.removeObject(forKey: "restMode")
            UserDefaults.standard.removeObject(forKey: "pauseMode")
        }

        let store = SettingsStore()
        store.trackingMode = .gps

        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 500,
            distanceSegments: [DistanceSegment(distanceMeters: 500, repeatCount: 6, restSeconds: 45, distanceGoalMode: .open)],
            restMode: .autoDetect
        )

        store.apply(workoutPlan: workoutPlan)

        XCTAssertEqual(store.trackingMode, .dual)
        XCTAssertEqual(store.distanceDistanceMeters, 500)
        XCTAssertEqual(store.distanceSegments, workoutPlan.distanceSegments)
        XCTAssertEqual(store.restMode, .autoDetect)
    }

    func testSettingsStoreDoesNotStorePredefinedSessionPreset() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let workoutPlan = SettingsStore.predefinedIntervalPresets[0].workoutPlan

        store.storeSessionIntervalPresetIfUnique(workoutPlan)

        XCTAssertTrue(store.intervalPresets.isEmpty)
    }

    func testSettingsStoreAssignsGeneratedTitleWhenSavingPresetWithoutCustomTitle() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
            restMode: .manual
        )

        let preset = store.saveIntervalPreset(workoutPlan)

        XCTAssertEqual(preset?.trimmedCustomTitle, "6 × 400 m")
        XCTAssertEqual(store.intervalPresets.first?.trimmedCustomTitle, "6 × 400 m")
    }

    func testSettingsStoreReturnsPresetsSortedByMostRecentlyEdited() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let firstPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 4, restSeconds: 45)],
            restMode: .manual
        )
        let secondPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 1000,
            distanceSegments: [DistanceSegment(distanceMeters: 1000, repeatCount: 3, restSeconds: 90)],
            restMode: .manual
        )

        let firstPreset = store.saveIntervalPreset(firstPlan, customTitle: "400s")
        let secondPreset = store.saveIntervalPreset(secondPlan, customTitle: "Ks")
        _ = store.saveIntervalPreset(firstPlan, customTitle: "400s updated", existingPresetID: firstPreset?.id)

        XCTAssertEqual(store.intervalPresets.count, 2)
        XCTAssertEqual(store.intervalPresets.first?.id, firstPreset?.id)
        XCTAssertEqual(store.intervalPresets.first?.trimmedCustomTitle, "400s updated")
        XCTAssertEqual(store.intervalPresets.last?.id, secondPreset?.id)
    }

    func testSettingsStoreUpdatesExistingPresetWithoutDuplicating() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let originalPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
            restMode: .manual
        )
        let updatedPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 500,
            distanceSegments: [DistanceSegment(distanceMeters: 500, repeatCount: 5, restSeconds: 75)],
            restMode: .autoDetect
        )

        let preset = store.saveIntervalPreset(originalPlan, customTitle: "Track")
        let updatedPreset = store.saveIntervalPreset(updatedPlan, customTitle: "Tempo", existingPresetID: preset?.id)

        XCTAssertEqual(store.intervalPresets.count, 1)
        XCTAssertEqual(updatedPreset?.workoutPlan.trackingMode, updatedPlan.trackingMode)
        XCTAssertEqual(updatedPreset?.workoutPlan.distanceLapDistanceMeters, updatedPlan.distanceLapDistanceMeters)
        XCTAssertEqual(updatedPreset?.workoutPlan.distanceSegments, updatedPlan.distanceSegments)
        XCTAssertEqual(updatedPreset?.trimmedCustomTitle, "Tempo")
    }

    func testSettingsStoreTitleUsesPredefinedPresetTitleWhenMatched() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let workoutPlan = SettingsStore.predefinedIntervalPresets[0].workoutPlan

        XCTAssertEqual(store.title(for: workoutPlan), "6 × 400 m")
    }

    func testSettingsStoreTitleUsesSavedPresetTitleWhenMatched() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 300,
            distanceSegments: [DistanceSegment(distanceMeters: 300, repeatCount: 10, restSeconds: 30)],
            restMode: .manual
        )

        _ = store.saveIntervalPreset(workoutPlan, customTitle: "Track Tens")

        XCTAssertEqual(store.title(for: workoutPlan), "Track Tens")
    }

    func testWorkoutPlanSupportUpgradesOpenIntervalsToDual() {
        let workoutPlan = WorkoutPlanSupport.makeWorkoutPlan(
            requestedTrackingMode: .distanceDistance,
            segments: [DistanceSegment(distanceMeters: 400, distanceGoalMode: .open)],
            restMode: .manual
        )

        XCTAssertEqual(workoutPlan.trackingMode, .dual)
    }

    func testWorkoutPlanSupportNextSegmentForAppendCopiesLastSegment() {
        let first = DistanceSegment(distanceMeters: 200, repeatCount: 2, restSeconds: 20)
        let last = DistanceSegment(
            distanceMeters: 800,
            repeatCount: 4,
            restSeconds: 45,
            lastRestSeconds: 90,
            distanceGoalMode: .open,
            targetPaceSecondsPerKm: 315,
            targetTimeSeconds: 240
        )

        let next = WorkoutPlanSupport.nextSegmentForAppend(from: [first, last])

        XCTAssertEqual(next.distanceMeters, last.distanceMeters)
        XCTAssertEqual(next.repeatCount, last.repeatCount)
        XCTAssertEqual(next.restSeconds, last.restSeconds)
        XCTAssertEqual(next.lastRestSeconds, last.lastRestSeconds)
        XCTAssertEqual(next.distanceGoalMode, last.distanceGoalMode)
        XCTAssertEqual(next.targetPaceSecondsPerKm, last.targetPaceSecondsPerKm)
        XCTAssertEqual(next.targetTimeSeconds, last.targetTimeSeconds)
        XCTAssertNotEqual(next.id, last.id)
    }

    func testWorkoutPlanSupportNextSegmentForAppendUsesDefaultWhenSegmentsEmpty() {
        let next = WorkoutPlanSupport.nextSegmentForAppend(from: [])

        XCTAssertEqual(next.distanceMeters, DistanceSegment.default.distanceMeters)
        XCTAssertEqual(next.repeatCount, DistanceSegment.default.repeatCount)
        XCTAssertEqual(next.restSeconds, DistanceSegment.default.restSeconds)
        XCTAssertEqual(next.lastRestSeconds, DistanceSegment.default.lastRestSeconds)
        XCTAssertEqual(next.distanceGoalMode, DistanceSegment.default.distanceGoalMode)
        XCTAssertEqual(next.targetPaceSecondsPerKm, DistanceSegment.default.targetPaceSecondsPerKm)
        XCTAssertEqual(next.targetTimeSeconds, DistanceSegment.default.targetTimeSeconds)
    }

    func testSettingsStoreApplySettingsSyncRecordUpdatesEditableCompanionState() {
        let keys = [
            "trackingMode",
            "distanceDistanceMeters",
            "distanceSegmentsJSON",
            "intervalPresetsJSON",
            "primaryColor",
            "restMode",
            "pauseMode",
            "appearanceMode",
            "distanceUnit",
            "lapAlerts",
            "restAlerts"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        defer { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }

        let store = SettingsStore()
        let presetPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 300,
            distanceSegments: [DistanceSegment(distanceMeters: 300, repeatCount: 8, restSeconds: 30)],
            restMode: .manual
        )
        let record = SettingsSyncRecord(
            trackingMode: .dual,
            distanceDistanceMeters: 300,
            distanceUnit: .miles,
            primaryColor: .pink,
            restMode: .autoDetect,
            lapAlerts: false,
            restAlerts: true,
            appearanceMode: .light,
            distanceSegments: presetPlan.distanceSegments,
            intervalPresets: [IntervalPreset(customTitle: "Track", workoutPlan: presetPlan)],
            updatedAt: Date(),
            deviceSource: "iphone"
        )

        store.apply(settingsSyncRecord: record)

        XCTAssertEqual(store.trackingMode, .dual)
        XCTAssertEqual(store.distanceDistanceMeters, 300)
        XCTAssertEqual(store.distanceUnit, .miles)
        XCTAssertEqual(store.primaryColor, .pink)
        XCTAssertEqual(store.restMode, .autoDetect)
        XCTAssertFalse(store.lapAlerts)
        XCTAssertTrue(store.restAlerts)
        XCTAssertEqual(store.appearanceMode, .light)
        XCTAssertEqual(store.distanceSegments, presetPlan.distanceSegments)
        XCTAssertEqual(store.intervalPresets.first?.trimmedCustomTitle, "Track")
    }

    func testSettingsStoreSaveIntervalPresetIgnoresGPSPlan() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: .gps,
            distanceSegments: [.default],
            restMode: .manual
        )

        let preset = store.saveIntervalPreset(workoutPlan, customTitle: "Outdoor Run")

        XCTAssertNil(preset)
        XCTAssertTrue(store.intervalPresets.isEmpty)
    }

    func testSettingsStoreMergesEditedPresetIntoExistingDuplicate() {
        UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "intervalPresetsJSON") }

        let store = SettingsStore()
        let firstPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
            restMode: .manual
        )
        let secondPlan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 1000,
            distanceSegments: [DistanceSegment(distanceMeters: 1000, repeatCount: 3, restSeconds: 120)],
            restMode: .manual
        )

        let firstPreset = store.saveIntervalPreset(firstPlan, customTitle: "400s")
        let secondPreset = store.saveIntervalPreset(secondPlan, customTitle: "Ks")
        let mergedPreset = store.saveIntervalPreset(secondPlan, customTitle: "Ks Updated", existingPresetID: firstPreset?.id)

        XCTAssertEqual(store.intervalPresets.count, 1)
        XCTAssertEqual(mergedPreset?.id, secondPreset?.id)
        XCTAssertEqual(store.intervalPresets.first?.id, secondPreset?.id)
        XCTAssertEqual(store.intervalPresets.first?.trimmedCustomTitle, "Ks Updated")
    }

    @MainActor
    func testOngoingWorkoutStoreLoadsStartupSnapshotFromStorage() throws {
        UserDefaults.standard.removeObject(forKey: "ongoingWorkoutSnapshotJSON")
        defer { UserDefaults.standard.removeObject(forKey: "ongoingWorkoutSnapshotJSON") }

        let snapshot = OngoingWorkoutSnapshot(
            sessionID: UUID(),
            savedAt: Date(),
            sessionStartDate: Date().addingTimeInterval(-180),
            currentLapStartDate: Date().addingTimeInterval(-20),
            elapsedSeconds: 180,
            lapElapsedSeconds: 20,
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 45)],
            restMode: .manual,
            completedLaps: [],
            cumulativeDistanceMeters: 0,
            currentLapDistanceMeters: 0,
            cumulativeGPSDistanceMeters: 0,
            currentLapGPSDistanceMeters: 0,
            currentHeartRate: nil,
            currentSegmentIndex: 0,
            currentSegmentRepeatsDone: 0,
            resumeRunState: .active,
            restElapsedSeconds: nil,
            restDurationSeconds: nil,
            pauseStartedAt: nil
        )
        let data = try JSONEncoder().encode(snapshot)
        UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: "ongoingWorkoutSnapshotJSON")

        let store = OngoingWorkoutStore()

        XCTAssertEqual(store.snapshot, snapshot)
        XCTAssertEqual(store.startupSnapshot, snapshot)
    }

    @MainActor
    func testOngoingWorkoutStoreClearsInvalidSnapshotDataWhenLoading() {
        UserDefaults.standard.set("not-json", forKey: "ongoingWorkoutSnapshotJSON")
        defer { UserDefaults.standard.removeObject(forKey: "ongoingWorkoutSnapshotJSON") }

        let store = OngoingWorkoutStore()

        XCTAssertNil(store.snapshot)
        XCTAssertNil(store.startupSnapshot)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "ongoingWorkoutSnapshotJSON"), "")
    }

    // MARK: - Preset Usage Tracking

    func testRecordPresetUsageIncrementsCount() {
        UserDefaults.standard.removeObject(forKey: "presetUsageCountsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "presetUsageCountsJSON") }

        let store = SettingsStore()
        let plan = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
            restMode: .manual
        )

        XCTAssertEqual(store.presetUsageCount(for: plan), 0)

        store.recordPresetUsage(for: plan)
        XCTAssertEqual(store.presetUsageCount(for: plan), 1)

        store.recordPresetUsage(for: plan)
        XCTAssertEqual(store.presetUsageCount(for: plan), 2)
    }

    func testRecordPresetUsageIgnoresGPSPlan() {
        UserDefaults.standard.removeObject(forKey: "presetUsageCountsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "presetUsageCountsJSON") }

        let store = SettingsStore()
        let gpsPlan = WorkoutPlanSnapshot(
            trackingMode: .gps,
            distanceLapDistanceMeters: nil,
            distanceSegments: [.default],
            restMode: .manual
        )

        store.recordPresetUsage(for: gpsPlan)
        XCTAssertEqual(store.presetUsageCount(for: gpsPlan), 0)
    }

    func testPresetUsageCountDistinguishesDifferentPlans() {
        UserDefaults.standard.removeObject(forKey: "presetUsageCountsJSON")
        defer { UserDefaults.standard.removeObject(forKey: "presetUsageCountsJSON") }

        let store = SettingsStore()
        let planA = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 400,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
            restMode: .manual
        )
        let planB = WorkoutPlanSnapshot(
            trackingMode: .distanceDistance,
            distanceLapDistanceMeters: 200,
            distanceSegments: [DistanceSegment(distanceMeters: 200, repeatCount: 8, restSeconds: 45)],
            restMode: .manual
        )

        store.recordPresetUsage(for: planA)
        store.recordPresetUsage(for: planA)
        store.recordPresetUsage(for: planB)

        XCTAssertEqual(store.presetUsageCount(for: planA), 2)
        XCTAssertEqual(store.presetUsageCount(for: planB), 1)
    }
}
