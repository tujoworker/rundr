import SwiftUI
import CoreLocation

struct PreStartView: View {
    @EnvironmentObject var settings: SettingsStore
    var onStart: () -> Void

    @State private var distanceText: String = ""
    @State private var isGPSPermissionAlertPresented = false
    @State private var isTrackingModeDialogPresented = false
    @State private var isDistanceUnitDialogPresented = false
    @State private var isPrimaryColorDialogPresented = false
    @StateObject private var locationPermissionRequester = LocationPermissionRequester()

    private var distanceLabel: String {
        switch settings.distanceUnit {
        case .km: return "Lap Distance (meters)"
        case .miles: return "Lap Distance (feet)"
        }
    }

    private var distancePlaceholder: String {
        switch settings.distanceUnit {
        case .km: return "e.g. 400"
        case .miles: return "e.g. 1320"
        }
    }

    private var distanceValueText: String {
        distanceText.isEmpty ? distancePlaceholder : distanceText
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    persistDistance()
                    onStart()
                }) {
                    Text("Start")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.primaryAccentColor)
                .disabled(settings.trackingMode == .distanceDistance && (Double(distanceText) ?? 0) <= 0)
                .padding(.bottom, 18)

                Text("Settings")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 6)

                Button {
                    isTrackingModeDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "location",
                        iconColor: settings.primaryAccentColor,
                        title: "Mode",
                        value: settings.trackingMode.displayName
                    )
                }
                .buttonStyle(.plain)

                if settings.trackingMode == .distanceDistance {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(distanceLabel)
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.horizontal, 8)

                        TextField(distancePlaceholder, text: $distanceText)
                            .multilineTextAlignment(.leading)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                            )
                    }
                }

                Button {
                    isDistanceUnitDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "ruler",
                        iconColor: .yellow,
                        title: "Distance",
                        value: settings.distanceUnit.displayName
                    )
                }
                .buttonStyle(.plain)

                Button {
                    isPrimaryColorDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "paintpalette",
                        iconColor: settings.primaryAccentColor,
                        title: "Primary Color",
                        value: settings.primaryColor.displayName
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .tint(settings.primaryAccentColor)
        .background(Color.clear)
        .onAppear {
            distanceText = displayDistance()
        }
        .onChange(of: settings.trackingMode) { _, newValue in
            guard newValue == .gps else { return }
            Task { @MainActor in
                let isGranted = await locationPermissionRequester.requestIfNeeded()
                guard !isGranted else { return }
                settings.trackingMode = .distanceDistance
                isGPSPermissionAlertPresented = true
            }
        }
        .onChange(of: settings.distanceUnit) {
            distanceText = displayDistance()
        }
        .alert("Location Required", isPresented: $isGPSPermissionAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("GPS mode needs location access. The mode was switched back to Distance.")
        }
        .confirmationDialog("Mode", isPresented: $isTrackingModeDialogPresented) {
            ForEach(TrackingMode.allCases) { mode in
                Button(mode.displayName) {
                    settings.trackingMode = mode
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Distance Unit", isPresented: $isDistanceUnitDialogPresented) {
            ForEach(DistanceUnit.allCases) { unit in
                Button(unit.displayName) {
                    settings.distanceUnit = unit
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Primary Color", isPresented: $isPrimaryColorDialogPresented) {
            ForEach(PrimaryColorOption.allCases) { color in
                Button(color.displayName) {
                    settings.primaryColor = color
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func displayDistance() -> String {
        let meters = settings.distanceDistanceMeters
        switch settings.distanceUnit {
        case .km:
            return String(format: "%.0f", meters)
        case .miles:
            return String(format: "%.0f", meters * 3.28084)
        }
    }

    private func persistDistance() {
        guard let value = Double(distanceText), value > 0 else { return }
        switch settings.distanceUnit {
        case .km:
            settings.distanceDistanceMeters = value
        case .miles:
            settings.distanceDistanceMeters = value / 3.28084
        }
    }
}

private struct SettingsCardRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)

                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

@MainActor
private final class LocationPermissionRequester: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestIfNeeded() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return false
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            continuation.resume(returning: true)
            self.continuation = nil
        case .denied, .restricted:
            continuation.resume(returning: false)
            self.continuation = nil
        case .notDetermined:
            break
        @unknown default:
            continuation.resume(returning: false)
            self.continuation = nil
        }
    }
}
