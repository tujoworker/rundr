import Foundation
import SwiftUI

struct IntervalPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var customTitle: String?
    var customDescription: String?
    var workoutPlan: WorkoutPlanSnapshot
    var createdAt: Date
    var updatedAt: Date
    var lastSharedAt: Date?
    var lastImportedAt: Date?
    var myRating: Double?
    var communityRating: Double?

    init(
        id: UUID = UUID(),
        customTitle: String? = nil,
        customDescription: String? = nil,
        workoutPlan: WorkoutPlanSnapshot,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastSharedAt: Date? = nil,
        lastImportedAt: Date? = nil,
        myRating: Double? = nil,
        communityRating: Double? = nil
    ) {
        let normalizedWorkoutPlan = IntervalPreset.normalizedWorkoutPlan(workoutPlan)
        self.id = id
        self.customTitle = IntervalPreset.storedTitle(for: normalizedWorkoutPlan, preferredTitle: customTitle)
        self.customDescription = IntervalPreset.sanitizeDescription(customDescription)
        self.workoutPlan = normalizedWorkoutPlan
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSharedAt = lastSharedAt
        self.lastImportedAt = lastImportedAt
        self.myRating = myRating
        self.communityRating = communityRating
    }

    var trimmedCustomTitle: String? {
        IntervalPreset.sanitizeTitle(customTitle)
    }

    var trimmedCustomDescription: String? {
        IntervalPreset.sanitizeDescription(customDescription)
    }

    var signature: IntervalPresetSignature {
        IntervalPresetSignature(workoutPlan: workoutPlan)
    }

    static func normalizedWorkoutPlan(_ workoutPlan: WorkoutPlanSnapshot) -> WorkoutPlanSnapshot {
        let normalizedSegments = WorkoutPlanSupport.normalizedSegments(workoutPlan.distanceSegments)
        return WorkoutPlanSnapshot(
            trackingMode: WorkoutPlanSupport.resolvedTrackingMode(
                requestedTrackingMode: workoutPlan.trackingMode,
                segments: normalizedSegments
            ),
            distanceLapDistanceMeters: normalizedSegments.first?.distanceMeters ?? workoutPlan.distanceLapDistanceMeters,
            distanceSegments: normalizedSegments,
            restMode: .manual,
            originPlanID: workoutPlan.originPlanID
        )
    }

    static func sanitizeTitle(_ title: String?) -> String? {
        guard let title else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func sanitizeDescription(_ description: String?) -> String? {
        guard let description else { return nil }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func storedTitle(for workoutPlan: WorkoutPlanSnapshot, preferredTitle: String?) -> String {
        sanitizeTitle(preferredTitle) ?? generatedTitle(for: workoutPlan)
    }

    static func generatedTitle(for workoutPlan: WorkoutPlanSnapshot) -> String {
        let normalizedWorkoutPlan = normalizedWorkoutPlan(workoutPlan)
        let segments = normalizedWorkoutPlan.distanceSegments
        guard let firstSegment = segments.first else { return L10n.noSessionPlanIntervalsTitle }
        let segmentLabel = generatedSegmentTitle(firstSegment)

        if segments.count == 1, let repeatCount = firstSegment.repeatCount {
            return L10n.repeatSummary(repeatCount, segmentLabel)
        }
        if segments.count == 1 {
            return segmentLabel
        }
        return L10n.segmentCount(segments.count)
    }

    private static func generatedSegmentTitle(_ segment: DistanceSegment) -> String {
        let primaryValue: String
        if segment.usesOpenDistance {
            primaryValue = segment.effectiveTargetTimeSeconds.map { Formatters.compactTimeString(from: $0) } ?? L10n.time
        } else if segment.distanceMeters >= 1000,
                    segment.distanceMeters.truncatingRemainder(dividingBy: 1000) == 0 {
            let kilometers = Int(segment.distanceMeters / 1000)
            primaryValue = "\(kilometers) km"
        } else {
            primaryValue = "\(Int(segment.distanceMeters)) m"
        }

        if let trimmedName = segment.trimmedName {
            return L10n.segmentSummary(trimmedName, primaryValue)
        }

        return primaryValue
    }
}

struct PredefinedIntervalPreset: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let workoutPlan: WorkoutPlanSnapshot

    var signature: IntervalPresetSignature {
        IntervalPresetSignature(workoutPlan: workoutPlan)
    }
}

