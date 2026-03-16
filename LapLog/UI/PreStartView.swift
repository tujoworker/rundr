import SwiftUI
import CoreLocation
import WatchKit

struct PreStartView: View {
    @EnvironmentObject var workoutController: WorkoutSessionController
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var settings: SettingsStore
    var onStart: () -> Void

    @State private var distanceText: String = ""
    @State private var readyStartDate = Date()
    @State private var readyElapsedSeconds = 0
    @State private var latestHeartRate: Double?
    @State private var isGPSPermissionAlertPresented = false
    @State private var isTrackingModeDialogPresented = false
    @State private var isDistanceUnitDialogPresented = false
    @State private var isPrimaryColorDialogPresented = false
    @StateObject private var locationPermissionRequester = LocationPermissionRequester()

    private let readyTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var distanceLabel: String { L10n.distance }

    private var distanceInputLabel: String {
        switch settings.distanceUnit {
        case .km: return L10n.distanceMeters
        case .miles: return L10n.distanceFeet
        }
    }

    private var distancePlaceholder: String {
        switch settings.distanceUnit {
        case .km: return L10n.distancePlaceholderKm
        case .miles: return L10n.distancePlaceholderMiles
        }
    }

    private var distanceValueText: String {
        distanceText.isEmpty ? distancePlaceholder : distanceText
    }

