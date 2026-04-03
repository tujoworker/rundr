import Foundation
import SwiftData

struct WorkoutPlanSnapshot: Codable, Equatable {
    var trackingMode: TrackingMode
    var distanceLapDistanceMeters: Double?
    var distanceSegments: [DistanceSegment]
    var restMode: RestMode

    init(
        trackingMode: TrackingMode,
        distanceLapDistanceMeters: Double? = nil,
        distanceSegments: [DistanceSegment] = [.default],
        restMode: RestMode = .manual
    ) {
        let normalizedSegments = distanceSegments.isEmpty ? [.default] : distanceSegments
        if trackingMode == .distanceDistance, normalizedSegments.contains(where: \.usesOpenDistance) {
            self.trackingMode = .dual
        } else {
            self.trackingMode = trackingMode
        }
        self.distanceLapDistanceMeters = self.trackingMode.usesManualIntervals
            ? (distanceLapDistanceMeters ?? normalizedSegments.first?.distanceMeters ?? DistanceSegment.default.distanceMeters)
            : nil
        self.distanceSegments = normalizedSegments
        self.restMode = restMode
    }
}

enum WorkoutPlanSupport {
    static func normalizedSegments(_ input: [DistanceSegment]) -> [DistanceSegment] {
        let segments = input.isEmpty ? [.default] : input
        guard segments.count > 1 else { return segments }

        var normalized = segments
        for index in normalized.indices.dropLast() where normalized[index].repeatCount == nil {
            normalized[index].repeatCount = 1
        }
        return normalized
    }

    static func reorderedSegments(
        _ input: [DistanceSegment],
        fromOffsets: IndexSet,
        toOffset: Int
    ) -> [DistanceSegment] {
        let segments = input.isEmpty ? [.default] : input
        let movingSegments = fromOffsets.sorted().map { segments[$0] }
        let remainingSegments = segments.enumerated().compactMap { index, segment in
            fromOffsets.contains(index) ? nil : segment
        }
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        let insertionIndex = max(0, min(toOffset - removedBeforeDestination, remainingSegments.count))

        var reorderedSegments = remainingSegments
        reorderedSegments.insert(contentsOf: movingSegments, at: insertionIndex)
        return normalizedSegments(reorderedSegments)
    }

    static func nextSegmentForAppend(from segments: [DistanceSegment]) -> DistanceSegment {
        let source = segments.last ?? .default
        return DistanceSegment(
            distanceMeters: source.distanceMeters,
            repeatCount: source.repeatCount,
            restSeconds: source.restSeconds,
            lastRestSeconds: source.lastRestSeconds,
            distanceGoalMode: source.distanceGoalMode,
            targetPaceSecondsPerKm: source.targetPaceSecondsPerKm,
            targetTimeSeconds: source.targetTimeSeconds
        )
    }

    static func resolvedTrackingMode(
        requestedTrackingMode: TrackingMode,
        segments: [DistanceSegment],
        currentTrackingMode: TrackingMode? = nil
    ) -> TrackingMode {
        if requestedTrackingMode == .distanceDistance,
           segments.contains(where: \.usesOpenDistance) {
            return .dual
        }

        guard let currentTrackingMode,
              currentTrackingMode == .gps,
              requestedTrackingMode.usesManualIntervals else {
            return requestedTrackingMode
        }

        return .dual
    }

    static func makeWorkoutPlan(
        requestedTrackingMode: TrackingMode,
        currentTrackingMode: TrackingMode? = nil,
        fallbackDistance: Double? = nil,
        segments: [DistanceSegment],
        restMode: RestMode
    ) -> WorkoutPlanSnapshot {
        let normalizedSegments = normalizedSegments(segments)
        let trackingMode = resolvedTrackingMode(
            requestedTrackingMode: requestedTrackingMode,
            segments: normalizedSegments,
            currentTrackingMode: currentTrackingMode
        )
        let distance = normalizedSegments.first?.distanceMeters ?? fallbackDistance

        return WorkoutPlanSnapshot(
            trackingMode: trackingMode,
            distanceLapDistanceMeters: distance,
            distanceSegments: normalizedSegments,
            restMode: restMode
        )
    }
}

