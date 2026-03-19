import Foundation
import SwiftUI

struct IntervalPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var customTitle: String?
    var workoutPlan: WorkoutPlanSnapshot
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        customTitle: String? = nil,
        workoutPlan: WorkoutPlanSnapshot,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let normalizedWorkoutPlan = IntervalPreset.normalizedWorkoutPlan(workoutPlan)
        self.id = id
        self.customTitle = IntervalPreset.storedTitle(for: normalizedWorkoutPlan, preferredTitle: customTitle)
        self.workoutPlan = normalizedWorkoutPlan
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var trimmedCustomTitle: String? {
        IntervalPreset.sanitizeTitle(customTitle)
    }

    var signature: IntervalPresetSignature {
        IntervalPresetSignature(workoutPlan: workoutPlan)
    }

    static func normalizedWorkoutPlan(_ workoutPlan: WorkoutPlanSnapshot) -> WorkoutPlanSnapshot {
        let normalizedSegments = normalizeSegments(workoutPlan.distanceSegments)
        return WorkoutPlanSnapshot(
            trackingMode: workoutPlan.trackingMode,
            distanceLapDistanceMeters: normalizedSegments.first?.distanceMeters ?? workoutPlan.distanceLapDistanceMeters,
            distanceSegments: normalizedSegments,
            restMode: .manual
        )
    }

    static func sanitizeTitle(_ title: String?) -> String? {
        guard let title else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func storedTitle(for workoutPlan: WorkoutPlanSnapshot, preferredTitle: String?) -> String {
        sanitizeTitle(preferredTitle) ?? generatedTitle(for: workoutPlan)
    }

    static func generatedTitle(for workoutPlan: WorkoutPlanSnapshot) -> String {
        let normalizedWorkoutPlan = normalizedWorkoutPlan(workoutPlan)
        let segments = normalizedWorkoutPlan.distanceSegments.isEmpty ? [DistanceSegment.default] : normalizedWorkoutPlan.distanceSegments
        guard let firstSegment = segments.first else { return "400 m" }

        let distanceText: String
        if firstSegment.distanceMeters >= 1000,
           firstSegment.distanceMeters.truncatingRemainder(dividingBy: 1000) == 0 {
            let kilometers = Int(firstSegment.distanceMeters / 1000)
            distanceText = "\(kilometers) km"
        } else {
            distanceText = "\(Int(firstSegment.distanceMeters)) m"
        }

        if segments.count == 1, let repeatCount = firstSegment.repeatCount {
            return "\(repeatCount) × \(distanceText)"
        }
        if segments.count == 1 {
            return distanceText
        }
        return "\(segments.count) segments"
    }

    private static func normalizeSegments(_ segments: [DistanceSegment]) -> [DistanceSegment] {
        let fallbackSegments = segments.isEmpty ? [DistanceSegment.default] : segments
        guard fallbackSegments.count > 1 else { return fallbackSegments }

        var normalized = fallbackSegments
        for index in normalized.indices.dropLast() where normalized[index].repeatCount == nil {
            normalized[index].repeatCount = 1
        }
        return normalized
    }
}

struct PredefinedIntervalPreset: Identifiable, Equatable {
    let id: String
    let title: String
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
    let distanceMeters: Double
    let repeatCount: Int?
    let restSeconds: Int?
    let targetPaceSecondsPerKm: Double?
    let targetTimeSeconds: Double?

    init(segment: DistanceSegment) {
        distanceMeters = segment.distanceMeters
        repeatCount = segment.repeatCount
        restSeconds = segment.restSeconds
        targetPaceSecondsPerKm = segment.targetPaceSecondsPerKm
        targetTimeSeconds = segment.targetTimeSeconds
    }
}

