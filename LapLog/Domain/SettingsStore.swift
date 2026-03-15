import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    @AppStorage("trackingMode") var trackingMode: TrackingMode = .distanceDistance
    @AppStorage("distanceDistanceMeters") var distanceDistanceMeters: Double = 400
    @AppStorage("distanceUnit") var distanceUnit: DistanceUnit = .km
    @AppStorage("primaryColor") var primaryColor: PrimaryColorOption = .blue

    var primaryAccentColor: Color {
        primaryColor.color
    }
}