enum SegmentEditSheetSection: Hashable {
    case timeTarget
    case rest
    case lastRest
    case repeats
    case paceTarget

    static func orderedSections(for usesOpenDistance: Bool) -> [SegmentEditSheetSection] {
        if usesOpenDistance {
            return [.timeTarget, .rest, .lastRest, .repeats]
        }

        return [.rest, .lastRest, .repeats, .paceTarget, .timeTarget]
    }
}

enum SegmentEditSheetRules {
    enum AddLastRestAction {
        case addValue
        case showRepeatsInfo
    }

    static func canConfigureLastRest(repeatCount: Int, restSeconds: Int) -> Bool {
        repeatCount > 0
    }

    static func shouldShowAddLastRestButton(lastRestSeconds: Int) -> Bool {
        lastRestSeconds <= 0
    }

    static func addLastRestAction(repeatCount: Int) -> AddLastRestAction {
        canConfigureLastRest(repeatCount: repeatCount, restSeconds: 0) ? .addValue : .showRepeatsInfo
    }

    static func normalizedLastRestSeconds(_ lastRestSeconds: Int, repeatCount: Int) -> Int {
        repeatCount > 0 ? lastRestSeconds : 0
    }
}

enum SegmentEditorValueRules {
    static func normalizedLastRestSeconds(lastRestSeconds: Int?, repeatCount: Int?) -> Int? {
        guard let repeatCount, repeatCount > 0 else { return nil }
        guard let lastRestSeconds, lastRestSeconds > 0 else { return nil }
        return lastRestSeconds
    }

    static func normalizedTargetPace(
        for distanceGoalMode: DistanceGoalMode,
        targetPaceSecondsPerKm: Double?
    ) -> Double? {
        distanceGoalMode == .open ? nil : targetPaceSecondsPerKm
    }

    static func updatedTargetsAfterSettingTime(
        seconds: Int,
        currentPaceSecondsPerKm: Double?
    ) -> (targetTimeSeconds: Double?, targetPaceSecondsPerKm: Double?) {
        let targetTimeSeconds = seconds > 0 ? Double(seconds) : nil
        let targetPaceSecondsPerKm = seconds > 0 ? nil : currentPaceSecondsPerKm
        return (targetTimeSeconds, targetPaceSecondsPerKm)
    }

    static func updatedTargetsAfterSettingPace(
        secondsPerKm: Int,
        currentTargetTimeSeconds: Double?
    ) -> (targetTimeSeconds: Double?, targetPaceSecondsPerKm: Double?) {
        let targetPaceSecondsPerKm = secondsPerKm > 0 ? Double(secondsPerKm) : nil
        let targetTimeSeconds = secondsPerKm > 0 ? nil : currentTargetTimeSeconds
        return (targetTimeSeconds, targetPaceSecondsPerKm)
    }
}