final class SettingsStore: ObservableObject {
    @AppStorage("trackingMode") var trackingMode: TrackingMode = .distanceDistance
    @AppStorage("distanceDistanceMeters") var distanceDistanceMeters: Double = 400
    @AppStorage("distanceUnit") var distanceUnit: DistanceUnit = .km
    @AppStorage("primaryColor") private var primaryColorRaw: String = "blue"
    @AppStorage("restMode") private var restModeRaw: String = RestMode.manual.rawValue
    // Preserve the user's existing saved setting while migrating from the old name.
    @AppStorage("pauseMode") private var legacyRestModeRaw: String = RestMode.manual.rawValue

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
            restModeRaw = newValue.rawValue
            legacyRestModeRaw = newValue.rawValue
        }
    }

    var primaryAccentColor: Color {
        primaryColor.color
    }

    // MARK: - Distance Segments

    @AppStorage("distanceSegmentsJSON") private var distanceSegmentsJSON: String = ""
    @AppStorage("intervalPresetsJSON") private var intervalPresetsJSON: String = ""

    static let predefinedIntervalPresets: [PredefinedIntervalPreset] = [
        PredefinedIntervalPreset(
            id: "sixByFourHundred",
            title: "6 × 400 m",
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .distanceDistance,
                distanceLapDistanceMeters: 400,
                distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "eightByTwoHundred",
            title: "8 × 200 m",
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .distanceDistance,
                distanceLapDistanceMeters: 200,
                distanceSegments: [DistanceSegment(distanceMeters: 200, repeatCount: 8, restSeconds: 45)],
                restMode: .manual
            )
        ),
        PredefinedIntervalPreset(
            id: "threeByOneK",
            title: "3 × 1 km",
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .distanceDistance,
                distanceLapDistanceMeters: 1000,
                distanceSegments: [DistanceSegment(distanceMeters: 1000, repeatCount: 3, restSeconds: 120)],
                restMode: .manual
            )
        )
    ]

    var distanceSegments: [DistanceSegment] {
        get {
            guard !distanceSegmentsJSON.isEmpty,
                  let data = distanceSegmentsJSON.data(using: .utf8),
                  let segments = try? JSONDecoder().decode([DistanceSegment].self, from: data),
                  !segments.isEmpty else {
                return [DistanceSegment(distanceMeters: distanceDistanceMeters, repeatCount: nil)]
            }
            return segments
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                distanceSegmentsJSON = json
            }
            // Keep legacy value in sync with first segment
            if let first = newValue.first {
                distanceDistanceMeters = first.distanceMeters
            }
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
            restMode: restMode
        )
    }

    func apply(workoutPlan: WorkoutPlanSnapshot) {
        trackingMode = resolvedTrackingMode(for: workoutPlan)
        restMode = workoutPlan.restMode

        let segments = workoutPlan.distanceSegments.isEmpty ? [.default] : workoutPlan.distanceSegments
        distanceSegments = segments

        if let distance = workoutPlan.distanceLapDistanceMeters ?? segments.first?.distanceMeters {
            distanceDistanceMeters = distance
        }
    }

    private func resolvedTrackingMode(for workoutPlan: WorkoutPlanSnapshot) -> TrackingMode {
        guard trackingMode == .gps, workoutPlan.trackingMode.usesManualIntervals else {
            return workoutPlan.trackingMode
        }

        return .dual
    }

    func intervalPreset(id: UUID) -> IntervalPreset? {
        intervalPresets.first { $0.id == id }
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
        existingPresetID: UUID? = nil
    ) -> IntervalPreset? {
        let normalizedPlan = IntervalPreset.normalizedWorkoutPlan(workoutPlan)
        guard normalizedPlan.trackingMode.usesManualIntervals else { return nil }

        let title = IntervalPreset.storedTitle(for: normalizedPlan, preferredTitle: customTitle)
        let now = Date()
        let signature = IntervalPresetSignature(workoutPlan: normalizedPlan)
        var presets = intervalPresets

        if let existingPresetID,
           let existingIndex = presets.firstIndex(where: { $0.id == existingPresetID }) {
            if let duplicateIndex = presets.firstIndex(where: { $0.id != existingPresetID && $0.signature == signature }) {
                presets[duplicateIndex].customTitle = title
                presets[duplicateIndex].updatedAt = now
                presets.remove(at: existingIndex)
                persistIntervalPresets(presets)
                return presets[safe: duplicateIndexAdjusted(from: duplicateIndex, removedIndex: existingIndex)]
            }

            presets[existingIndex].customTitle = title
            presets[existingIndex].workoutPlan = normalizedPlan
            presets[existingIndex].updatedAt = now
            persistIntervalPresets(presets)
            return presets[existingIndex]
        }

        if let duplicateIndex = presets.firstIndex(where: { $0.signature == signature }) {
            presets[duplicateIndex].customTitle = title
            presets[duplicateIndex].updatedAt = now
            persistIntervalPresets(presets)
            return presets[duplicateIndex]
        }

        let preset = IntervalPreset(customTitle: title, workoutPlan: normalizedPlan, createdAt: now, updatedAt: now)
        presets.append(preset)
        persistIntervalPresets(presets)
        return preset
    }

    func deleteIntervalPreset(id: UUID) {
        var presets = intervalPresets
        presets.removeAll { $0.id == id }
        persistIntervalPresets(presets)
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
