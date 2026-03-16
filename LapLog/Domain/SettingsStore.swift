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
}
