import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    @AppStorage("trackingMode") var trackingMode: TrackingMode = .gps
    @AppStorage("distanceDistanceMeters") var distanceDistanceMeters: Double = 400
}
