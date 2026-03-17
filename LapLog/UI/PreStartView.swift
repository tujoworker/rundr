import SwiftUI
import CoreLocation
import WatchKit

struct PreStartView: View {
    @EnvironmentObject var workoutController: WorkoutSessionController
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var settings: SettingsStore
    var onStart: () -> Void

    @State private var segments: [DistanceSegment] = []
    @State private var readyStartDate = Date()
    @State private var readyElapsedSeconds = 0
    @State private var latestHeartRate: Double?
    @State private var isGPSPermissionAlertPresented = false
    @State private var isTrackingModeDialogPresented = false
    @State private var isDistanceUnitDialogPresented = false
    @State private var isPrimaryColorDialogPresented = false
    @State private var editingSegmentID: UUID?
    @State private var editingSegmentDistanceText: String = ""
    @State private var editingSegmentRepeatCount: Int = 0
    @State private var editingSegmentRestSeconds: Int = 0
    @StateObject private var locationPermissionRequester = LocationPermissionRequester()

    private let readyTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var distanceLabel: String {
        switch settings.distanceUnit {
        case .km: return "Distance (m)"
        case .miles: return "Distance (ft)"
        }
    }

    private var distancePlaceholder: String {
        switch settings.distanceUnit {
        case .km: return "e.g. 400"
        case .miles: return "e.g. 1320"
        }
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
                Text("s")
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
                    Text("m")
                        .font(smallFont)
                        .foregroundStyle(smallColor)
                } else {
                    Text("\(m)")
                        .font(bigFont)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("m")
                        .font(smallFont)
                        .foregroundStyle(smallColor)
                    Text("\(secs)")
                        .font(bigFont)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("s")
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
        if settings.trackingMode == .distanceDistance {
            return segments.isEmpty || segments.contains { $0.distanceMeters <= 0 }
        }
        return false
    }

    private var supportsActionButton: Bool {
        let screenBounds = WKInterfaceDevice.current().screenBounds
        return screenBounds.width >= 205 && screenBounds.height >= 251
    }

    @ViewBuilder
    private var intervalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intervals")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 8)

            ForEach(segments) { segment in
                SegmentRow(
                    segment: segment,
                    distanceUnit: settings.distanceUnit,
                    onTap: { beginEditingSegment(segment) },
                    onDelete: { deleteSegment(segment) }
                )
            }