enum SegmentEditInputParser {
    static func parseRepeatCount(from value: String) -> Int {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmedValue) ?? 0
    }

    static func parseDurationSeconds(from value: String) -> Int {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return 0 }

        let components = trimmedValue.split(separator: ":", omittingEmptySubsequences: false)

        if components.count == 1 {
            return Int(components[0]) ?? 0
        }

        guard components.count <= 3 else { return 0 }
        guard components.allSatisfy({ !$0.isEmpty && Int($0) != nil }) else { return 0 }

        let values = components.compactMap { Int($0) }
        guard values.count == components.count else { return 0 }
        guard values.dropFirst().allSatisfy({ $0 < 60 }) else { return 0 }

        return values.reversed().enumerated().reduce(0) { partialResult, pair in
            let (index, component) = pair
            return partialResult + component * Int(pow(60.0, Double(index)))
        }
    }

    static func applyDurationKey(_ key: String, to text: inout String) {
        if key == "⌫" {
            if !text.isEmpty {
                text.removeLast()
            }
            return
        }

        if key == ":" {
            guard !text.isEmpty, !text.hasSuffix(":"), !text.contains(":") else { return }
            text += key
            return
        }

        if let colonIndex = text.firstIndex(of: ":") {
            let secondsStart = text.index(after: colonIndex)
            let secondsCount = text[secondsStart...].count
            guard secondsCount < 2 else { return }
            text += key
            return
        }

        // If the trailing colon was removed with backspace from "mm:", resume in mm:ss mode.
        if text.count >= 2 {
            text += ":"
            text += key
            return
        }

        text += key

        // Match watch-style keypad behavior by auto-inserting a colon after two digits.
        if !text.contains(":"), text.count == 2 {
            text += ":"
        }
    }

    static func applyRepeatKey(_ key: String, to text: inout String) {
        if key == "⌫" {
            if !text.isEmpty {
                text.removeLast()
            }
            return
        }

        if key == "∞" {
            text = ""
            return
        }

        text += key
    }

    static func applyDistanceKey(_ key: String, to text: inout String) {
        if key == "⌫" {
            if !text.isEmpty {
                text.removeLast()
            }
            return
        }

        if key == "." {
            if text.isEmpty {
                text = "0."
            } else if !text.contains(".") {
                text += key
            }
            return
        }

        text += key
    }
}

enum CompanionSegmentEditorField {
    case distance
    case repeats
    case rest
    case lastRest
    case time
    case pace
}

enum CompanionSegmentEditorRules {
    static func canOpenEditor(
        field: CompanionSegmentEditorField,
        lastRestSeconds: Int?
    ) -> Bool {
        switch field {
        case .time, .pace, .distance, .repeats, .rest:
            return true
        case .lastRest:
            return (lastRestSeconds ?? 0) > 0
        }
    }

    static func emptyDisplayValue(for field: CompanionSegmentEditorField) -> String? {
        switch field {
        case .time, .pace:
            return L10n.off
        case .distance, .repeats, .rest, .lastRest:
            return nil
        }
    }
}

func durationFieldTapKey(_ key: String, text: inout String) {
    SegmentEditInputParser.applyDurationKey(key, to: &text)
}

func repeatFieldTapKey(_ key: String, text: inout String) {
    SegmentEditInputParser.applyRepeatKey(key, to: &text)
}

extension IntervalPreset {
    func displayTitle(unit: DistanceUnit) -> String {
        trimmedCustomTitle ?? workoutPlan.displayTitle(unit: unit)
    }
}

extension WorkoutPlanSnapshot {
    func displayTitle(unit: DistanceUnit) -> String {
        let normalizedSegments = WorkoutPlanSupport.normalizedSegments(distanceSegments)
        guard let firstSegment = normalizedSegments.first else {
            return Formatters.distanceString(meters: DistanceSegment.default.distanceMeters, unit: unit)
        }

        let distance = firstSegment.usesOpenDistance
            ? L10n.openDistance
            : Formatters.distanceString(meters: firstSegment.distanceMeters, unit: unit)

        if normalizedSegments.count == 1, let repeatCount = firstSegment.repeatCount {
            return "\(repeatCount) × \(distance)"
        }

        if normalizedSegments.count == 1 {
            return distance
        }

        return L10n.segmentCount(normalizedSegments.count)
    }

