import SwiftUI
import CoreLocation
import WatchKit

struct PreStartView: View {
    @EnvironmentObject var workoutController: WorkoutSessionController
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Environment(\.appTheme) private var theme
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
    @State private var isAppearanceModeDialogPresented = false
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
        case .km: return L10n.distanceMetersShort
        case .miles: return L10n.distanceFeetShort
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
        let smallFont = Font.system(size: Tokens.FontSize.sm, weight: .semibold, design: .rounded)
        let smallColor = theme.text.subtle

        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xxs) {
            if s < 60 {
                Text("\(s)")
                    .font(bigFont)
                    .monospacedDigit()
                    .foregroundStyle(theme.text.neutral)
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
                        .foregroundStyle(theme.text.neutral)
                    Text(L10n.minutesAbbrev)
                        .font(smallFont)
                        .foregroundStyle(smallColor)
                } else {
                    Text("\(m)")
                        .font(bigFont)
                        .monospacedDigit()
                        .foregroundStyle(theme.text.neutral)
                    Text(L10n.minutesAbbrev)
                        .font(smallFont)
                        .foregroundStyle(smallColor)
                    Text("\(secs)")
                        .font(bigFont)
                        .monospacedDigit()
                        .foregroundStyle(theme.text.neutral)
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
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            Text(L10n.intervalsTitle)
                .font(.caption.bold())
                .foregroundStyle(theme.text.subtle)
                .padding(.horizontal, Tokens.Spacing.md)

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
                HStack {
                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: Tokens.FontSize.xxxl, weight: .semibold))

                    Spacer()
                }
                .foregroundStyle(settings.primaryAccentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Spacing.xs)
            }
            .buttonStyle(.plain)
            .padding(.top, Tokens.Spacing.xxs)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                        readyTimerView

                        ReadyHeartIndicator(heartRateText: readyHeartRateText)
                    }
                    .offset(x: Tokens.Spacing.sm, y: Tokens.Spacing.md)

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
                    Text(L10n.pressActionButton)
                        .font(.system(size: Tokens.FontSize.sm, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.text.subtle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Tokens.Spacing.sm)
                        .padding(.bottom, Tokens.Spacing.xxs)
                }

                if settings.trackingMode.usesManualIntervals {
                    intervalsSection

                    Button {
                        coordinator.goToIntervalLibrary()
                    } label: {
                        SettingsCardRow(
                            icon: "square.grid.2x2",
                            title: L10n.browse,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Tokens.Spacing.xl)
                }

                Text(L10n.preferences)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.text.neutral)
                    .padding(.horizontal, Tokens.Spacing.sm)
                    .padding(.top, Tokens.Spacing.xl)

                Button {
                    isTrackingModeDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "location",
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
                        title: L10n.color,
                        value: settings.primaryColor.displayName
                    )
                }
                .buttonStyle(.plain)

                Button {
                    isAppearanceModeDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "circle.lefthalf.filled",
                        title: L10n.appearance,
                        value: settings.appearanceMode.displayName
                    )
                }
                .buttonStyle(.plain)

                Button {
                    isAlertsDialogPresented = true
                } label: {
                    SettingsCardRow(
                        icon: "bell.badge",
                        title: L10n.alerts,
                        value: alertsSummary
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.md)
            .id("prestart-top")
        }
        .tint(settings.primaryAccentColor)
        .background(Color.clear)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            proxy.scrollTo("prestart-top", anchor: .top)
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
        .confirmationDialog(L10n.restMode, isPresented: $isRestModeDialogPresented) {
            ForEach(RestMode.allCases) { mode in
                Button(mode.displayName) {
                    settings.restMode = mode
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
        .confirmationDialog(L10n.appearance, isPresented: $isAppearanceModeDialogPresented) {
            ForEach(AppearanceMode.allCases) { mode in
                Button(mode.displayName) {
                    settings.appearanceMode = mode
                }
            }
            Button(L10n.cancel, role: .cancel) {}
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
        } // ScrollViewReader
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
        segments.append(WorkoutPlanSupport.nextSegmentForAppend(from: segments))
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
    @Environment(\.appTheme) private var theme

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
            let repeatItem = SessionStatItem(label: L10n.repeats, value: String(count))
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
                VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                    Text(distanceDisplay)
                        .font(.system(size: Tokens.FontSize.xl, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.text.neutral)
                    if hasSecondaryDetails {
                        LazyVGrid(columns: detailColumns, alignment: .leading, spacing: Tokens.Spacing.md) {
                            ForEach(detailItems) { item in
                                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                                    Text(item.label)
                                        .font(.system(size: Tokens.FontSize.sm, weight: .regular, design: .rounded))
                                        .foregroundStyle(theme.text.subtle)

                                    Text(item.value)
                                        .font(.caption2)
                                        .foregroundStyle(theme.text.neutral)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Spacing.xxl)
                .padding(.vertical, Tokens.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.xxxl, style: .continuous)
                        .fill(theme.background.neutralInteraction)
                )
                .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.xxxl, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Tokens.FontSize.xl))
                    .foregroundStyle(theme.text.subtle)
            }
            .buttonStyle(.plain)
            .padding(.top, Tokens.Spacing.xl)
            .padding(.trailing, Tokens.Spacing.xxl)
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
    @Environment(\.appTheme) private var theme
    @State private var displayedPresetCount = 10

    private var visiblePresets: [IntervalPreset] {
        Array(settings.intervalPresets.prefix(displayedPresetCount))
    }

    private var hasMorePresets: Bool {
        settings.intervalPresets.count > displayedPresetCount
    }

    var body: some View {
        List {
            Section {
                if settings.intervalPresets.isEmpty {
                    Text(L10n.noSavedIntervalsYet)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Spacing.xxxxl)
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
                            Button {
                                settings.deleteIntervalPreset(id: preset.id)
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                                    .foregroundStyle(Color.white)
                            }
                            .tint(settings.primaryAccentColor)
                        }
                        .listRowInsets(Tokens.ListRowInsets.card)
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
                        .accentRoundedButtonChrome(accentColor: settings.primaryAccentColor, cornerRadius: Tokens.Radius.pill)
                        .buttonStyle(.plain)
                        .listRowInsets(Tokens.ListRowInsets.action)
                        .listRowBackground(Color.clear)
                    }
                }
            } header: {
                Text(L10n.myIntervals)
                    .foregroundStyle(theme.text.neutral)
            }

            Section {
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
                    .listRowInsets(Tokens.ListRowInsets.card)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text(L10n.predefined)
                    .foregroundStyle(theme.text.neutral)
                    .padding(.top, Tokens.Spacing.lg)
            }
        }
        .tint(settings.primaryAccentColor)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct IntervalSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.appTheme) private var theme

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
    @State private var isUseActivityConfirmationPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isActionMenuPresented = false
    @StateObject private var locationPermissionRequester = LocationPermissionRequester()

    private var distanceLabel: String {
        switch settings.distanceUnit {
        case .km: return L10n.distanceMetersShort
        case .miles: return L10n.distanceFeetShort
        }
    }

    private var isContinueDisabled: Bool {
        if trackingMode.usesManualIntervals {
            return segments.isEmpty || segments.contains { !$0.usesOpenDistance && $0.distanceMeters <= 0 }
        }
        return false
    }

    private var canDeletePreset: Bool {
        storedPresetID != nil
    }

    private var actionMenuTitle: String {
        subtitle ?? headerTitle
    }

    @ViewBuilder
    private var intervalsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            Text(L10n.intervalsTitle)
                .font(.caption.bold())
                .foregroundStyle(theme.text.subtle)
                .padding(.horizontal, Tokens.Spacing.md)

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
                HStack {
                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: Tokens.FontSize.xxxl, weight: .semibold))

                    Spacer()
                }
                .foregroundStyle(settings.primaryAccentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Spacing.xs)
            }
            .buttonStyle(.plain)
            .padding(.top, Tokens.Spacing.xxs)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                        Text(headerTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(theme.text.neutral)
                    }
                    .padding(.horizontal, Tokens.Spacing.sm)
                    .id("top")

                    if showsCustomTitle {
                        IntervalTitleField(text: $customTitle)
                    }

                    if trackingMode.usesManualIntervals {
                        intervalsSection
                    }
                }
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.vertical, Tokens.Spacing.md)
            }
        }
        .tint(settings.primaryAccentColor)
        .background(Color.clear)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isActionMenuPresented = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
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
        .alert(L10n.useActivityConfirmationTitle, isPresented: $isUseActivityConfirmationPresented) {
            Button(L10n.yes) {
                continueToGetReady()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.useActivityConfirmationMessage)
        }
        .alert(L10n.deletePlan, isPresented: $isDeleteConfirmationPresented) {
            Button(L10n.delete, role: .destructive) {
                deletePreset()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deletePlanConfirmMessage)
        }
        .confirmationDialog(actionMenuTitle, isPresented: $isActionMenuPresented) {
            Button(L10n.reusePlan) {
                isUseActivityConfirmationPresented = true
            }

            if canDeletePreset {
                Button(L10n.deletePlan, role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
            }

            Button(L10n.cancel, role: .cancel) {}
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

    private func deletePreset() {
        guard let storedPresetID else { return }
        settings.deleteIntervalPreset(id: storedPresetID)
        dismiss()
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
        segments.append(WorkoutPlanSupport.nextSegmentForAppend(from: segments))
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
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.text.neutral)
                Spacer()
                if usageCount > 0 {
                    PresetUsageBadge(count: usageCount)
                }
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(theme.text.subtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.md)
        .background(theme.background.neutral)
        .cornerRadius(Tokens.Radius.medium)
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
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(L10n.usedCount(count))
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.text.subtle)
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(theme.background.neutral)
            .clipShape(Capsule(style: .continuous))
    }
}