            Button {
                addSegment()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Distance")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(settings.primaryAccentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(settings.primaryAccentColor.opacity(0.5), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
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
                    Text("Press the Action Button")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 2)
                }

                if settings.trackingMode == .distanceDistance {
                    intervalsSection
                }

                Text(L10n.settings)
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.top, 12)

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
                        title: "Color",
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
            segments = settings.distanceSegments
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
            // Segments are stored in meters; no conversion needed on unit change
        }
        .alert("Location Required", isPresented: $isGPSPermissionAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("GPS mode needs location access. The mode was switched back to Distance.")
        }
        .confirmationDialog(L10n.mode, isPresented: $isTrackingModeDialogPresented) {
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
        .sheet(isPresented: Binding(
            get: { editingSegmentID != nil },
            set: { if !$0 { commitSegmentEdit() } }
        )) {
            SegmentEditSheet(
                distanceText: $editingSegmentDistanceText,
                repeatCount: $editingSegmentRepeatCount,
                restSeconds: $editingSegmentRestSeconds,
                distanceLabel: distanceLabel,
                distancePlaceholder: distancePlaceholder,
                accentColor: settings.primaryAccentColor,
                onDone: { commitSegmentEdit() }
            )
        }
    }

    private func persistSegments() {
        settings.distanceSegments = segments
    }

    private func startSession() {
        persistSegments()
        onStart()
    }

    private func addSegment() {
        let lastDistance = segments.last?.distanceMeters ?? 400
        segments.append(DistanceSegment(distanceMeters: lastDistance, repeatCount: nil))
        persistSegments()
    }

    private func deleteSegment(_ segment: DistanceSegment) {
        segments.removeAll { $0.id == segment.id }
        if segments.isEmpty {
            segments = [.default]
        }
        persistSegments()
    }

    private func beginEditingSegment(_ segment: DistanceSegment) {
        editingSegmentID = segment.id
        let displayDist: Double
        switch settings.distanceUnit {
        case .km: displayDist = segment.distanceMeters
        case .miles: displayDist = segment.distanceMeters * 3.28084
        }
        editingSegmentDistanceText = displayDist == floor(displayDist) ? String(format: "%.0f", displayDist) : String(format: "%g", displayDist)
        editingSegmentRepeatCount = segment.repeatCount ?? 0
        editingSegmentRestSeconds = segment.restSeconds ?? 0
    }

    private func commitSegmentEdit() {
        guard let id = editingSegmentID,
              let idx = segments.firstIndex(where: { $0.id == id }),
              let value = Double(editingSegmentDistanceText), value > 0 else {
            editingSegmentID = nil
            return
        }
        let meters: Double
        switch settings.distanceUnit {
        case .km: meters = value
        case .miles: meters = value / 3.28084
        }
        segments[idx].distanceMeters = meters
        segments[idx].repeatCount = editingSegmentRepeatCount > 0 ? editingSegmentRepeatCount : nil
        segments[idx].restSeconds = editingSegmentRestSeconds > 0 ? editingSegmentRestSeconds : nil
        editingSegmentID = nil
        persistSegments()
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

private struct SegmentRow: View {
    let segment: DistanceSegment
    let distanceUnit: DistanceUnit
    let onTap: () -> Void
    let onDelete: () -> Void

    private var distanceDisplay: String {
        Formatters.distanceString(meters: segment.distanceMeters, unit: distanceUnit)
    }

    private var hasRepeatCount: Bool {
        segment.repeatCount != nil
    }

    private var hasRestDuration: Bool {
        segment.restSeconds != nil
    }

    private var hasSecondaryDetails: Bool {
        hasRepeatCount || hasRestDuration
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text(distanceDisplay)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if hasSecondaryDetails {
                        VStack(alignment: .leading, spacing: 1) {
                            if let count = segment.repeatCount {
                                Text("×\(count)")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            if let rest = segment.restSeconds {
                                Text("\(rest)s rest")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SegmentEditSheet: View {
    @Binding var distanceText: String
    @Binding var repeatCount: Int
    @Binding var restSeconds: Int
    let distanceLabel: String
    let distancePlaceholder: String
    let accentColor: Color
    let onDone: () -> Void

    private var distanceValue: Double {
        Double(distanceText) ?? 0
    }

    private var stepSize: Double {
        distanceValue >= 1000 ? 100 : 50
    }

    private var repeatLabel: String {
        repeatCount > 0 ? "\(repeatCount)" : "∞"
    }

    private var restLabel: String {
        restSeconds > 0 ? "\(restSeconds)s" : "Manual"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(distanceLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    Button {
                        let current = distanceValue
                        let newVal = max(stepSize, current - stepSize)
                        distanceText = formatDistanceValue(newVal)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                        TextField(distancePlaceholder, text: $distanceText)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)

                    Button {
                        let current = distanceValue
                        let newVal = current + stepSize
                        distanceText = formatDistanceValue(newVal)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                Text("Repeats")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    Button {
                        if repeatCount > 0 {
                            repeatCount -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text(repeatLabel)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )

                    Button {
                        repeatCount += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                Text("Rest")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    Button {
                        if restSeconds >= 15 {
                            restSeconds -= 15
                        } else {
                            restSeconds = 0
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text(restLabel)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )

                    Button {
                        restSeconds += 15
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                Button("Done") {
                    onDone()
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accentColor)
                )
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .scrollContentBackground(.hidden)
    }

    private func formatDistanceValue(_ value: Double) -> String {
        value == floor(value) ? String(format: "%.0f", value) : String(format: "%g", value)
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