struct IntervalPresetSignature: Codable, Equatable {
    let trackingMode: TrackingMode
    let distanceLapDistanceMeters: Double?
    let distanceSegments: [IntervalPresetSegmentSignature]

    init(workoutPlan: WorkoutPlanSnapshot) {
        let normalized = IntervalPreset.normalizedWorkoutPlan(workoutPlan)
        trackingMode = normalized.trackingMode
        distanceLapDistanceMeters = normalized.distanceLapDistanceMeters
        distanceSegments = normalized.distanceSegments.map(IntervalPresetSegmentSignature.init(segment:))
    }
}

struct IntervalPresetSegmentSignature: Codable, Equatable {
    let name: String?
    let distanceMeters: Double
    let distanceGoalMode: DistanceGoalMode
    let repeatCount: Int?
    let restSeconds: Int?
    let lastRestSeconds: Int?
    let targetPaceSecondsPerKm: Double?
    let targetTimeSeconds: Double?

    init(segment: DistanceSegment) {
        name = segment.trimmedName
        distanceMeters = segment.distanceMeters
        distanceGoalMode = segment.distanceGoalMode
        repeatCount = segment.repeatCount
        restSeconds = segment.restSeconds
        lastRestSeconds = segment.lastRestSeconds
        targetPaceSecondsPerKm = segment.targetPaceSecondsPerKm
        targetTimeSeconds = segment.targetTimeSeconds
    }
}

enum CompanionPresetBadgeResolver {
    static func badgeCount(usageCount: Int) -> Int? {
        usageCount > 0 ? usageCount : nil
    }
}

enum SettingsSyncApplicationContext {
    case iPhoneCompanion
    case watchApp

    static var current: SettingsSyncApplicationContext {
        #if os(iOS)
        .iPhoneCompanion
        #else
        .watchApp
        #endif
    }
}

enum SettingsSyncAppearancePolicy {
    static func resolvedLocalSyncAppearanceMode(
        currentValue: Bool,
        incomingValue: Bool,
        context: SettingsSyncApplicationContext
    ) -> Bool {
        switch context {
        case .iPhoneCompanion:
            currentValue
        case .watchApp:
            incomingValue
        }
    }

    static func shouldApplyIncomingAppearance(
        localSyncAppearanceMode: Bool,
        incomingSyncAppearanceMode: Bool,
        context: SettingsSyncApplicationContext
    ) -> Bool {
        switch context {
        case .iPhoneCompanion:
            localSyncAppearanceMode && incomingSyncAppearanceMode
        case .watchApp:
            incomingSyncAppearanceMode
        }
    }
}

final class SettingsStore: ObservableObject {
    private static let defaultDistanceSegmentID = UUID(uuidString: "7FA5A34F-E9E7-45E7-A60A-C071132B6B52")!

    @AppStorage("trackingMode") private var trackingModeRaw: String = TrackingMode.distanceDistance.rawValue
    @AppStorage("distanceDistanceMeters") private var distanceDistanceMetersValue: Double = 400
    @AppStorage("distanceUnit") var distanceUnit: DistanceUnit = .km
    @AppStorage("primaryColor") private var primaryColorRaw: String = "blue"
    @AppStorage("restMode") private var restModeRaw: String = RestMode.manual.rawValue
    // Preserve the user's existing saved setting while migrating from the old name.
    @AppStorage("pauseMode") private var legacyRestModeRaw: String = RestMode.manual.rawValue
    @AppStorage("lapAlerts") var lapAlerts: Bool = true
    @AppStorage("restAlerts") var restAlerts: Bool = true
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @AppStorage("syncAppearanceMode") var syncAppearanceMode: Bool = true
    @AppStorage("currentWorkoutPlanCreatedAt") private var currentWorkoutPlanCreatedAtInterval: Double = 0
    @AppStorage("currentWorkoutPlanUpdatedAt") private var currentWorkoutPlanUpdatedAtInterval: Double = 0