private struct IntervalTitleField: View {
    @Binding var text: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text(L10n.title)
                .font(.caption.bold())
                .foregroundStyle(theme.text.subtle)
                .padding(.horizontal, Tokens.Spacing.md)

            TextField(L10n.optionalTitlePlaceholder, text: $text)
                .textInputAutocapitalization(.words)
                .foregroundStyle(theme.text.neutral)
                .padding(.horizontal, Tokens.Spacing.md)
        }
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
    @Environment(\.appTheme) private var theme

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
    @State private var isLastRestInfoPresented = false
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

    private var canConfigureLastRest: Bool {
        SegmentEditSheetRules.canConfigureLastRest(repeatCount: repeatCount, restSeconds: restSeconds)
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
        ZStack {
            AppScreenBackground(accentColor: accentColor)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                    Text(L10n.distanceType)
                        .font(.caption.bold())
                        .foregroundStyle(theme.text.subtle)
                        .padding(.horizontal, Tokens.Spacing.xs)
                        .padding(.top, Tokens.Spacing.md)

                    HStack(spacing: Tokens.Spacing.md) {
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
                                usesSuccessTokens: true,
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
                    .font(.system(size: Tokens.FontSize.lg, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Spacing.xl)
                    .padding(.top, Tokens.Spacing.xs)
                }
                .padding(.horizontal, Tokens.Spacing.xl)
                .padding(.vertical, Tokens.Spacing.xl)
            }
        }
        .onDisappear {
            if distanceText.isEmpty {
                distanceText = defaultDistanceText
            }
        }
        .onAppear {
            syncLastRestWithRepeatCount(animated: false)
        }
        .onChange(of: repeatCount) { _, _ in
            syncLastRestWithRepeatCount()
        }
        .alert(L10n.lastRestNeedsRepeatsTitle, isPresented: $isLastRestInfoPresented) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.lastRestNeedsRepeatsMessage)
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
                .foregroundStyle(theme.text.subtle)
                .padding(.horizontal, Tokens.Spacing.xs)
                .padding(.top, Tokens.Spacing.xs)

            HStack(spacing: Tokens.Spacing.sm) {
                Button {
                    if repeatCount > 0 {
                        repeatCount -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: Tokens.FontSize.lg, weight: .bold))
                        .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                        .background(Circle().fill(theme.background.neutralAction))
                        .foregroundStyle(theme.text.neutral)
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
                        .font(.system(size: Tokens.FontSize.xxl, weight: .bold))
                        .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                        .background(Circle().fill(theme.background.neutralAction))
                        .foregroundStyle(theme.text.neutral)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var restSection: some View {
        Group {
            Text(L10n.rest)
                .font(.caption.bold())
                .foregroundStyle(theme.text.subtle)
                .padding(.horizontal, Tokens.Spacing.xs)
                .padding(.top, Tokens.Spacing.xs)

            HStack(spacing: Tokens.Spacing.sm) {
                Button {
                    if restSeconds >= 15 {
                        restSeconds -= 15
                    } else {
                        restSeconds = 0
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: Tokens.FontSize.lg, weight: .bold))
                        .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                        .background(Circle().fill(theme.background.neutralAction))
                        .foregroundStyle(theme.text.neutral)
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
                        .font(.system(size: Tokens.FontSize.xxl, weight: .bold))
                        .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                        .background(Circle().fill(theme.background.neutralAction))
                        .foregroundStyle(theme.text.neutral)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var lastRestSection: some View {
        if lastRestSeconds > 0 && canConfigureLastRest {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                Text(L10n.lastRest)
                    .font(.caption.bold())
                    .foregroundStyle(theme.text.subtle)
                    .padding(.horizontal, Tokens.Spacing.xs)
                    .padding(.top, Tokens.Spacing.xs)

                HStack(spacing: Tokens.Spacing.sm) {
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
                            .font(.system(size: Tokens.FontSize.lg, weight: .bold))
                            .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                            .background(Circle().fill(theme.background.neutralAction))
                            .foregroundStyle(theme.text.neutral)
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
                            .font(.system(size: Tokens.FontSize.xxl, weight: .bold))
                            .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                            .background(Circle().fill(theme.background.neutralAction))
                            .foregroundStyle(theme.text.neutral)
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
        let isActive = SegmentEditSheetRules.shouldShowAddLastRestButton(lastRestSeconds: lastRestSeconds)
        let isEnabled = canConfigureLastRest && isActive

        return Button {
            switch SegmentEditSheetRules.addLastRestAction(repeatCount: repeatCount) {
            case .addValue:
                withAnimation(.easeInOut(duration: 0.22)) {
                    lastRestSeconds = max(restSeconds, 15)
                }
            case .showRepeatsInfo:
                isLastRestInfoPresented = true
            }
        } label: {
            HStack(spacing: Tokens.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: Tokens.FontSize.lg, weight: .semibold))

                Text(L10n.addLastRest)
                    .font(.system(size: Tokens.FontSize.md, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(theme.text.neutral.opacity(isEnabled ? 1 : 0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                    .fill(theme.background.neutralAction)
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                            .stroke(theme.stroke.neutral, lineWidth: Tokens.LineWidth.thin)
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(height: isActive ? nil : 0, alignment: .top)
        .clipped()
        .opacity(isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.22), value: isActive)
    }

    private var paceTargetSection: some View {
        Group {
            Text(paceFieldTitle)
                .font(.caption.bold())
                .foregroundStyle(theme.text.subtle)
                .padding(.horizontal, Tokens.Spacing.xs)
                .padding(.top, Tokens.Spacing.md)

            HStack(spacing: Tokens.Spacing.sm) {
                Button {
                    if targetPace >= 15 {
                        targetPace -= 5
                    } else {
                        targetPace = 0
                    }
                    if targetPace > 0 { targetTime = 0 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: Tokens.FontSize.lg, weight: .bold))
                        .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                        .background(Circle().fill(theme.background.neutralAction))
                        .foregroundStyle(theme.text.neutral)
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
                        .font(.system(size: Tokens.FontSize.xxl, weight: .bold))
                        .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                        .background(Circle().fill(theme.background.neutralAction))
                        .foregroundStyle(theme.text.neutral)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timeTargetSection: some View {
        Group {
            Text(L10n.time)
                .font(.caption.bold())
                .foregroundStyle(theme.text.subtle)
                .padding(.horizontal, Tokens.Spacing.xs)
                .padding(.top, Tokens.Spacing.xs)

            HStack(spacing: Tokens.Spacing.sm) {
                Button {
                    if targetTime >= 10 {
                        targetTime -= 5
                    } else {
                        targetTime = 0
                    }
                    if targetTime > 0 { targetPace = 0 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: Tokens.FontSize.lg, weight: .bold))
                        .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                        .background(Circle().fill(theme.background.neutralAction))
                        .foregroundStyle(theme.text.neutral)
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
                        .font(.system(size: Tokens.FontSize.xxl, weight: .bold))
                        .frame(width: Tokens.ControlSize.inlineAdjustButton, height: Tokens.ControlSize.inlineAdjustButton)
                        .background(Circle().fill(theme.background.neutralAction))
                        .foregroundStyle(theme.text.neutral)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func editorValueField(_ text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                .fill(theme.background.neutralAction)

            Text(text)
                .font(.system(size: Tokens.FontSize.xl, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.text.neutral)
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
        isRestEditorPresented = false
    }

    private func commitLastRestEditorText() {
        lastRestSeconds = SegmentEditInputParser.parseDurationSeconds(from: lastRestEditorText)
        isLastRestEditorPresented = false
    }

    private func syncLastRestWithRepeatCount(animated: Bool = true) {
        let normalizedLastRest = SegmentEditSheetRules.normalizedLastRestSeconds(
            lastRestSeconds,
            repeatCount: repeatCount
        )

        guard normalizedLastRest != lastRestSeconds else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                lastRestSeconds = normalizedLastRest
            }
        } else {
            lastRestSeconds = normalizedLastRest
        }
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

struct TintedInfoBanner: View {
    let title: String
    let subtitle: String
    let tint: Color
    var usesSuccessTokens: Bool = false
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil
    @Environment(\.appTheme) private var theme

    private var titleColor: Color {
        usesSuccessTokens ? theme.text.success : tint
    }

    private var subtitleColor: Color {
        theme.text.neutral
    }

    private var buttonColor: Color {
        usesSuccessTokens ? theme.text.success : tint
    }

    private var backgroundColor: Color {
        usesSuccessTokens ? theme.background.success : tint.opacity(Tokens.Opacity.fillCard)
    }

    private var strokeColor: Color {
        usesSuccessTokens ? theme.stroke.success : theme.stroke.emphasis(tint)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                Text(title)
                    .font(.system(size: Tokens.FontSize.md, weight: .semibold, design: .rounded))
                    .foregroundStyle(titleColor)

                Text(subtitle)
                    .font(.system(size: Tokens.FontSize.sm, weight: .regular, design: .rounded))
                    .foregroundStyle(subtitleColor)
            }

            if let buttonTitle, let buttonAction {
                Button(buttonTitle, action: buttonAction)
                    .font(.system(size: Tokens.FontSize.md, weight: .semibold, design: .rounded))
                    .foregroundStyle(buttonColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.md)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                .stroke(strokeColor, lineWidth: Tokens.LineWidth.thin)
        )
        .cornerRadius(Tokens.Radius.medium)
    }
}

private struct ReadyHeartIndicator: View {
    let heartRateText: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Text(heartRateText)
                .font(.system(size: Tokens.FontSize.lg, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text.neutral)
                .monospacedDigit()

            Image(systemName: "heart.fill")
                .font(.system(size: Tokens.FontSize.xs, weight: .semibold))
                .foregroundStyle(theme.text.neutral)
        }
    }
}

private struct ReadyStartIcon: View {
    let baseColor: Color
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.background.emphasisAction(baseColor))

            Circle()
                .stroke(theme.stroke.emphasisAction(baseColor), lineWidth: Tokens.LineWidth.thick)
                .padding(Tokens.LineWidth.regular)
        }
        .overlay {
            Image(systemName: "play.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(theme.text.emphasis)
        }
        .frame(width: 78, height: 78)
        .shadow(color: baseColor.opacity(Tokens.Opacity.shadow), radius: Tokens.Radius.small, y: 2)
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
    let title: String
    var value: String? = nil
    var showsChevron: Bool = false
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Spacing.xxl) {
            Image(systemName: icon)
                .font(.system(size: Tokens.FontSize.xl, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(settings.primaryAccentColor)
                .frame(width: Tokens.FontSize.xl)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: Tokens.FontSize.xl, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.text.neutral)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)

                if let value {
                    Text(value)
                        .font(.system(size: Tokens.FontSize.lg, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.text.subtle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: Tokens.Spacing.sm)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: Tokens.FontSize.sm, weight: .semibold))
                    .foregroundStyle(theme.text.subtle)
            }
        }
        .padding(.horizontal, Tokens.Spacing.xxl)
        .padding(.vertical, Tokens.Spacing.xl)
        .background(theme.background.history)
        .cornerRadius(Tokens.Radius.medium)
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
