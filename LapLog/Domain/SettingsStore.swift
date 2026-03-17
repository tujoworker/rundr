import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    @AppStorage("trackingMode") var trackingMode: TrackingMode = .distanceDistance
    @AppStorage("distanceDistanceMeters") var distanceDistanceMeters: Double = 400
    @AppStorage("distanceUnit") var distanceUnit: DistanceUnit = .km
    @AppStorage("primaryColor") private var primaryColorRaw: String = "blue"

    var primaryColor: PrimaryColorOption {
        get { PrimaryColorOption(rawValue: primaryColorRaw) ?? .blue }
        set { primaryColorRaw = newValue.rawValue }
    }
    @AppStorage("pauseMode") var pauseMode: PauseMode = .manual

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