    init() {
        ensureCurrentWorkoutPlanTimestamps()
    }

    var trackingMode: TrackingMode {
        get {
            let storedMode = TrackingMode(rawValue: trackingModeRaw) ?? .distanceDistance
            return storedMode == .gps ? .distanceDistance : storedMode
        }
        set {
            guard newValue != trackingMode else { return }
            trackingModeRaw = newValue.rawValue
            touchCurrentWorkoutPlan()
        }
    }

    var distanceDistanceMeters: Double {
        get { distanceDistanceMetersValue }
        set {
            guard newValue != distanceDistanceMetersValue else { return }
            distanceDistanceMetersValue = newValue
            touchCurrentWorkoutPlan()
        }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

    var currentWorkoutPlanCreatedAt: Date {
        ensureCurrentWorkoutPlanTimestamps()
        return Date(timeIntervalSince1970: currentWorkoutPlanCreatedAtInterval)
    }

    var currentWorkoutPlanUpdatedAt: Date {
        ensureCurrentWorkoutPlanTimestamps()
        return Date(timeIntervalSince1970: currentWorkoutPlanUpdatedAtInterval)
    }

    var primaryColor: PrimaryColorOption {
        get { PrimaryColorOption(rawValue: primaryColorRaw) ?? .blue }
        set { primaryColorRaw = newValue.rawValue }
    }
    var restMode: RestMode {
        get {
            if let mode = RestMode(rawValue: restModeRaw) {
                return mode
            }
            if let legacyMode = RestMode(rawValue: legacyRestModeRaw) {
                restModeRaw = legacyMode.rawValue
                return legacyMode
            }
            return .manual
        }
        set {
            guard newValue != restMode else { return }
            restModeRaw = newValue.rawValue
            legacyRestModeRaw = newValue.rawValue
            touchCurrentWorkoutPlan()
        }
    }

    var primaryAccentColor: Color {
        primaryColor.color
    }

    // MARK: - Distance Segments

    @AppStorage("distanceSegmentsJSON") private var distanceSegmentsJSON: String = ""
    @AppStorage("intervalPresetsJSON") private var intervalPresetsJSON: String = ""
    @AppStorage("presetUsageCountsJSON") private var presetUsageCountsJSON: String = ""
    @AppStorage("workoutPlanOriginID") private var workoutPlanOriginIDRaw: String = ""


    static let predefinedIntervalPresets: [PredefinedIntervalPreset] = [
        PredefinedIntervalPreset(
            id: "fourByFour",
            title: L10n.predefinedFourByFourTitle,
            description: L10n.predefinedFourByFourDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 0,
                distanceSegments: [
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 240),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 240),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 240),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 240)
                ],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "thresholdSixes",
            title: L10n.predefinedThresholdSixesTitle,
            description: L10n.predefinedThresholdSixesDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 0,
                distanceSegments: [
                    DistanceSegment(name: L10n.threshold, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 360),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.threshold, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 360),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.threshold, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 360),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.threshold, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 360),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.threshold, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 360)
                ],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "thousandRepeats",
            title: L10n.predefinedThousandRepeatsTitle,
            description: L10n.predefinedThousandRepeatsDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 1000,
                distanceSegments: [
                    DistanceSegment(name: L10n.run, distanceMeters: 1000, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 90),
                    DistanceSegment(name: L10n.run, distanceMeters: 1000, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 90),
                    DistanceSegment(name: L10n.run, distanceMeters: 1000, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 90),
                    DistanceSegment(name: L10n.run, distanceMeters: 1000, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 90),
                    DistanceSegment(name: L10n.run, distanceMeters: 1000, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 90),
                    DistanceSegment(name: L10n.run, distanceMeters: 1000, repeatCount: 1)
                ],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "fourHundredRepeats",
            title: L10n.predefinedFourHundredRepeatsTitle,
            description: L10n.predefinedFourHundredRepeatsDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 400,
                distanceSegments: [
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 400, repeatCount: 1)
                ],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "fourHundredRepeatsNoRest",
            title: L10n.predefinedFourHundredRepeatsNoRestTitle,
            description: L10n.predefinedFourHundredRepeatsNoRestDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .distanceDistance,
                distanceLapDistanceMeters: 400,
                distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 10)],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "fortyFiveFifteens",
            title: L10n.predefinedFortyFiveFifteensTitle,
            description: L10n.predefinedFortyFiveFifteensDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 0,
                distanceSegments: [
                    DistanceSegment(name: L10n.sprint, distanceMeters: 0, repeatCount: 20, restSeconds: 15, lastRestSeconds: 90, distanceGoalMode: .open, targetTimeSeconds: 45),
                    DistanceSegment(name: L10n.sprint, distanceMeters: 0, repeatCount: 20, restSeconds: 15, distanceGoalMode: .open, targetTimeSeconds: 45)
                ],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "thirtyFifteens",
            title: L10n.predefinedThirtyFifteensTitle,
            description: L10n.predefinedThirtyFifteensDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 0,
                distanceSegments: [
                    DistanceSegment(name: L10n.sprint, distanceMeters: 0, repeatCount: 10, restSeconds: 15, lastRestSeconds: 120, distanceGoalMode: .open, targetTimeSeconds: 30),
                    DistanceSegment(name: L10n.sprint, distanceMeters: 0, repeatCount: 10, restSeconds: 15, distanceGoalMode: .open, targetTimeSeconds: 30)
                ],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "overUnder",
            title: L10n.predefinedOverUnderTitle,
            description: L10n.predefinedOverUnderDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 0,
                distanceSegments: [
                    DistanceSegment(name: L10n.predefinedOverUnderTitle, distanceMeters: 0, distanceGoalMode: .open, targetTimeSeconds: 480),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.predefinedOverUnderTitle, distanceMeters: 0, distanceGoalMode: .open, targetTimeSeconds: 480),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.predefinedOverUnderTitle, distanceMeters: 0, distanceGoalMode: .open, targetTimeSeconds: 480),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.predefinedOverUnderTitle, distanceMeters: 0, distanceGoalMode: .open, targetTimeSeconds: 480)
                ],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "pyramid",
            title: L10n.predefinedPyramidTitle,
            description: L10n.predefinedPyramidDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 0,
                distanceSegments: [
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60),
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 240),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 240),
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.run, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 60)
                ],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "structuredFartlek",
            title: L10n.predefinedStructuredFartlekTitle,
            description: L10n.predefinedStructuredFartlekDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 0,
                distanceSegments: [
                    DistanceSegment(name: L10n.surge, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.surge, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.surge, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.surge, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.surge, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180),
                    DistanceSegment(name: L10n.surge, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 120),
                    DistanceSegment(name: L10n.activeRecovery, distanceMeters: 0, repeatCount: 1, distanceGoalMode: .open, targetTimeSeconds: 180)
                ],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "longTwelves",
            title: L10n.predefinedLongTwelvesTitle,
            description: L10n.predefinedLongTwelvesDescription,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .dual,
                distanceLapDistanceMeters: 0,
                distanceSegments: [
                    DistanceSegment(name: L10n.threshold, distanceMeters: 0, repeatCount: 3, restSeconds: 180, distanceGoalMode: .open, targetTimeSeconds: 720)
                ],
                restMode: .manual
            )
        )
    ]

    var distanceSegments: [DistanceSegment] {
        get {
            guard !distanceSegmentsJSON.isEmpty,
                  let data = distanceSegmentsJSON.data(using: .utf8),
                  let segments = try? JSONDecoder().decode([DistanceSegment].self, from: data) else {
                return [
                    DistanceSegment(
                        id: Self.defaultDistanceSegmentID,
                        distanceMeters: distanceDistanceMeters,
                        repeatCount: nil
                    )
                ]
            }
            return segments
        }
        set {
            let existingSegments = distanceSegments
            guard newValue != existingSegments else { return }
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                distanceSegmentsJSON = json
            }
            // Keep legacy value in sync with first segment
            if let firstFixed = newValue.first(where: { !$0.usesOpenDistance }) {
                distanceDistanceMeters = firstFixed.distanceMeters
            } else if let first = newValue.first {
                distanceDistanceMeters = first.distanceMeters
            }
            touchCurrentWorkoutPlan()
        }
    }

    var intervalPresets: [IntervalPreset] {
        guard !intervalPresetsJSON.isEmpty,
              let data = intervalPresetsJSON.data(using: .utf8),
              let presets = try? JSONDecoder().decode([IntervalPreset].self, from: data) else {
            return []
        }

        return presets.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var currentWorkoutPlan: WorkoutPlanSnapshot {
        WorkoutPlanSnapshot(
            trackingMode: trackingMode,
            distanceLapDistanceMeters: distanceDistanceMeters,
            distanceSegments: distanceSegments,
            restMode: restMode,
            originPlanID: workoutPlanOriginID
        )
    }

    var workoutPlanOriginID: UUID? {
        get { UUID(uuidString: workoutPlanOriginIDRaw) }
        set {
            let newRawValue = newValue?.uuidString ?? ""
            guard newRawValue != workoutPlanOriginIDRaw else { return }
            workoutPlanOriginIDRaw = newRawValue
            touchCurrentWorkoutPlan()
        }
    }

    func apply(workoutPlan: WorkoutPlanSnapshot) {
        trackingMode = WorkoutPlanSupport.resolvedTrackingMode(
            requestedTrackingMode: workoutPlan.trackingMode,
            segments: workoutPlan.distanceSegments,
            currentTrackingMode: trackingMode
        )
        restMode = workoutPlan.restMode
        workoutPlanOriginID = workoutPlan.originPlanID

        let segments = workoutPlan.distanceSegments
        distanceSegments = segments

        if let distance = workoutPlan.distanceLapDistanceMeters ?? segments.first?.distanceMeters {
            distanceDistanceMeters = distance
        }
    }

    func makeSettingsSyncRecord(updatedAt: Date, deviceSource: String) -> SettingsSyncRecord {
        SettingsSyncRecord(
            trackingMode: trackingMode,
            distanceDistanceMeters: distanceDistanceMeters,
            distanceUnit: distanceUnit,
            primaryColor: primaryColor,
            restMode: restMode,
            lapAlerts: lapAlerts,
            restAlerts: restAlerts,
            appearanceMode: appearanceMode,
            syncAppearanceMode: syncAppearanceMode,
            distanceSegments: distanceSegments,
            workoutPlanOriginID: workoutPlanOriginID,
            intervalPresets: intervalPresets,
            updatedAt: updatedAt,
            deviceSource: deviceSource
        )
    }

    func apply(
        settingsSyncRecord: SettingsSyncRecord,
        context: SettingsSyncApplicationContext = .current
    ) {
        trackingMode = settingsSyncRecord.trackingMode
        distanceDistanceMeters = settingsSyncRecord.distanceDistanceMeters
        distanceUnit = settingsSyncRecord.distanceUnit
        primaryColor = settingsSyncRecord.primaryColor
        restMode = settingsSyncRecord.restMode
        lapAlerts = settingsSyncRecord.lapAlerts
        restAlerts = settingsSyncRecord.restAlerts
        let resolvedSyncAppearanceMode = SettingsSyncAppearancePolicy.resolvedLocalSyncAppearanceMode(
            currentValue: syncAppearanceMode,
            incomingValue: settingsSyncRecord.syncAppearanceMode,
            context: context
        )
        syncAppearanceMode = resolvedSyncAppearanceMode
        if SettingsSyncAppearancePolicy.shouldApplyIncomingAppearance(
            localSyncAppearanceMode: resolvedSyncAppearanceMode,
            incomingSyncAppearanceMode: settingsSyncRecord.syncAppearanceMode,
            context: context
        ) {
            appearanceMode = settingsSyncRecord.appearanceMode
        }
        distanceSegments = settingsSyncRecord.distanceSegments
        workoutPlanOriginID = settingsSyncRecord.workoutPlanOriginID
        persistIntervalPresets(settingsSyncRecord.intervalPresets)
    }

    func intervalPreset(id: UUID) -> IntervalPreset? {
        intervalPresets.first { $0.id == id }
    }

    func title(for workoutPlan: WorkoutPlanSnapshot) -> String {
        let normalizedPlan = IntervalPreset.normalizedWorkoutPlan(workoutPlan)
        let signature = IntervalPresetSignature(workoutPlan: normalizedPlan)

        if let savedPreset = intervalPresets.first(where: { $0.signature == signature }) {
            return savedPreset.customTitle ?? IntervalPreset.generatedTitle(for: normalizedPlan)
        }

        if let predefinedPreset = Self.predefinedIntervalPresets.first(where: { $0.signature == signature }) {
            return predefinedPreset.title
        }

        return IntervalPreset.generatedTitle(for: normalizedPlan)
    }

    func storeSessionIntervalPresetIfUnique(_ workoutPlan: WorkoutPlanSnapshot) {
        let normalizedPlan = IntervalPreset.normalizedWorkoutPlan(workoutPlan)
        guard normalizedPlan.trackingMode.usesManualIntervals else { return }

        let signature = IntervalPresetSignature(workoutPlan: normalizedPlan)
        let containsSavedPreset = intervalPresets.contains { $0.signature == signature }
        let matchesPredefined = Self.predefinedIntervalPresets.contains { $0.signature == signature }
        guard !containsSavedPreset && !matchesPredefined else { return }

        var presets = intervalPresets
        presets.append(IntervalPreset(workoutPlan: normalizedPlan))
        persistIntervalPresets(presets)
    }

    @discardableResult
    func saveIntervalPreset(
        _ workoutPlan: WorkoutPlanSnapshot,
        customTitle: String? = nil,
        existingPresetID: UUID? = nil,
        importedAt: Date? = nil,
        customDescription: String? = nil,
        updatesDescription: Bool = false
    ) -> IntervalPreset? {
        var normalizedPlan = IntervalPreset.normalizedWorkoutPlan(workoutPlan)
        guard normalizedPlan.trackingMode.usesManualIntervals else { return nil }

        normalizedPlan.originPlanID = normalizedPlan.originPlanID ?? UUID()
        let title = IntervalPreset.storedTitle(for: normalizedPlan, preferredTitle: customTitle)
        let description = IntervalPreset.sanitizeDescription(customDescription)
        let timestamp = importedAt ?? Date()
        let signature = IntervalPresetSignature(workoutPlan: normalizedPlan)
        var presets = intervalPresets

        if let existingPresetID,
           let existingIndex = presets.firstIndex(where: { $0.id == existingPresetID }) {
            if let duplicateIndex = presets.firstIndex(where: { $0.id != existingPresetID && $0.signature == signature }) {
                presets[duplicateIndex].customTitle = title
                if updatesDescription {
                    presets[duplicateIndex].customDescription = description
                }
                presets[duplicateIndex].updatedAt = timestamp
                if let importedAt {
                    presets[duplicateIndex].lastImportedAt = importedAt
                }
                presets.remove(at: existingIndex)
                persistIntervalPresets(presets)
                return presets[safe: duplicateIndexAdjusted(from: duplicateIndex, removedIndex: existingIndex)]
            }

            presets[existingIndex].customTitle = title
            if updatesDescription {
                presets[existingIndex].customDescription = description
            }
            presets[existingIndex].workoutPlan = normalizedPlan
            presets[existingIndex].updatedAt = timestamp
            if let importedAt {
                presets[existingIndex].lastImportedAt = importedAt
            }
            persistIntervalPresets(presets)
            return presets[existingIndex]
        }

        if let duplicateIndex = presets.firstIndex(where: { $0.signature == signature }) {
            presets[duplicateIndex].customTitle = title
            if updatesDescription {
                presets[duplicateIndex].customDescription = description
            }
            presets[duplicateIndex].updatedAt = timestamp
            if let importedAt {
                presets[duplicateIndex].lastImportedAt = importedAt
            }
            persistIntervalPresets(presets)
            return presets[duplicateIndex]
        }

        let preset = IntervalPreset(
            customTitle: title,
            customDescription: updatesDescription ? description : nil,
            workoutPlan: normalizedPlan,
            createdAt: timestamp,
            updatedAt: timestamp,
            lastImportedAt: importedAt
        )
        presets.append(preset)
        persistIntervalPresets(presets)
        return preset
    }

    func recordPresetShare(for workoutPlan: WorkoutPlanSnapshot, sharedAt: Date = Date()) {
        let normalizedPlan = IntervalPreset.normalizedWorkoutPlan(workoutPlan)
        let signature = IntervalPresetSignature(workoutPlan: normalizedPlan)
        var presets = intervalPresets

        guard let presetIndex = presets.firstIndex(where: { $0.signature == signature }) else {
            return
        }

        presets[presetIndex].lastSharedAt = sharedAt
        presets[presetIndex].updatedAt = sharedAt
        persistIntervalPresets(presets)
    }

    func deleteIntervalPreset(id: UUID) {
        var presets = intervalPresets
        presets.removeAll { $0.id == id }
        persistIntervalPresets(presets)
    }

    // MARK: - Preset Usage Tracking

    private func decodeUsageCounts() -> [String: Int] {
        let raw = presetUsageCountsJSON
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let counts = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return counts
    }

    private func encodeUsageCounts(_ counts: [String: Int]) {
        guard let data = try? JSONEncoder().encode(counts),
              let json = String(data: data, encoding: .utf8) else {
            presetUsageCountsJSON = ""
            return
        }
        presetUsageCountsJSON = json
    }

    func recordPresetUsage(for workoutPlan: WorkoutPlanSnapshot) {
        let normalized = IntervalPreset.normalizedWorkoutPlan(workoutPlan)
        guard normalized.trackingMode.usesManualIntervals else { return }
        let key = signatureKey(for: normalized)
        var counts = decodeUsageCounts()
        counts[key, default: 0] += 1
        encodeUsageCounts(counts)
        objectWillChange.send()
    }

    func presetUsageCount(for workoutPlan: WorkoutPlanSnapshot) -> Int {
        let key = signatureKey(for: IntervalPreset.normalizedWorkoutPlan(workoutPlan))
        return decodeUsageCounts()[key] ?? 0
    }

    private func signatureKey(for workoutPlan: WorkoutPlanSnapshot) -> String {
        let signature = IntervalPresetSignature(workoutPlan: workoutPlan)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(signature) else { return "" }
        return data.base64EncodedString()
    }

    private func persistIntervalPresets(_ presets: [IntervalPreset]) {
        objectWillChange.send()

        guard let data = try? JSONEncoder().encode(presets),
              let json = String(data: data, encoding: .utf8) else {
            intervalPresetsJSON = ""
            return
        }

        intervalPresetsJSON = json
    }

    private func ensureCurrentWorkoutPlanTimestamps() {
        guard currentWorkoutPlanCreatedAtInterval <= 0 || currentWorkoutPlanUpdatedAtInterval <= 0 else {
            return
        }

        let now = Date().timeIntervalSince1970
        if currentWorkoutPlanCreatedAtInterval <= 0 {
            currentWorkoutPlanCreatedAtInterval = now
        }
        if currentWorkoutPlanUpdatedAtInterval <= 0 {
            currentWorkoutPlanUpdatedAtInterval = now
        }
    }

    private func touchCurrentWorkoutPlan() {
        ensureCurrentWorkoutPlanTimestamps()
        currentWorkoutPlanUpdatedAtInterval = Date().timeIntervalSince1970
    }

    private func duplicateIndexAdjusted(from duplicateIndex: Int, removedIndex: Int) -> Int {
        duplicateIndex > removedIndex ? duplicateIndex - 1 : duplicateIndex
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
