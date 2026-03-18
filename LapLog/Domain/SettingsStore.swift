import Foundation
import SwiftUI

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
}
