import SwiftUI
import CoreLocation
import WatchKit

struct PreStartView: View {
    @EnvironmentObject var workoutController: WorkoutSessionController
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: NavigationCoordinator
    var onStart: () -> Void

    @State private var segments: [DistanceSegment] = []
    @State private var readyStartDate = Date()
    @State private var readyElapsedSeconds = 0
    @State private var latestHeartRate: Double?
    @State private var isGPSPermissionAlertPresented = false
    @State private var isTrackingModeDialogPresented = false
    @State private var isDistanceUnitDialogPresented = false
    @State private var isRestModeDialogPresented = false
    @State private var isPrimaryColorDialogPresented = false
    @State private var editingSegmentID: UUID?
    @State private var editingSegmentDistanceText: String = ""
    @State private var editingSegmentRepeatCount: Int = 0
    @State private var editingSegmentRestSeconds: Int = 0
    @State private var editingSegmentTargetPace: Int = 0
    @State private var editingSegmentTargetTime: Int = 0
    @State private var lastAddedDistanceMeters: Double = 400
    @State private var lastAddedRepeatCount: Int = 0
    @State private var lastAddedRestSeconds: Int = 0
    @State private var lastAddedTargetPace: Int = 0
    @State private var lastAddedTargetTime: Int = 0
    @StateObject private var locationPermissionRequester = LocationPermissionRequester()