    func displayDetail(unit: DistanceUnit) -> String {
        WorkoutPlanSupport
            .normalizedSegments(distanceSegments)
            .map { segment in
                let distance = segment.usesOpenDistance
                    ? L10n.openDistance
                    : Formatters.distanceString(meters: segment.distanceMeters, unit: unit)

                if let repeatCount = segment.repeatCount {
                    return "\(repeatCount) × \(distance)"
                }

                return distance
            }
            .joined(separator: " • ")
    }
}

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var modeRaw: String
    var sportVariantRaw: String?
    var distanceLapDistanceMeters: Double?
    var totalDistanceMeters: Double
    var totalGPSDistanceMeters: Double?
    var averageSpeedMetersPerSecond: Double
    var totalLaps: Int
    @Relationship(deleteRule: .cascade)
    var laps: [Lap]
    var deviceSource: String
    var healthKitWorkoutUUID: UUID?
    var createdAt: Date
    var updatedAt: Date

    // Settings snapshot
    var snapshotTrackingModeRaw: String
    var snapshotDistanceDistanceMeters: Double?
    var snapshotWorkoutPlanJSON: String = ""

    var mode: TrackingMode {
        get { TrackingMode(rawValue: modeRaw) ?? .gps }
        set { modeRaw = newValue.rawValue }
    }

    var snapshotTrackingMode: TrackingMode {
        get { TrackingMode(rawValue: snapshotTrackingModeRaw) ?? .gps }
        set { snapshotTrackingModeRaw = newValue.rawValue }
    }

    var snapshotWorkoutPlan: WorkoutPlanSnapshot {
        get {
            guard !snapshotWorkoutPlanJSON.isEmpty,
                  let data = snapshotWorkoutPlanJSON.data(using: .utf8),
                  let snapshot = try? JSONDecoder().decode(WorkoutPlanSnapshot.self, from: data) else {
                let fallbackDistance = snapshotDistanceDistanceMeters
                    ?? distanceLapDistanceMeters
                    ?? DistanceSegment.default.distanceMeters
                let fallbackSegments: [DistanceSegment]
                if snapshotTrackingMode.usesManualIntervals {
                    fallbackSegments = [DistanceSegment(distanceMeters: fallbackDistance)]
                } else {
                    fallbackSegments = [.default]
                }

                return WorkoutPlanSnapshot(
                    trackingMode: snapshotTrackingMode,
                    distanceLapDistanceMeters: snapshotDistanceDistanceMeters,
                    distanceSegments: fallbackSegments,
                    restMode: .manual
                )
            }
            return snapshot
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                snapshotWorkoutPlanJSON = ""
                return
            }
            snapshotWorkoutPlanJSON = json
        }
    }

    var activeLapCount: Int {
        laps.filter { $0.lapType == .active }.count
    }

    var activeDurationSeconds: Double {
        laps.filter { $0.lapType == .active }.reduce(0) { $0 + $1.durationSeconds }
    }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Double,
        mode: TrackingMode,
        sportVariantRaw: String? = nil,
        distanceLapDistanceMeters: Double? = nil,
        totalDistanceMeters: Double,
        totalGPSDistanceMeters: Double? = nil,
        averageSpeedMetersPerSecond: Double,
        totalLaps: Int,
        laps: [Lap] = [],
        deviceSource: String = "",
        healthKitWorkoutUUID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        snapshotTrackingMode: TrackingMode,
        snapshotDistanceDistanceMeters: Double? = nil,
        snapshotWorkoutPlan: WorkoutPlanSnapshot? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.modeRaw = mode.rawValue
        self.sportVariantRaw = sportVariantRaw
        self.distanceLapDistanceMeters = distanceLapDistanceMeters
        self.totalDistanceMeters = totalDistanceMeters
        self.totalGPSDistanceMeters = totalGPSDistanceMeters
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.totalLaps = totalLaps
        self.laps = laps
        self.deviceSource = deviceSource
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.snapshotTrackingModeRaw = snapshotTrackingMode.rawValue
        self.snapshotDistanceDistanceMeters = snapshotDistanceDistanceMeters
        self.snapshotWorkoutPlan = snapshotWorkoutPlan ?? WorkoutPlanSnapshot(
            trackingMode: snapshotTrackingMode,
            distanceLapDistanceMeters: snapshotDistanceDistanceMeters,
            distanceSegments: snapshotTrackingMode.usesManualIntervals
                ? [DistanceSegment(distanceMeters: snapshotDistanceDistanceMeters ?? distanceLapDistanceMeters ?? DistanceSegment.default.distanceMeters)]
                : [.default],
            restMode: .manual
        )
    }
}
