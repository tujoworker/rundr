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
    @State private var isAlertsDialogPresented = false
    @State private var editingSegmentID: UUID?
    @State private var editingSegmentDistanceText: String = ""
    @State private var editingSegmentUsesOpenDistance = false
    @State private var editingSegmentRepeatCount: Int = 0
    @State private var editingSegmentRestSeconds: Int = 0
    @State private var editingSegmentLastRestSeconds: Int = 0
    @State private var editingSegmentTargetPace: Int = 0
    @State private var editingSegmentTargetTime: Int = 0
    @State private var lastAddedDistanceMeters: Double = 400
    @State private var lastAddedUsesOpenDistance = false
    @State private var lastAddedRepeatCount: Int = 0
    @State private var lastAddedRestSeconds: Int = 0
    @State private var lastAddedLastRestSeconds: Int = 0
    @State private var lastAddedTargetPace: Int = 0
    @State private var lastAddedTargetTime: Int = 0
    @State private var showsOpenDistanceGPSBanner = false
    @State private var suppressNextGPSPermissionRequest = false
    @StateObject private var locationPermissionRequester = LocationPermissionRequester()

    private let readyTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var distanceLabel: String {
        switch settings.distanceUnit {
        case .km: return "Distance (m)"
        case .miles: return "Distance (ft)"
        }
    }

    private var alertsSummary: String {
        switch (settings.lapAlerts, settings.restAlerts) {
        case (true, true): return L10n.on
        case (false, false): return L10n.off
        case (true, false): return L10n.lapAlerts
        case (false, true): return L10n.restAlerts
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
        if settings.trackingMode.usesManualIntervals {
            return segments.isEmpty || segments.contains { !$0.usesOpenDistance && $0.distanceMeters <= 0 }
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
            Text(L10n.intervalsTitle)
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
                    Text(L10n.addInterval)
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

                if settings.trackingMode.usesManualIntervals {
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
                        title: L10n.unit,
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
                        title: L10n.color,
                        value: settings.primaryColor.displayName
                    )
                }
                .buttonStyle(.plain)

                Button {
                    isAlertsDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "bell.badge",
                        iconColor: .orange,
                        title: L10n.alerts,
                        value: alertsSummary
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .tint(settings.primaryAccentColor)
        .background(Color.clear)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            readyStartDate = Date()
            readyElapsedSeconds = 0
            segments = settings.distanceSegments
            lastAddedDistanceMeters = settings.distanceSegments.last?.distanceMeters ?? 400
            lastAddedUsesOpenDistance = settings.distanceSegments.last?.usesOpenDistance ?? false
            lastAddedRepeatCount = settings.distanceSegments.last?.repeatCount ?? 0
            lastAddedRestSeconds = settings.distanceSegments.last?.restSeconds ?? 0
            lastAddedLastRestSeconds = settings.distanceSegments.last?.lastRestSeconds ?? 0
            lastAddedTargetPace = Int(settings.distanceSegments.last?.targetPaceSecondsPerKm ?? 0)
            lastAddedTargetTime = Int(settings.distanceSegments.last?.targetTimeSeconds ?? 0)
            ensureDualModeForOpenDistanceSegments(showBanner: false)
            refreshHeartRate()
        }
        .onReceive(readyTimer) { currentDate in
            readyElapsedSeconds = Int(currentDate.timeIntervalSince(readyStartDate))

            guard readyElapsedSeconds == 0 || readyElapsedSeconds % 3 == 0 else { return }
            refreshHeartRate()
        }
        .onChange(of: settings.trackingMode) { _, newValue in
            guard newValue.usesGPSDistance else { return }
            if suppressNextGPSPermissionRequest {
                suppressNextGPSPermissionRequest = false
                return
            }
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
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(L10n.distanceUnit, isPresented: $isDistanceUnitDialogPresented) {
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
        .confirmationDialog(L10n.primaryColor, isPresented: $isPrimaryColorDialogPresented) {
            ForEach(PrimaryColorOption.allCases) { color in
                Button(color.displayName) {
                    settings.primaryColor = color
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isAlertsDialogPresented) {
            AlertsSettingsSheet(settings: settings)
        }
        .sheet(isPresented: Binding(
            get: { editingSegmentID != nil },
            set: { if !$0 { commitSegmentEdit() } }
        )) {
            SegmentEditSheet(
                distanceText: $editingSegmentDistanceText,
                usesOpenDistance: $editingSegmentUsesOpenDistance,
                repeatCount: $editingSegmentRepeatCount,
                restSeconds: $editingSegmentRestSeconds,
                lastRestSeconds: $editingSegmentLastRestSeconds,
                targetPace: $editingSegmentTargetPace,
                targetTime: $editingSegmentTargetTime,
                distanceLabel: distanceLabel,
                distanceUnit: settings.distanceUnit,
                accentColor: settings.primaryAccentColor,
                showsGPSInfoBanner: showsOpenDistanceGPSBanner,
                showsGPSPermissionButton: locationPermissionRequester.authorizationStatus == .notDetermined,
                onRequestLocationAccess: requestLocationPermissionIfNeeded,
                onDistanceModeChanged: handleEditingDistanceModeChanged,
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
        ensureDualModeForOpenDistanceSegments(showBanner: false)
        persistSegments()
        onStart()
    }

    private func addSegment() {
        segments.append(
            DistanceSegment(
                distanceMeters: lastAddedDistanceMeters,
                repeatCount: lastAddedRepeatCount > 0 ? lastAddedRepeatCount : nil,
                restSeconds: lastAddedRestSeconds > 0 ? lastAddedRestSeconds : nil,
                lastRestSeconds: lastAddedLastRestSeconds > 0 ? lastAddedLastRestSeconds : nil,
                distanceGoalMode: lastAddedUsesOpenDistance ? .open : .fixed,
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
        editingSegmentUsesOpenDistance = segment.usesOpenDistance
        let displayDist: Double
        switch settings.distanceUnit {
        case .km: displayDist = segment.distanceMeters
        case .miles: displayDist = segment.distanceMeters * 3.28084
        }
        editingSegmentDistanceText = displayDist == floor(displayDist) ? String(format: "%.0f", displayDist) : String(format: "%g", displayDist)
        editingSegmentRepeatCount = segment.repeatCount ?? 0
        editingSegmentRestSeconds = segment.restSeconds ?? 0
        editingSegmentLastRestSeconds = segment.lastRestSeconds ?? 0
        editingSegmentTargetPace = Int(segment.targetPaceSecondsPerKm ?? 0)
        editingSegmentTargetTime = Int(segment.targetTimeSeconds ?? 0)
        showsOpenDistanceGPSBanner = false
    }

    private func commitSegmentEdit() {
        guard let id = editingSegmentID,
              let idx = segments.firstIndex(where: { $0.id == id }) else {
            editingSegmentID = nil
            return
        }

        if !editingSegmentUsesOpenDistance {
            guard let value = Double(editingSegmentDistanceText), value > 0 else {
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
        }
        segments[idx].distanceGoalMode = editingSegmentUsesOpenDistance ? .open : .fixed
        lastAddedUsesOpenDistance = editingSegmentUsesOpenDistance
        lastAddedRepeatCount = editingSegmentRepeatCount
        lastAddedRestSeconds = editingSegmentRestSeconds
        lastAddedLastRestSeconds = editingSegmentLastRestSeconds
        lastAddedTargetPace = editingSegmentTargetPace
        lastAddedTargetTime = editingSegmentTargetTime
        segments[idx].repeatCount = editingSegmentRepeatCount > 0 ? editingSegmentRepeatCount : nil
        segments[idx].restSeconds = editingSegmentRestSeconds > 0 ? editingSegmentRestSeconds : nil
        segments[idx].lastRestSeconds = editingSegmentLastRestSeconds > 0 ? editingSegmentLastRestSeconds : nil
        segments[idx].targetPaceSecondsPerKm = editingSegmentTargetPace > 0 ? Double(editingSegmentTargetPace) : nil
        segments[idx].targetTimeSeconds = editingSegmentTargetTime > 0 ? Double(editingSegmentTargetTime) : nil
        editingSegmentID = nil
        ensureDualModeForOpenDistanceSegments(showBanner: false)
        persistSegments()
        showsOpenDistanceGPSBanner = false
    }

    private func handleEditingDistanceModeChanged(_ usesOpenDistance: Bool) {
        if usesOpenDistance {
            editingSegmentTargetPace = 0
        }
        ensureDualModeForOpenDistanceSegments(showBanner: usesOpenDistance)
    }

    private func ensureDualModeForOpenDistanceSegments(showBanner: Bool) {
        guard segments.contains(where: \.usesOpenDistance) || editingSegmentUsesOpenDistance else { return }
        guard settings.trackingMode == .distanceDistance else { return }
        suppressNextGPSPermissionRequest = true
        settings.trackingMode = .dual
        if showBanner {
            withAnimation(.easeOut(duration: 0.2)) {
                showsOpenDistanceGPSBanner = true
            }
        }
    }

    private func requestLocationPermissionIfNeeded() {
        Task { @MainActor in
            _ = await locationPermissionRequester.requestIfNeeded()
        }
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
    @State private var isDeleteConfirmationPresented = false

    private let detailColumns = [
        GridItem(.flexible(), spacing: 10, alignment: .topLeading),
        GridItem(.flexible(), spacing: 10, alignment: .topLeading)
    ]

    private var distanceDisplay: String {
        if segment.usesOpenDistance {
            return L10n.openDistance
        }
        return Formatters.distanceString(meters: segment.distanceMeters, unit: distanceUnit)
    }

    private var hasRepeatCount: Bool {
        segment.repeatCount != nil
    }

    private var hasRestDuration: Bool {
        segment.restSeconds != nil
    }

    private var hasLastRestDuration: Bool {
        segment.lastRestSeconds != nil
    }

    private var hasTarget: Bool {
        segment.effectiveTargetTimeSeconds != nil
    }

    private var hasSecondaryDetails: Bool {
        hasRepeatCount || hasRestDuration || hasLastRestDuration || hasTarget
    }

    private var detailItems: [SessionStatItem] {
        var items: [SessionStatItem] = []

        if let rest = segment.restSeconds {
            items.append(
                SessionStatItem(
                    label: L10n.rest,
                    value: Formatters.compactTimeString(from: Double(rest))
                )
            )
        }

        if let count = segment.repeatCount {
            let repeatItem = SessionStatItem(label: L10n.repeats, value: "×\(count)")
            if segment.usesOpenDistance {
                items.append(repeatItem)
            } else {
                items.insert(repeatItem, at: 0)
            }
        }

        if let lastRest = segment.lastRestSeconds {
            items.append(
                SessionStatItem(
                    label: L10n.lastRest,
                    value: Formatters.compactTimeString(from: Double(lastRest))
                )
            )
        }

        if let targetTime = segment.targetTimeSeconds {
            items.append(
                SessionStatItem(
                    label: L10n.targetTimeLabel,
                    value: Formatters.compactTimeString(from: targetTime)
                )
            )
        }

        if let targetPace = segment.targetPaceSecondsPerKm {
            items.append(
                SessionStatItem(
                    label: L10n.targetPaceLabel,
                    value: Formatters.compactPaceString(secondsPerKm: targetPace, unit: distanceUnit)
                )
            )
        }

        return items
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(distanceDisplay)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if hasSecondaryDetails {
                        LazyVGrid(columns: detailColumns, alignment: .leading, spacing: 8) {
                            ForEach(detailItems) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.label)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.55))

                                    Text(item.value)
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 14)
        }
        .alert(distanceDisplay, isPresented: $isDeleteConfirmationPresented) {
            Button(L10n.delete, role: .destructive, action: onDelete)
            Button(L10n.cancel, role: .cancel) {}
        }
    }
}

struct HistorySessionSetupView: View {
    let session: Session
    let onContinue: (WorkoutPlanSnapshot) -> Void

    private var sourceTitle: String {
        Formatters.historySessionDateTimeString(from: session.startedAt)
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
                                subtitle: preset.workoutPlan.displayDetail(unit: settings.distanceUnit),
                                usageCount: settings.presetUsageCount(for: preset.workoutPlan)
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
                            subtitle: preset.workoutPlan.displayDetail(unit: settings.distanceUnit),
                            usageCount: settings.presetUsageCount(for: preset.workoutPlan)
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
        .toolbar(.visible, for: .navigationBar)
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
    @State private var editingSegmentUsesOpenDistance = false
    @State private var editingSegmentRepeatCount: Int = 0
    @State private var editingSegmentRestSeconds: Int = 0
    @State private var editingSegmentLastRestSeconds: Int = 0
    @State private var editingSegmentTargetPace: Int = 0
    @State private var editingSegmentTargetTime: Int = 0
    @State private var lastAddedDistanceMeters: Double = 400
    @State private var lastAddedUsesOpenDistance = false
    @State private var lastAddedRepeatCount: Int = 0
    @State private var lastAddedRestSeconds: Int = 0
    @State private var lastAddedLastRestSeconds: Int = 0
    @State private var lastAddedTargetPace: Int = 0
    @State private var lastAddedTargetTime: Int = 0
    @State private var showsOpenDistanceGPSBanner = false
    @StateObject private var locationPermissionRequester = LocationPermissionRequester()

    private var distanceLabel: String {
        switch settings.distanceUnit {
        case .km: return "Distance (m)"
        case .miles: return "Distance (ft)"
        }
    }

    private var isContinueDisabled: Bool {
        if trackingMode.usesManualIntervals {
            return segments.isEmpty || segments.contains { !$0.usesOpenDistance && $0.distanceMeters <= 0 }
        }
        return false
    }

    @ViewBuilder
    private var intervalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.intervalsTitle)
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
                    Text(L10n.addInterval)
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

                if trackingMode.usesManualIntervals {
                    intervalsSection
                }

                Button(action: continueToGetReady) {
                    Text(L10n.useSessionSettings)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(isContinueDisabled)
                .opacity(isContinueDisabled ? 0.5 : 1)
                .padding(.top, 10)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .tint(settings.primaryAccentColor)
        .background(Color.clear)
        .toolbar(.visible, for: .navigationBar)
        .onAppear(perform: loadSnapshot)
        .sheet(isPresented: Binding(
            get: { editingSegmentID != nil },
            set: { if !$0 { commitSegmentEdit() } }
        )) {
            SegmentEditSheet(
                distanceText: $editingSegmentDistanceText,
                usesOpenDistance: $editingSegmentUsesOpenDistance,
                repeatCount: $editingSegmentRepeatCount,
                restSeconds: $editingSegmentRestSeconds,
                lastRestSeconds: $editingSegmentLastRestSeconds,
                targetPace: $editingSegmentTargetPace,
                targetTime: $editingSegmentTargetTime,
                distanceLabel: distanceLabel,
                distanceUnit: settings.distanceUnit,
                accentColor: settings.primaryAccentColor,
                showsGPSInfoBanner: showsOpenDistanceGPSBanner,
                showsGPSPermissionButton: locationPermissionRequester.authorizationStatus == .notDetermined,
                onRequestLocationAccess: requestLocationPermissionIfNeeded,
                onDistanceModeChanged: handleEditingDistanceModeChanged,
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
        lastAddedUsesOpenDistance = segments.last?.usesOpenDistance ?? false
        lastAddedRepeatCount = segments.last?.repeatCount ?? 0
        lastAddedRestSeconds = segments.last?.restSeconds ?? 0
        lastAddedLastRestSeconds = segments.last?.lastRestSeconds ?? 0
        lastAddedTargetPace = Int(segments.last?.targetPaceSecondsPerKm ?? 0)
        lastAddedTargetTime = Int(segments.last?.targetTimeSeconds ?? 0)
        ensureDualModeForOpenDistanceSegments(showBanner: false)
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
        ensureDualModeForOpenDistanceSegments(showBanner: false)
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
                lastRestSeconds: lastAddedLastRestSeconds > 0 ? lastAddedLastRestSeconds : nil,
                distanceGoalMode: lastAddedUsesOpenDistance ? .open : .fixed,
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
        editingSegmentUsesOpenDistance = segment.usesOpenDistance
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
        editingSegmentLastRestSeconds = segment.lastRestSeconds ?? 0
        editingSegmentTargetPace = Int(segment.targetPaceSecondsPerKm ?? 0)
        editingSegmentTargetTime = Int(segment.targetTimeSeconds ?? 0)
        showsOpenDistanceGPSBanner = false
    }

    private func commitSegmentEdit() {
        guard let id = editingSegmentID,
              let index = segments.firstIndex(where: { $0.id == id }) else {
            editingSegmentID = nil
            return
        }

        if !editingSegmentUsesOpenDistance {
            guard let value = Double(editingSegmentDistanceText), value > 0 else {
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
        }
        segments[index].distanceGoalMode = editingSegmentUsesOpenDistance ? .open : .fixed
        lastAddedUsesOpenDistance = editingSegmentUsesOpenDistance
        lastAddedRepeatCount = editingSegmentRepeatCount
        lastAddedRestSeconds = editingSegmentRestSeconds
        lastAddedLastRestSeconds = editingSegmentLastRestSeconds
        lastAddedTargetPace = editingSegmentTargetPace
        lastAddedTargetTime = editingSegmentTargetTime
        segments[index].repeatCount = editingSegmentRepeatCount > 0 ? editingSegmentRepeatCount : nil
        segments[index].restSeconds = editingSegmentRestSeconds > 0 ? editingSegmentRestSeconds : nil
        segments[index].lastRestSeconds = editingSegmentLastRestSeconds > 0 ? editingSegmentLastRestSeconds : nil
        segments[index].targetPaceSecondsPerKm = editingSegmentTargetPace > 0 ? Double(editingSegmentTargetPace) : nil
        segments[index].targetTimeSeconds = editingSegmentTargetTime > 0 ? Double(editingSegmentTargetTime) : nil
        editingSegmentID = nil
        ensureDualModeForOpenDistanceSegments(showBanner: false)
        segments = normalizedSegments(segments)
        persistPresetAfterEditIfNeeded()
        showsOpenDistanceGPSBanner = false
    }

    private func handleEditingDistanceModeChanged(_ usesOpenDistance: Bool) {
        if usesOpenDistance {
            editingSegmentTargetPace = 0
        }
        ensureDualModeForOpenDistanceSegments(showBanner: usesOpenDistance)
    }

    private func ensureDualModeForOpenDistanceSegments(showBanner: Bool) {
        guard segments.contains(where: \.usesOpenDistance) || editingSegmentUsesOpenDistance else { return }
        guard trackingMode == .distanceDistance else { return }
        trackingMode = .dual
        if showBanner {
            withAnimation(.easeOut(duration: 0.2)) {
                showsOpenDistanceGPSBanner = true
            }
        }
    }

    private func requestLocationPermissionIfNeeded() {
        Task { @MainActor in
            _ = await locationPermissionRequester.requestIfNeeded()
        }
    }
}

private struct IntervalLibraryRowView: View {
    let title: String
    let subtitle: String
    var usageCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if usageCount > 0 {
                    PresetUsageBadge(count: usageCount)
                }
            }
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

private struct AlertsSettingsSheet: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        List {
            Toggle(L10n.lapAlerts, isOn: $settings.lapAlerts)
            Toggle(L10n.restAlerts, isOn: $settings.restAlerts)
        }
        .navigationTitle(L10n.alerts)
        .tint(settings.primaryAccentColor)
    }
}

private struct PresetUsageBadge: View {
    let count: Int

    var body: some View {
        Text(L10n.usedCount(count))
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.white.opacity(0.12))
            .clipShape(Capsule(style: .continuous))
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

            TextField(L10n.optionalTitlePlaceholder, text: $text)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 8)
        }
    }
}

enum SegmentEditSheetSection: Hashable {
    case timeTarget
    case rest
    case lastRest
    case repeats
    case paceTarget

    static func orderedSections(for usesOpenDistance: Bool) -> [SegmentEditSheetSection] {
        if usesOpenDistance {
            return [.timeTarget, .rest, .lastRest, .repeats]
        }

        return [.rest, .lastRest, .repeats, .paceTarget, .timeTarget]
    }
}

private struct SegmentEditSheet: View {
    @Binding var distanceText: String
    @Binding var usesOpenDistance: Bool
    @Binding var repeatCount: Int
    @Binding var restSeconds: Int
    @Binding var lastRestSeconds: Int
    @Binding var targetPace: Int
    @Binding var targetTime: Int
    let distanceLabel: String
    let distanceUnit: DistanceUnit
    let accentColor: Color
    let showsGPSInfoBanner: Bool
    let showsGPSPermissionButton: Bool
    let onRequestLocationAccess: () -> Void
    let onDistanceModeChanged: (Bool) -> Void
    let onDone: () -> Void

    private let defaultDistanceText = "400"
    private let durationKeypadRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [":", "0", "⌫"]
    ]
    private let repeatKeypadRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["∞", "0", "⌫"]
    ]

    @State private var isRepeatEditorPresented = false
    @State private var isPaceEditorPresented = false
    @State private var isRestEditorPresented = false
    @State private var isLastRestEditorPresented = false
    @State private var isTimeEditorPresented = false
    @State private var repeatEditorText = ""
    @State private var paceEditorText = ""
    @State private var restEditorText = ""
    @State private var lastRestEditorText = ""
    @State private var timeEditorText = ""

    private var repeatLabel: String {
        repeatCount > 0 ? "\(repeatCount)" : "∞"
    }

    private var restLabel: String {
        restSeconds > 0 ? Formatters.compactTimeString(from: Double(restSeconds)) : L10n.restManual
    }

    private var lastRestLabel: String {
        lastRestSeconds > 0 ? Formatters.compactTimeString(from: Double(lastRestSeconds)) : L10n.restManual
    }

    private var paceUnitLabel: String {
        distanceUnit == .km ? L10n.pacePerKm : L10n.pacePerMi
    }

    private var paceFieldTitle: String {
        "\(L10n.pace) (\(paceUnitLabel))"
    }

    private var paceLabel: String {
        guard targetPace > 0 else { return L10n.off }
        let secondsPerUnit = distanceUnit == .km ? Double(targetPace) : Double(targetPace) * 1.60934
        return Formatters.compactTimeString(from: secondsPerUnit)
    }

    private var timeLabel: String {
        targetTime > 0 ? Formatters.compactTimeString(from: Double(targetTime)) : L10n.off
    }

    private var orderedSections: [SegmentEditSheetSection] {
        SegmentEditSheetSection.orderedSections(for: usesOpenDistance)
    }

    @ViewBuilder
    private func sectionView(_ section: SegmentEditSheetSection) -> some View {
        switch section {
        case .timeTarget:
            timeTargetSection
        case .rest:
            restSection
        case .lastRest:
            lastRestSection
        case .repeats:
            repeatsSection
        case .paceTarget:
            paceTargetSection
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.distanceType)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                HStack(spacing: 8) {
                    distanceModeButton(title: L10n.fixedDistance, isSelected: !usesOpenDistance) {
                        usesOpenDistance = false
                        onDistanceModeChanged(false)
                    }
                    distanceModeButton(title: L10n.openDistance, isSelected: usesOpenDistance) {
                        usesOpenDistance = true
                        onDistanceModeChanged(true)
                    }
                }

                if usesOpenDistance {
                    if showsGPSInfoBanner {
                        TintedInfoBanner(
                            title: L10n.gpsAlsoEnabledTitle,
                            subtitle: L10n.gpsAlsoEnabledSubtitle,
                            tint: .green,
                            buttonTitle: showsGPSPermissionButton ? L10n.requestLocationAccess : nil,
                            buttonAction: showsGPSPermissionButton ? onRequestLocationAccess : nil
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                } else {
                    DistanceInputView(
                        label: distanceLabel,
                        accentColor: accentColor,
                        text: $distanceText
                    )
                }

                ForEach(orderedSections, id: \.self) { section in
                    sectionView(section)
                }

                Button(L10n.done) {
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
        .sheet(isPresented: Binding(
            get: { isRepeatEditorPresented },
            set: { presented in
                if !presented {
                    commitRepeatEditorText()
                } else {
                    isRepeatEditorPresented = true
                }
            }
        )) {
            NumericKeypadEditorScreen(
                title: L10n.repeats,
                accentColor: accentColor,
                keypadRows: repeatKeypadRows,
                text: $repeatEditorText,
                onTapKey: repeatFieldTapKey,
                onDone: {
                    commitRepeatEditorText()
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: Binding(
            get: { isRestEditorPresented },
            set: { presented in
                if !presented {
                    commitRestEditorText()
                } else {
                    isRestEditorPresented = true
                }
            }
        )) {
            NumericKeypadEditorScreen(
                title: L10n.rest,
                accentColor: accentColor,
                keypadRows: durationKeypadRows,
                text: $restEditorText,
                onTapKey: durationFieldTapKey,
                onDone: {
                    commitRestEditorText()
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: Binding(
            get: { isLastRestEditorPresented },
            set: { presented in
                if !presented {
                    commitLastRestEditorText()
                } else {
                    isLastRestEditorPresented = true
                }
            }
        )) {
            NumericKeypadEditorScreen(
                title: L10n.lastRest,
                accentColor: accentColor,
                keypadRows: durationKeypadRows,
                text: $lastRestEditorText,
                onTapKey: durationFieldTapKey,
                onDone: {
                    commitLastRestEditorText()
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: Binding(
            get: { isPaceEditorPresented },
            set: { presented in
                if !presented {
                    commitPaceEditorText()
                } else {
                    isPaceEditorPresented = true
                }
            }
        )) {
            NumericKeypadEditorScreen(
                title: paceFieldTitle,
                accentColor: accentColor,
                keypadRows: durationKeypadRows,
                text: $paceEditorText,
                onTapKey: durationFieldTapKey,
                onDone: {
                    commitPaceEditorText()
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: Binding(
            get: { isTimeEditorPresented },
            set: { presented in
                if !presented {
                    commitTimeEditorText()
                } else {
                    isTimeEditorPresented = true
                }
            }
        )) {
            NumericKeypadEditorScreen(
                title: L10n.time,
                accentColor: accentColor,
                keypadRows: durationKeypadRows,
                text: $timeEditorText,
                onTapKey: durationFieldTapKey,
                onDone: {
                    commitTimeEditorText()
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var repeatsSection: some View {
        Group {
            Text(L10n.repeats)
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

                Button {
                    repeatEditorText = repeatCount > 0 ? "\(repeatCount)" : ""
                    isRepeatEditorPresented = true
                } label: {
                    editorValueField(repeatLabel)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)

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
        }
    }

    private var restSection: some View {
        Group {
            Text(L10n.rest)
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
                    if restSeconds <= 0 {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            lastRestSeconds = 0
                        }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    restEditorText = restSeconds > 0 ? restLabel : ""
                    isRestEditorPresented = true
                } label: {
                    editorValueField(restSeconds > 0 ? restLabel : L10n.restManual)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)

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
        }
    }

    @ViewBuilder
    private var lastRestSection: some View {
        if lastRestSeconds > 0 && restSeconds > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.lastRest)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            if lastRestSeconds >= 15 {
                                lastRestSeconds -= 15
                            } else {
                                lastRestSeconds = 0
                            }
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        lastRestEditorText = lastRestSeconds > 0 ? lastRestLabel : ""
                        isLastRestEditorPresented = true
                    } label: {
                        editorValueField(lastRestSeconds > 0 ? lastRestLabel : L10n.restManual)
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            lastRestSeconds += 15
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }

        addLastRestButton
    }

    private var addLastRestButton: some View {
        let isActive = lastRestSeconds <= 0 || restSeconds <= 0
        let isEnabled = restSeconds > 0 && lastRestSeconds <= 0

        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                lastRestSeconds = max(restSeconds, 15)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text(L10n.addLastRest)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.3))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(isEnabled ? 0.12 : 0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(height: isActive ? nil : 0, alignment: .top)
        .clipped()
        .opacity(isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.22), value: isActive)
    }

    private var paceTargetSection: some View {
        Group {
            Text(paceFieldTitle)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 4)
                .padding(.top, 8)

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

                Button {
                    paceEditorText = targetPace > 0 ? paceLabel : ""
                    isPaceEditorPresented = true
                } label: {
                    editorValueField(targetPace > 0 ? paceLabel : L10n.off)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)

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
        }
    }

    private var timeTargetSection: some View {
        Group {
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

                Button {
                    timeEditorText = targetTime > 0 ? timeLabel : ""
                    isTimeEditorPresented = true
                } label: {
                    editorValueField(targetTime > 0 ? timeLabel : L10n.off)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)

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
        }
    }

    private func editorValueField(_ text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.12))

            Text(text)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
    }

    private func commitPaceEditorText() {
        targetPace = SegmentEditInputParser.parseDurationSeconds(from: paceEditorText)
        if targetPace > 0 {
            targetTime = 0
        }
        isPaceEditorPresented = false
    }

    private func commitRepeatEditorText() {
        repeatCount = SegmentEditInputParser.parseRepeatCount(from: repeatEditorText)
        isRepeatEditorPresented = false
    }

    private func commitRestEditorText() {
        restSeconds = SegmentEditInputParser.parseDurationSeconds(from: restEditorText)
        if restSeconds <= 0 {
            withAnimation(.easeInOut(duration: 0.22)) {
                lastRestSeconds = 0
            }
        }
        isRestEditorPresented = false
    }

    private func commitLastRestEditorText() {
        lastRestSeconds = SegmentEditInputParser.parseDurationSeconds(from: lastRestEditorText)
        isLastRestEditorPresented = false
    }

    private func commitTimeEditorText() {
        targetTime = SegmentEditInputParser.parseDurationSeconds(from: timeEditorText)
        if targetTime > 0 {
            targetPace = 0
        }
        isTimeEditorPresented = false
    }

    private func distanceModeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        SelectionToggleButton(title: title, isSelected: isSelected, action: action)
    }
}

private func durationFieldTapKey(_ key: String, text: inout String) {
    SegmentEditInputParser.applyDurationKey(key, to: &text)
}

private func repeatFieldTapKey(_ key: String, text: inout String) {
    SegmentEditInputParser.applyRepeatKey(key, to: &text)
}

enum SegmentEditInputParser {
    static func parseRepeatCount(from value: String) -> Int {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmedValue) ?? 0
    }

    static func parseDurationSeconds(from value: String) -> Int {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return 0 }

        let components = trimmedValue.split(separator: ":", omittingEmptySubsequences: false)

        if components.count == 1 {
            return Int(components[0]) ?? 0
        }

        guard components.count <= 3 else { return 0 }
        guard components.allSatisfy({ !$0.isEmpty && Int($0) != nil }) else { return 0 }

        let values = components.compactMap { Int($0) }
        guard values.count == components.count else { return 0 }
        guard values.dropFirst().allSatisfy({ $0 < 60 }) else { return 0 }

        return values.reversed().enumerated().reduce(0) { partialResult, pair in
            let (index, component) = pair
            return partialResult + component * Int(pow(60.0, Double(index)))
        }
    }

    static func applyDurationKey(_ key: String, to text: inout String) {
        if key == "⌫" {
            if !text.isEmpty {
                text.removeLast()
            }
            return
        }

        if key == ":" {
            guard !text.isEmpty, !text.hasSuffix(":"), text.filter({ $0 == ":" }).count < 2 else { return }
            text += key
            return
        }

        if text == "0" {
            text = key
        } else {
            text += key
        }
    }

    static func applyRepeatKey(_ key: String, to text: inout String) {
        if key == "⌫" {
            if !text.isEmpty {
                text.removeLast()
            }
            return
        }

        if key == "∞" {
            text = ""
            return
        }

        if text == "0" {
            text = key
        } else {
            text += key
        }
    }
}

struct TintedInfoBanner: View {
    let title: String
    let subtitle: String
    let tint: Color
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)

                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }

            if let buttonTitle, let buttonAction {
                Button(buttonTitle, action: buttonAction)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(tint.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.32), lineWidth: 1)
        )
        .cornerRadius(8)
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

        let distance = firstSegment.usesOpenDistance
            ? L10n.openDistance
            : Formatters.distanceString(meters: firstSegment.distanceMeters, unit: unit)
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
            let distance = $0.usesOpenDistance
                ? L10n.openDistance
                : Formatters.distanceString(meters: $0.distanceMeters, unit: unit)
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
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    @MainActor
    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
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
        authorizationStatus = manager.authorizationStatus
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