    private let readyTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var distanceLabel: String {
        switch settings.distanceUnit {
        case .km: return "Distance (m)"
        case .miles: return "Distance (ft)"
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .accentRoundedButtonChrome(accentColor: settings.primaryAccentColor, cornerRadius: 16)
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
                    .offset(x: 6, y: 8)

                    Spacer(minLength: 12)

                    Button(action: startSession) {
                        ReadyStartIcon(baseColor: settings.primaryAccentColor)
                    }
                    .buttonStyle(BounceButtonStyle())
                    .disabled(isStartDisabled)
                    .opacity(isStartDisabled ? 0.5 : 1)
                    .offset(x: -4)
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

                    Button {
                        coordinator.goToIntervalLibrary()
                    } label: {
                        SettingsCardRow(
                            icon: "square.grid.2x2",
                            iconColor: settings.primaryAccentColor,
                            title: L10n.browse,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
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
                    isRestModeDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "figure.cooldown",
                        iconColor: .mint,
                        title: L10n.restMode,
                        value: settings.restMode.displayName
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
            lastAddedDistanceMeters = settings.distanceSegments.last?.distanceMeters ?? 400
            lastAddedRepeatCount = settings.distanceSegments.last?.repeatCount ?? 0
            lastAddedRestSeconds = settings.distanceSegments.last?.restSeconds ?? 0
            lastAddedTargetPace = Int(settings.distanceSegments.last?.targetPaceSecondsPerKm ?? 0)
            lastAddedTargetTime = Int(settings.distanceSegments.last?.targetTimeSeconds ?? 0)
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
        .confirmationDialog(L10n.restMode, isPresented: $isRestModeDialogPresented) {
            ForEach(RestMode.allCases) { mode in
                Button(mode.displayName) {
                    settings.restMode = mode
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
                targetPace: $editingSegmentTargetPace,
                targetTime: $editingSegmentTargetTime,
                distanceLabel: distanceLabel,
                distanceUnit: settings.distanceUnit,
                accentColor: settings.primaryAccentColor,
                onDone: { commitSegmentEdit() }
            )
        }
    }

    private func persistSegments() {
        segments = normalizedSegments(segments)
        settings.distanceSegments = segments
    }

    private func normalizedSegments(_ input: [DistanceSegment]) -> [DistanceSegment] {
        guard input.count > 1 else { return input }

        var normalized = input
        for index in normalized.indices.dropLast() where normalized[index].repeatCount == nil {
            normalized[index].repeatCount = 1
        }
        return normalized
    }

    private func startSession() {
        persistSegments()
        onStart()
    }

    private func addSegment() {
        segments.append(
            DistanceSegment(
                distanceMeters: lastAddedDistanceMeters,
                repeatCount: lastAddedRepeatCount > 0 ? lastAddedRepeatCount : nil,
                restSeconds: lastAddedRestSeconds > 0 ? lastAddedRestSeconds : nil,
                targetPaceSecondsPerKm: lastAddedTargetPace > 0 ? Double(lastAddedTargetPace) : nil,
                targetTimeSeconds: lastAddedTargetTime > 0 ? Double(lastAddedTargetTime) : nil
            )
        )
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
        editingSegmentTargetPace = Int(segment.targetPaceSecondsPerKm ?? 0)
        editingSegmentTargetTime = Int(segment.targetTimeSeconds ?? 0)
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
        lastAddedDistanceMeters = meters
        lastAddedRepeatCount = editingSegmentRepeatCount
        lastAddedRestSeconds = editingSegmentRestSeconds
        lastAddedTargetPace = editingSegmentTargetPace
        lastAddedTargetTime = editingSegmentTargetTime
        segments[idx].repeatCount = editingSegmentRepeatCount > 0 ? editingSegmentRepeatCount : nil
        segments[idx].restSeconds = editingSegmentRestSeconds > 0 ? editingSegmentRestSeconds : nil
        segments[idx].targetPaceSecondsPerKm = editingSegmentTargetPace > 0 ? Double(editingSegmentTargetPace) : nil
        segments[idx].targetTimeSeconds = editingSegmentTargetTime > 0 ? Double(editingSegmentTargetTime) : nil
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

    private var hasTarget: Bool {
        segment.effectiveTargetTimeSeconds != nil
    }

    private var hasSecondaryDetails: Bool {
        hasRepeatCount || hasRestDuration || hasTarget
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
                            if let targetTime = segment.effectiveTargetTimeSeconds {
                                Text(Formatters.compactTimeString(from: targetTime))
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

struct HistorySessionSetupView: View {
    let session: Session
    let onContinue: (WorkoutPlanSnapshot) -> Void

    private var sourceTitle: String {
        session.startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        IntervalSetupView(
            headerTitle: L10n.adjustSettings,
            subtitle: L10n.loadedFromSession(sourceTitle),
            initialWorkoutPlan: session.snapshotWorkoutPlan,
            initialCustomTitle: nil,
            initialStoredPresetID: nil,
            showsCustomTitle: false,
            autoSaveOnSegmentDone: false,
            onContinue: { workoutPlan, _, _ in
                onContinue(workoutPlan)
            }
        )
    }
}

struct IntervalLibraryView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: NavigationCoordinator
    @State private var displayedPresetCount = 10

    private var visiblePresets: [IntervalPreset] {
        Array(settings.intervalPresets.prefix(displayedPresetCount))
    }

    private var hasMorePresets: Bool {
        settings.intervalPresets.count > displayedPresetCount
    }

    var body: some View {
        List {
            Section(L10n.myIntervals) {
                if settings.intervalPresets.isEmpty {
                    Text(L10n.noSavedIntervalsYet)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(visiblePresets) { preset in
                        NavigationLink {
                            IntervalSetupView(
                                headerTitle: L10n.adjustSettings,
                                subtitle: preset.trimmedCustomTitle ?? L10n.presetCountSummary(preset.workoutPlan.distanceSegments.count),
                                initialWorkoutPlan: preset.workoutPlan,
                                initialCustomTitle: preset.customTitle,
                                initialStoredPresetID: preset.id,
                                showsCustomTitle: true,
                                autoSaveOnSegmentDone: true,
                                onContinue: { workoutPlan, customTitle, storedPresetID in
                                    _ = settings.saveIntervalPreset(
                                        workoutPlan,
                                        customTitle: customTitle,
                                        existingPresetID: storedPresetID ?? preset.id
                                    )
                                    settings.apply(workoutPlan: workoutPlan)
                                    coordinator.goToPreStart(replacingPath: true)
                                }
                            )
                        } label: {
                            IntervalLibraryRowView(
                                title: preset.displayTitle(unit: settings.distanceUnit),
                                subtitle: preset.workoutPlan.displayDetail(unit: settings.distanceUnit)
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                settings.deleteIntervalPreset(id: preset.id)
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                        .listRowBackground(Color.clear)
                    }

                    if hasMorePresets {
                        Button {
                            displayedPresetCount += 10
                        } label: {
                            Text(L10n.loadMore)
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .accentRoundedButtonChrome(accentColor: settings.primaryAccentColor, cornerRadius: 999)
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                    }
                }
            }

            Section(L10n.predefined) {
                ForEach(SettingsStore.predefinedIntervalPresets) { preset in
                    NavigationLink {
                        IntervalSetupView(
                            headerTitle: L10n.adjustSettings,
                            subtitle: preset.title,
                            initialWorkoutPlan: preset.workoutPlan,
                            initialCustomTitle: preset.title,
                            initialStoredPresetID: nil,
                            showsCustomTitle: true,
                            autoSaveOnSegmentDone: true,
                            onContinue: { workoutPlan, customTitle, storedPresetID in
                                let normalizedTitle = IntervalPreset.sanitizeTitle(customTitle)
                                if IntervalPresetSignature(workoutPlan: workoutPlan) != preset.signature || normalizedTitle != nil {
                                    _ = settings.saveIntervalPreset(
                                        workoutPlan,
                                        customTitle: normalizedTitle,
                                        existingPresetID: storedPresetID
                                    )
                                }
                                settings.apply(workoutPlan: workoutPlan)
                                coordinator.goToPreStart(replacingPath: true)
                            }
                        )
                    } label: {
                        IntervalLibraryRowView(
                            title: preset.title,
                            subtitle: preset.workoutPlan.displayDetail(unit: settings.distanceUnit)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                    .listRowBackground(Color.clear)
                }
            }
        }
        .tint(settings.primaryAccentColor)
        .listStyle(.carousel)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

private struct IntervalSetupView: View {
    @EnvironmentObject var settings: SettingsStore

    let headerTitle: String
    let subtitle: String?
    let initialWorkoutPlan: WorkoutPlanSnapshot
    let initialCustomTitle: String?
    let initialStoredPresetID: UUID?
    let showsCustomTitle: Bool
    let autoSaveOnSegmentDone: Bool
    let onContinue: (WorkoutPlanSnapshot, String?, UUID?) -> Void

    @State private var trackingMode: TrackingMode = .distanceDistance
    @State private var segments: [DistanceSegment] = []
    @State private var customTitle: String = ""
    @State private var storedPresetID: UUID?
    @State private var editingSegmentID: UUID?
    @State private var editingSegmentDistanceText: String = ""
    @State private var editingSegmentRepeatCount: Int = 0
    @State private var editingSegmentRestSeconds: Int = 0
    @State private var editingSegmentTargetPace: Int = 0
    @State private var editingSegmentTargetTime: Int = 0
    @State private var lastAddedDistanceMeters: Double = 400
    @State private var lastAddedRepeatCount: Int = 0
    @State private var lastAddedRestSeconds: Int = 0
    @State private var lastAddedTargetPace: Int = 0
    @State private var lastAddedTargetTime: Int = 0

    private var distanceLabel: String {
        switch settings.distanceUnit {
        case .km: return "Distance (m)"
        case .miles: return "Distance (ft)"
        }
    }

    private var isContinueDisabled: Bool {
        if trackingMode == .distanceDistance {
            return segments.isEmpty || segments.contains { $0.distanceMeters <= 0 }
        }
        return false
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .accentRoundedButtonChrome(accentColor: settings.primaryAccentColor, cornerRadius: 16)
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding(.horizontal, 6)

                if showsCustomTitle {
                    IntervalTitleField(text: $customTitle)
                }

                if trackingMode == .distanceDistance {
                    intervalsSection
                }

                Button(action: continueToGetReady) {
                    Text(L10n.continueToGetReady)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .disabled(isContinueDisabled)
                .opacity(isContinueDisabled ? 0.5 : 1)
                .padding(.top, 6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .tint(settings.primaryAccentColor)
        .background(Color.clear)
        .onAppear(perform: loadSnapshot)
        .sheet(isPresented: Binding(
            get: { editingSegmentID != nil },
            set: { if !$0 { commitSegmentEdit() } }
        )) {
            SegmentEditSheet(
                distanceText: $editingSegmentDistanceText,
                repeatCount: $editingSegmentRepeatCount,
                restSeconds: $editingSegmentRestSeconds,
                targetPace: $editingSegmentTargetPace,
                targetTime: $editingSegmentTargetTime,
                distanceLabel: distanceLabel,
                distanceUnit: settings.distanceUnit,
                accentColor: settings.primaryAccentColor,
                onDone: { commitSegmentEdit() }
            )
        }
    }

    private func loadSnapshot() {
        let snapshot = initialWorkoutPlan
        trackingMode = snapshot.trackingMode
        segments = snapshot.distanceSegments.isEmpty ? [.default] : snapshot.distanceSegments
        customTitle = initialCustomTitle ?? ""
        storedPresetID = initialStoredPresetID
        lastAddedDistanceMeters = segments.last?.distanceMeters ?? DistanceSegment.default.distanceMeters
        lastAddedRepeatCount = segments.last?.repeatCount ?? 0
        lastAddedRestSeconds = segments.last?.restSeconds ?? 0
        lastAddedTargetPace = Int(segments.last?.targetPaceSecondsPerKm ?? 0)
        lastAddedTargetTime = Int(segments.last?.targetTimeSeconds ?? 0)
    }

    private func normalizedSegments(_ input: [DistanceSegment]) -> [DistanceSegment] {
        guard input.count > 1 else { return input }

        var normalized = input
        for index in normalized.indices.dropLast() where normalized[index].repeatCount == nil {
            normalized[index].repeatCount = 1
        }
        return normalized
    }

    private func continueToGetReady() {
        let normalized = normalizedSegments(segments)
        let distance = normalized.first?.distanceMeters ?? initialWorkoutPlan.distanceLapDistanceMeters
        onContinue(
            WorkoutPlanSnapshot(
                trackingMode: trackingMode,
                distanceLapDistanceMeters: distance,
                distanceSegments: normalized,
                restMode: settings.restMode
            ),
            IntervalPreset.sanitizeTitle(customTitle),
            storedPresetID
        )
    }

    private func currentWorkoutPlan() -> WorkoutPlanSnapshot {
        let normalized = normalizedSegments(segments)
        let distance = normalized.first?.distanceMeters ?? initialWorkoutPlan.distanceLapDistanceMeters
        return WorkoutPlanSnapshot(
            trackingMode: trackingMode,
            distanceLapDistanceMeters: distance,
            distanceSegments: normalized,
            restMode: settings.restMode
        )
    }

    private func persistPresetAfterEditIfNeeded() {
        guard autoSaveOnSegmentDone, showsCustomTitle else { return }

        let savedPreset = settings.saveIntervalPreset(
            currentWorkoutPlan(),
            customTitle: customTitle,
            existingPresetID: storedPresetID
        )
        storedPresetID = savedPreset?.id ?? storedPresetID
        if let savedPreset {
            customTitle = savedPreset.customTitle ?? customTitle
        }
    }

    private func addSegment() {
        segments.append(
            DistanceSegment(
                distanceMeters: lastAddedDistanceMeters,
                repeatCount: lastAddedRepeatCount > 0 ? lastAddedRepeatCount : nil,
                restSeconds: lastAddedRestSeconds > 0 ? lastAddedRestSeconds : nil,
                targetPaceSecondsPerKm: lastAddedTargetPace > 0 ? Double(lastAddedTargetPace) : nil,
                targetTimeSeconds: lastAddedTargetTime > 0 ? Double(lastAddedTargetTime) : nil
            )
        )
        segments = normalizedSegments(segments)
    }

    private func deleteSegment(_ segment: DistanceSegment) {
        segments.removeAll { $0.id == segment.id }
        if segments.isEmpty {
            segments = [.default]
        }
        segments = normalizedSegments(segments)
    }

    private func beginEditingSegment(_ segment: DistanceSegment) {
        editingSegmentID = segment.id
        let displayDistance: Double
        switch settings.distanceUnit {
        case .km:
            displayDistance = segment.distanceMeters
        case .miles:
            displayDistance = segment.distanceMeters * 3.28084
        }
        editingSegmentDistanceText = displayDistance == floor(displayDistance)
            ? String(format: "%.0f", displayDistance)
            : String(format: "%g", displayDistance)
        editingSegmentRepeatCount = segment.repeatCount ?? 0
        editingSegmentRestSeconds = segment.restSeconds ?? 0
        editingSegmentTargetPace = Int(segment.targetPaceSecondsPerKm ?? 0)
        editingSegmentTargetTime = Int(segment.targetTimeSeconds ?? 0)
    }

    private func commitSegmentEdit() {
        guard let id = editingSegmentID,
              let index = segments.firstIndex(where: { $0.id == id }),
              let value = Double(editingSegmentDistanceText), value > 0 else {
            editingSegmentID = nil
            return
        }

        let meters: Double
        switch settings.distanceUnit {
        case .km:
            meters = value
        case .miles:
            meters = value / 3.28084
        }
        segments[index].distanceMeters = meters
        lastAddedDistanceMeters = meters
        lastAddedRepeatCount = editingSegmentRepeatCount
        lastAddedRestSeconds = editingSegmentRestSeconds
        lastAddedTargetPace = editingSegmentTargetPace
        lastAddedTargetTime = editingSegmentTargetTime
        segments[index].repeatCount = editingSegmentRepeatCount > 0 ? editingSegmentRepeatCount : nil
        segments[index].restSeconds = editingSegmentRestSeconds > 0 ? editingSegmentRestSeconds : nil
        segments[index].targetPaceSecondsPerKm = editingSegmentTargetPace > 0 ? Double(editingSegmentTargetPace) : nil
        segments[index].targetTimeSeconds = editingSegmentTargetTime > 0 ? Double(editingSegmentTargetTime) : nil
        editingSegmentID = nil
        segments = normalizedSegments(segments)
        persistPresetAfterEditIfNeeded()
    }
}

private struct IntervalLibraryRowView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.15))
        .cornerRadius(8)
    }
}

private struct IntervalTitleField: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 8)

            TextField("Title (optional)", text: $text)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 8)
        }
    }
}

private struct SegmentEditSheet: View {
    @Binding var distanceText: String
    @Binding var repeatCount: Int
    @Binding var restSeconds: Int
    @Binding var targetPace: Int
    @Binding var targetTime: Int
    let distanceLabel: String
    let distanceUnit: DistanceUnit
    let accentColor: Color
    let onDone: () -> Void

    private let defaultDistanceText = "400"

    private var repeatLabel: String {
        repeatCount > 0 ? "\(repeatCount)" : "∞"
    }

    private var restLabel: String {
        restSeconds > 0 ? "\(restSeconds)s" : L10n.restManual
    }

    private var paceLabel: String {
        targetPace > 0 ? Formatters.compactPaceString(secondsPerKm: Double(targetPace), unit: distanceUnit) : L10n.off
    }

    private var timeLabel: String {
        targetTime > 0 ? Formatters.compactTimeString(from: Double(targetTime)) : L10n.off
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                DistanceInputView(
                    label: distanceLabel,
                    accentColor: accentColor,
                    text: $distanceText
                )

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

                Text(L10n.pace)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    Button {
                        if targetPace >= 15 {
                            targetPace -= 5
                        } else {
                            targetPace = 0
                        }
                        if targetPace > 0 { targetTime = 0 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text(paceLabel)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )

                    Button {
                        if targetPace == 0 { targetPace = 300 }
                        else { targetPace += 5 }
                        targetTime = 0
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                Text(L10n.time)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    Button {
                        if targetTime >= 10 {
                            targetTime -= 5
                        } else {
                            targetTime = 0
                        }
                        if targetTime > 0 { targetPace = 0 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text(timeLabel)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )

                    Button {
                        if targetTime == 0 { targetTime = 90 }
                        else { targetTime += 5 }
                        targetPace = 0
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
                .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .onDisappear {
            if distanceText.isEmpty {
                distanceText = defaultDistanceText
            }
        }
        .scrollContentBackground(.hidden)
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
                .fill(baseColor.opacity(0.2))

            Circle()
                .stroke(baseColor.opacity(0.4), lineWidth: 3)
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

private struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct SettingsCardRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var value: String? = nil
    var showsChevron: Bool = false

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

                if let value {
                    Text(value)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer(minLength: 10)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private extension IntervalPreset {
    func displayTitle(unit: DistanceUnit) -> String {
        trimmedCustomTitle ?? workoutPlan.displayTitle(unit: unit)
    }
}

private extension WorkoutPlanSnapshot {
    func displayTitle(unit: DistanceUnit) -> String {
        let normalizedSegments = distanceSegments.isEmpty ? [DistanceSegment.default] : distanceSegments
        guard let firstSegment = normalizedSegments.first else { return Formatters.distanceString(meters: 400, unit: unit) }

        let distance = Formatters.distanceString(meters: firstSegment.distanceMeters, unit: unit)
        if normalizedSegments.count == 1, let repeatCount = firstSegment.repeatCount {
            return "\(repeatCount) × \(distance)"
        }
        if normalizedSegments.count == 1 {
            return distance
        }
        return "\(normalizedSegments.count) segments"
    }

    func displayDetail(unit: DistanceUnit) -> String {
        let normalizedSegments = distanceSegments.isEmpty ? [DistanceSegment.default] : distanceSegments
        let distanceSummary = normalizedSegments.map {
            let distance = Formatters.distanceString(meters: $0.distanceMeters, unit: unit)
            if let repeatCount = $0.repeatCount {
                return "\(repeatCount) × \(distance)"
            }
            return distance
        }
        .joined(separator: " • ")

        return distanceSummary
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