    @ViewBuilder
    private var readyTimerView: some View {
        let s = readyElapsedSeconds
        let bigFont = Font.system(size: 26, weight: .bold, design: .rounded)
        let smallFont = Font.system(size: 13, weight: .semibold, design: .rounded)
        let smallColor = Color.white.opacity(0.78)

        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if s < 60 {
                Text("\(s)")
                    .font(bigFont)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(L10n.secondsAbbrev)
                    .font(smallFont)
                    .foregroundStyle(smallColor)
            } else {
                let m = s / 60
                let secs = s % 60
                if secs == 0 {
                    Text("\(m)")
                        .font(bigFont)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(L10n.minutesAbbrev)
                        .font(smallFont)
                        .foregroundStyle(smallColor)
                } else {
                    Text("\(m)")
                        .font(bigFont)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(L10n.minutesAbbrev)
                        .font(smallFont)
                        .foregroundStyle(smallColor)
                    Text("\(secs)")
                        .font(bigFont)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(L10n.secondsAbbrev)
                        .font(smallFont)
                        .foregroundStyle(smallColor)
                }
            }
        }
    }

    private var readyHeartRateText: String {
        Formatters.heartRateString(bpm: latestHeartRate)
    }

    private var isStartDisabled: Bool {
        settings.trackingMode == .distanceDistance && (Double(distanceText) ?? 0) <= 0
    }

    private var supportsActionButton: Bool {
        let screenBounds = WKInterfaceDevice.current().screenBounds
        return screenBounds.width >= 205 && screenBounds.height >= 251
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        readyTimerView

                        ReadyHeartIndicator(heartRateText: readyHeartRateText)
                    }

                    Spacer(minLength: 12)

                    Button(action: startSession) {
                        ReadyStartIcon(baseColor: settings.primaryAccentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(isStartDisabled)
                    .opacity(isStartDisabled ? 0.5 : 1)
                }

                Color.clear
                    .frame(height: 6)

                if supportsActionButton {
                    Text(L10n.pressActionButton)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 2)
                }

                Text(L10n.settings)
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 6)

                Button {
                    isTrackingModeDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "location",
                        iconColor: settings.primaryAccentColor,
                        title: L10n.mode,
                        value: settings.trackingMode.displayName
                    )
                }
                .buttonStyle(.plain)

                if settings.trackingMode == .distanceDistance {
                    NavigationLink {
                        DistanceInputView(
                            label: distanceInputLabel,
                            placeholder: distancePlaceholder,
                            text: $distanceText,
                            onValueChange: persistDistance
                        )
                    } label: {
                        SettingsCardRow(
                            icon: "ruler",
                            iconColor: .yellow,
                            title: distanceLabel,
                            value: distanceText.isEmpty ? distancePlaceholder : distanceText
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isDistanceUnitDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .yellow,
                        title: L10n.unit,
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
                        title: L10n.color,
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
            readyStartDate = Date()
            readyElapsedSeconds = 0
            distanceText = displayDistance()
            refreshHeartRate()
        }
        .onReceive(readyTimer) { currentDate in
            readyElapsedSeconds = Int(currentDate.timeIntervalSince(readyStartDate))

            guard readyElapsedSeconds == 0 || readyElapsedSeconds % 3 == 0 else { return }
            refreshHeartRate()
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
        .alert(L10n.locationRequired, isPresented: $isGPSPermissionAlertPresented) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.gpsModeNeedsLocation)
        }
        .confirmationDialog(L10n.mode, isPresented: $isTrackingModeDialogPresented) {
            ForEach(TrackingMode.allCases) { mode in
                Button(mode.displayName) {
                    settings.trackingMode = mode
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .confirmationDialog(L10n.distanceUnit, isPresented: $isDistanceUnitDialogPresented) {
            ForEach(DistanceUnit.allCases) { unit in
                Button(unit.displayName) {
                    settings.distanceUnit = unit
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .confirmationDialog(L10n.primaryColor, isPresented: $isPrimaryColorDialogPresented) {
            ForEach(PrimaryColorOption.allCases) { color in
                Button(color.displayName) {
                    settings.primaryColor = color
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }

    private func displayDistance() -> String {
        let meters = settings.distanceDistanceMeters
        switch settings.distanceUnit {
        case .km:
            return formatDistance(meters)
        case .miles:
            return formatDistance(meters * 3.28084)
        }
    }

    private func formatDistance(_ value: Double) -> String {
        value == floor(value)
            ? String(format: "%.0f", value)
            : String(format: "%g", value)
    }

    private func persistDistance() {
        let normalized = distanceText.hasPrefix(".") ? "0" + distanceText : distanceText
        guard let value = Double(normalized), value > 0 else { return }
        switch settings.distanceUnit {
        case .km:
            settings.distanceDistanceMeters = value
        case .miles:
            settings.distanceDistanceMeters = value / 3.28084
        }
    }

    private func startSession() {
        persistDistance()
        onStart()
    }

    private func refreshHeartRate() {
        Task {
            let bpm = await healthKitManager.fetchMostRecentHeartRate()
            await MainActor.run {
                latestHeartRate = bpm ?? workoutController.currentHeartRate
            }
        }
    }
}

private struct ReadyHeartIndicator: View {
    let heartRateText: String

    var body: some View {
        HStack(spacing: 6) {
            Text(heartRateText)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Image(systemName: "heart.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct ReadyStartIcon: View {
    let baseColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [baseColor.opacity(0.98), baseColor.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 3)
                .padding(1.5)
        }
        .overlay {
            Image(systemName: "figure.run")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 78, height: 78)
        .shadow(color: baseColor.opacity(0.28), radius: 6, y: 2)
    }
}

private struct SettingsCardRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    private var iconHorizontalPadding: CGFloat {
        let w = WKInterfaceDevice.current().screenBounds.width
        if w < 200 { return 8 }
        if w < 210 { return 12 }
        return 18
    }

    var body: some View {
        HStack(alignment: .center, spacing: iconHorizontalPadding > 12 ? 12 : 8) {
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

            Spacer(minLength: 6)
        }
        .padding(.leading, iconHorizontalPadding)
        .padding(.trailing, 0)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private final class LocationPermissionRequester: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Bool, Never>?

    @MainActor
    override init() {
        super.init()
        manager.delegate = self
    }

    @MainActor
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

    @MainActor
    private func handleAuthorizationChange(_ manager: CLLocationManager) {
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

extension LocationPermissionRequester: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.handleAuthorizationChange(manager)
        }
    }
}
