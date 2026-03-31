import SwiftData
import SwiftUI

struct CompanionRootView: View {
    var body: some View {
        TabView {
            CompanionWorkoutsView()
                .tabItem {
                    Label(L10n.workouts, systemImage: "figure.run")
                }

            CompanionBrowserView()
                .tabItem {
                    Label(L10n.browser, systemImage: "square.grid.2x2")
                }

            CompanionSettingsView()
                .tabItem {
                    Label(L10n.settings, systemImage: "paintpalette")
                }
        }
    }
}

private struct CompanionWorkoutsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var syncManager: WatchConnectivitySyncManager
    @Environment(\.appTheme) private var theme
    @Query(sort: [SortDescriptor(\Session.startedAt, order: .reverse)]) private var sessions: [Session]

    private var visibleLiveWorkoutState: LiveWorkoutStateRecord? {
        guard let state = syncManager.liveWorkoutState,
              !state.isTerminalState,
              sessions.contains(where: { $0.id == state.sessionID }) == false else {
            return nil
        }

        return state
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CompanionWorkoutEditorView(
                            headerTitle: L10n.workoutPlan,
                            subtitle: L10n.usedWhenStartingOnAppleWatch,
                            initialWorkoutPlan: settings.currentWorkoutPlan,
                            initialCustomTitle: nil,
                            initialStoredPresetID: nil,
                            showsCustomTitle: false,
                            autoSaveOnSegmentDone: false
                        ) { workoutPlan, _, _ in
                            settings.apply(workoutPlan: workoutPlan)
                        }
                    } label: {
                        CompanionCurrentWorkoutCard()
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: Tokens.Spacing.md, leading: Tokens.Spacing.xl, bottom: Tokens.Spacing.md, trailing: Tokens.Spacing.xl))
                    .listRowBackground(Color.clear)
                }

                if let liveWorkoutState = visibleLiveWorkoutState {
                    Section(L10n.liveOnAppleWatch) {
                        CompanionLiveWorkoutCard(state: liveWorkoutState)
                            .listRowCardChrome()
                    }
                }

                Section(L10n.syncedSessions) {
                    if sessions.isEmpty {
                        Text(L10n.noSyncedSessionsYet)
                            .foregroundStyle(theme.text.subtle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listRowCardChrome()
                    } else {
                        ForEach(sessions, id: \.id) { session in
                            NavigationLink {
                                CompanionSessionDetailView(session: session)
                            } label: {
                                CompanionSessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                            .listRowCardChrome()
                        }
                    }
                }
            }
            .navigationTitle("Rundr")
            .themedCompanionList()
        }
    }
}

private struct CompanionBrowserView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.myIntervals) {
                    if settings.intervalPresets.isEmpty {
                        Text(L10n.noSavedIntervalsYet)
                            .foregroundStyle(theme.text.subtle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listRowCardChrome()
                    } else {
                        ForEach(settings.intervalPresets) { preset in
                            NavigationLink {
                                CompanionWorkoutEditorView(
                                    headerTitle: L10n.adjustSettings,
                                    subtitle: preset.trimmedCustomTitle ?? L10n.presetCountSummary(preset.workoutPlan.distanceSegments.count),
                                    initialWorkoutPlan: preset.workoutPlan,
                                    initialCustomTitle: preset.customTitle,
                                    initialStoredPresetID: preset.id,
                                    showsCustomTitle: true,
                                    autoSaveOnSegmentDone: true
                                ) { workoutPlan, customTitle, storedPresetID in
                                    _ = settings.saveIntervalPreset(
                                        workoutPlan,
                                        customTitle: customTitle,
                                        existingPresetID: storedPresetID ?? preset.id
                                    )
                                    settings.apply(workoutPlan: workoutPlan)
                                }
                            } label: {
                                CompanionPresetRowView(
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
                                .tint(theme.background.swipeAction(settings.primaryAccentColor))
                            }
                            .listRowCardChrome()
                        }
                    }
                }

                Section(L10n.predefined) {
                    ForEach(SettingsStore.predefinedIntervalPresets) { preset in
                        NavigationLink {
                            CompanionWorkoutEditorView(
                                headerTitle: L10n.adjustSettings,
                                subtitle: preset.title,
                                initialWorkoutPlan: preset.workoutPlan,
                                initialCustomTitle: preset.title,
                                initialStoredPresetID: nil,
                                showsCustomTitle: true,
                                autoSaveOnSegmentDone: true
                            ) { workoutPlan, customTitle, storedPresetID in
                                let normalizedTitle = IntervalPreset.sanitizeTitle(customTitle)
                                if IntervalPresetSignature(workoutPlan: workoutPlan) != preset.signature || normalizedTitle != nil {
                                    _ = settings.saveIntervalPreset(
                                        workoutPlan,
                                        customTitle: normalizedTitle,
                                        existingPresetID: storedPresetID
                                    )
                                }
                                settings.apply(workoutPlan: workoutPlan)
                            }
                        } label: {
                            CompanionPresetRowView(
                                title: preset.title,
                                subtitle: preset.workoutPlan.displayDetail(unit: settings.distanceUnit),
                                usageCount: settings.presetUsageCount(for: preset.workoutPlan)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowCardChrome()
                    }
                }
            }
            .navigationTitle(L10n.browser)
            .themedCompanionList()
        }
    }
}

private struct CompanionSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.color) {
                    ForEach(PrimaryColorOption.allCases) { color in
                        Button {
                            settings.primaryColor = color
                        } label: {
                            HStack(spacing: Tokens.Spacing.md) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 18, height: 18)

                                Text(color.displayName)
                                    .foregroundStyle(theme.text.neutral)

                                Spacer()

                                if settings.primaryColor == color {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(settings.primaryAccentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowCardChrome()
                    }
                }

                Section(L10n.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button {
                            settings.appearanceMode = mode
                        } label: {
                            HStack {
                                Text(mode.displayName)
                                    .foregroundStyle(theme.text.neutral)

                                Spacer()

                                if settings.appearanceMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(settings.primaryAccentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowCardChrome()
                    }
                }
            }
            .navigationTitle(L10n.settings)
            .themedCompanionList()
        }
    }
}

private struct CompanionCurrentWorkoutCard: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            HStack(alignment: .top, spacing: Tokens.Spacing.md) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text(L10n.currentWorkout)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.neutral)

                    Text(L10n.usedWhenStartingOnAppleWatch)
                        .font(.subheadline)
                        .foregroundStyle(theme.text.subtle)
                }

                Spacer(minLength: Tokens.Spacing.md)

                Image(systemName: "chevron.right")
                    .font(.system(size: Tokens.FontSize.md, weight: .semibold))
                    .foregroundStyle(theme.text.subtle)
            }

            Text(settings.currentWorkoutPlan.displayTitle(unit: settings.distanceUnit))
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.text.neutral)

            Text(settings.currentWorkoutPlan.displayDetail(unit: settings.distanceUnit))
                .font(.subheadline)
                .foregroundStyle(theme.text.subtle)

            HStack(spacing: Tokens.Spacing.xl) {
                CompanionMetricPill(title: L10n.mode, value: settings.trackingMode.displayName)
                CompanionMetricPill(title: L10n.restMode, value: settings.restMode.displayName)
                CompanionMetricPill(title: L10n.unit, value: settings.distanceUnit.displayName)
            }
        }
        .companionCardChrome()
    }
}

private struct CompanionMetricPill: View {
    let title: String
    let value: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.text.subtle)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.text.neutral)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompanionPresetRowView: View {
    let title: String
    let subtitle: String
    let usageCount: Int
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.text.neutral)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(theme.text.subtle)
            }

            Spacer(minLength: Tokens.Spacing.md)

            if usageCount > 0 {
                Text(L10n.usedCount(usageCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.text.subtle)
            }
        }
        .companionCardChrome()
    }
}

private struct CompanionWorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsStore
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
    @State private var restMode: RestMode = .manual
    @State private var distanceUnit: DistanceUnit = .km
    @State private var segments: [DistanceSegment] = []
    @State private var customTitle: String = ""
    @State private var storedPresetID: UUID?
    @State private var editingSegment: DistanceSegment?
    @State private var showsOpenDistanceBanner = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text(headerTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.neutral)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(theme.text.subtle)
                    }
                }
                .companionCardChrome()
            }

            if showsCustomTitle {
                Section(L10n.title) {
                    TextField(L10n.optionalTitlePlaceholder, text: $customTitle)
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(theme.text.neutral)
                        .listRowCardChrome()
                }
            }

            Section(L10n.mode) {
                Picker(L10n.mode, selection: $trackingMode) {
                    ForEach(TrackingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .listRowCardChrome()

                Picker(L10n.restMode, selection: $restMode) {
                    ForEach(RestMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .listRowCardChrome()

                Picker(L10n.unit, selection: $distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .listRowCardChrome()
            }

            if trackingMode.usesManualIntervals {
                Section(L10n.intervalsTitle) {
                    ForEach(segments) { segment in
                        Button {
                            editingSegment = segment
                        } label: {
                            CompanionSegmentRow(segment: segment, distanceUnit: distanceUnit)
                        }
                        .buttonStyle(.plain)
                        .listRowCardChrome()
                    }
                    .onDelete(perform: deleteSegments)

                    Button {
                        addSegment()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(L10n.addInterval)
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.emphasis)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Spacing.md)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                            .fill(theme.background.emphasisAction(settings.primaryAccentColor))
                    )
                }
            }

            if showsOpenDistanceBanner {
                Section {
                    Text(L10n.gpsAlsoEnabledSubtitle)
                        .foregroundStyle(theme.text.subtle)
                        .listRowCardChrome()
                }
            }
        }
        .navigationTitle(headerTitle)
        .themedCompanionList()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.done) {
                    commitWorkoutPlan()
                }
            }
        }
        .onAppear(perform: loadSnapshot)
        .sheet(item: $editingSegment) { segment in
            CompanionSegmentEditorView(
                segment: segment,
                distanceUnit: distanceUnit
            ) { updatedSegment in
                commitSegment(updatedSegment)
            }
        }
        .onChange(of: trackingMode) { _, newValue in
            guard newValue.usesManualIntervals else { return }
            if segments.isEmpty {
                segments = [.default]
            }
        }
    }

    private func loadSnapshot() {
        let snapshot = initialWorkoutPlan
        trackingMode = snapshot.trackingMode
        restMode = snapshot.restMode
        distanceUnit = settings.distanceUnit
        segments = snapshot.distanceSegments.isEmpty ? [.default] : snapshot.distanceSegments
        customTitle = initialCustomTitle ?? ""
        storedPresetID = initialStoredPresetID
        ensuresDualModeForOpenIntervals(showBanner: false)
    }

    private func addSegment() {
        let nextSegment = segments.last ?? .default
        segments.append(
            DistanceSegment(
                distanceMeters: nextSegment.distanceMeters,
                repeatCount: nextSegment.repeatCount,
                restSeconds: nextSegment.restSeconds,
                lastRestSeconds: nextSegment.lastRestSeconds,
                distanceGoalMode: nextSegment.distanceGoalMode,
                targetPaceSecondsPerKm: nextSegment.targetPaceSecondsPerKm,
                targetTimeSeconds: nextSegment.targetTimeSeconds
            )
        )
        segments = WorkoutPlanSupport.normalizedSegments(segments)
        persistPresetAfterEditIfNeeded()
    }

    private func deleteSegments(at offsets: IndexSet) {
        segments.remove(atOffsets: offsets)
        if segments.isEmpty {
            segments = [.default]
        }
        segments = WorkoutPlanSupport.normalizedSegments(segments)
        persistPresetAfterEditIfNeeded()
    }

    private func commitSegment(_ updatedSegment: DistanceSegment) {
        guard let index = segments.firstIndex(where: { $0.id == updatedSegment.id }) else { return }
        segments[index] = updatedSegment
        ensuresDualModeForOpenIntervals(showBanner: updatedSegment.usesOpenDistance)
        segments = WorkoutPlanSupport.normalizedSegments(segments)
        persistPresetAfterEditIfNeeded()
    }

    private func currentWorkoutPlan() -> WorkoutPlanSnapshot {
        WorkoutPlanSupport.makeWorkoutPlan(
            requestedTrackingMode: trackingMode,
            currentTrackingMode: settings.trackingMode,
            fallbackDistance: initialWorkoutPlan.distanceLapDistanceMeters,
            segments: trackingMode.usesManualIntervals ? segments : [.default],
            restMode: restMode
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

    private func commitWorkoutPlan() {
        let workoutPlan = currentWorkoutPlan()
        settings.distanceUnit = distanceUnit
        onContinue(workoutPlan, IntervalPreset.sanitizeTitle(customTitle), storedPresetID)
        dismiss()
    }

    private func ensuresDualModeForOpenIntervals(showBanner: Bool) {
        guard segments.contains(where: \.usesOpenDistance) else { return }
        guard trackingMode == .distanceDistance else { return }
        trackingMode = .dual
        showsOpenDistanceBanner = showBanner
    }
}

private struct CompanionSegmentRow: View {
    let segment: DistanceSegment
    let distanceUnit: DistanceUnit
    @Environment(\.appTheme) private var theme

    private var title: String {
        let distance = segment.usesOpenDistance
            ? L10n.openDistance
            : Formatters.distanceString(meters: segment.distanceMeters, unit: distanceUnit)

        if let repeatCount = segment.repeatCount {
            return "\(repeatCount) × \(distance)"
        }

        return distance
    }

    private var details: [String] {
        var items: [String] = []

        if let restSeconds = segment.restSeconds {
            items.append("\(L10n.rest): \(restSeconds)s")
        } else {
            items.append("\(L10n.rest): \(L10n.manual)")
        }

        if let lastRestSeconds = segment.lastRestSeconds {
            items.append("\(L10n.lastRest): \(lastRestSeconds)s")
        }

        if let targetTime = segment.targetTimeSeconds {
            items.append("\(L10n.time): \(Formatters.timeString(from: targetTime))")
        }

        if let targetPace = segment.targetPaceSecondsPerKm {
            items.append("\(L10n.pace): \(Formatters.compactPaceString(secondsPerKm: targetPace, unit: distanceUnit))")
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.text.neutral)

            if !details.isEmpty {
                Text(details.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(theme.text.subtle)
            }
        }
    }
}

private struct CompanionSegmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var segment: DistanceSegment
    @State private var distanceText: String
    let distanceUnit: DistanceUnit
    let onSave: (DistanceSegment) -> Void

    init(segment: DistanceSegment, distanceUnit: DistanceUnit, onSave: @escaping (DistanceSegment) -> Void) {
        _segment = State(initialValue: segment)
        _distanceText = State(initialValue: CompanionSegmentEditorView.distanceText(for: segment, unit: distanceUnit))
        self.distanceUnit = distanceUnit
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker(L10n.distanceType, selection: $segment.distanceGoalMode) {
                    Text(L10n.fixedDistance).tag(DistanceGoalMode.fixed)
                    Text(L10n.openDistance).tag(DistanceGoalMode.open)
                }

                if !segment.usesOpenDistance {
                    TextField(distanceLabel, text: $distanceText)
                        .keyboardType(.decimalPad)
                        .foregroundStyle(theme.text.neutral)
                }

                Stepper(value: Binding(
                    get: { segment.repeatCount ?? 0 },
                    set: { segment.repeatCount = $0 > 0 ? $0 : nil }
                ), in: 0...99) {
                    LabeledContent(L10n.repeats, value: segment.repeatCount.map(String.init) ?? L10n.unlimited)
                }

                Stepper(value: Binding(
                    get: { segment.restSeconds ?? 0 },
                    set: { segment.restSeconds = $0 > 0 ? $0 : nil }
                ), in: 0...600) {
                    LabeledContent(L10n.rest, value: segment.restSeconds.map { "\($0)s" } ?? L10n.manual)
                }

                Stepper(value: Binding(
                    get: { segment.lastRestSeconds ?? 0 },
                    set: { segment.lastRestSeconds = $0 > 0 ? $0 : nil }
                ), in: 0...600) {
                    LabeledContent(L10n.lastRest, value: segment.lastRestSeconds.map { "\($0)s" } ?? L10n.off)
                }

                Stepper(value: Binding(
                    get: { Int(segment.targetTimeSeconds ?? 0) },
                    set: { segment.targetTimeSeconds = $0 > 0 ? Double($0) : nil }
                ), in: 0...7200) {
                    LabeledContent(L10n.time, value: segment.targetTimeSeconds.map { Formatters.timeString(from: $0) } ?? L10n.off)
                }

                if !segment.usesOpenDistance {
                    Stepper(value: Binding(
                        get: { Int(segment.targetPaceSecondsPerKm ?? 0) },
                        set: { segment.targetPaceSecondsPerKm = $0 > 0 ? Double($0) : nil }
                    ), in: 0...1200) {
                        LabeledContent(
                            L10n.pace,
                            value: segment.targetPaceSecondsPerKm.map {
                                Formatters.compactPaceString(secondsPerKm: $0, unit: distanceUnit)
                            } ?? L10n.off
                        )
                    }
                }
            }
            .navigationTitle(L10n.editInterval)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) {
                        commit()
                    }
                }
            }
        }
    }

    private var distanceLabel: String {
        switch distanceUnit {
        case .km:
            return L10n.distanceMetersShort
        case .miles:
            return L10n.distanceFeetShort
        }
    }

    private func commit() {
        if !segment.usesOpenDistance, let value = Double(distanceText), value > 0 {
            switch distanceUnit {
            case .km:
                segment.distanceMeters = value
            case .miles:
                segment.distanceMeters = value / 3.28084
            }
        }

        if segment.usesOpenDistance {
            segment.targetPaceSecondsPerKm = nil
        }

        onSave(segment)
        dismiss()
    }

    private static func distanceText(for segment: DistanceSegment, unit: DistanceUnit) -> String {
        let displayDistance: Double
        switch unit {
        case .km:
            displayDistance = segment.distanceMeters
        case .miles:
            displayDistance = segment.distanceMeters * 3.28084
        }

        if displayDistance == floor(displayDistance) {
            return String(format: "%.0f", displayDistance)
        }

        return String(format: "%g", displayDistance)
    }
}

private struct CompanionLiveWorkoutCard: View {
    let state: LiveWorkoutStateRecord
    @Environment(\.appTheme) private var theme
    @State private var now = Date()
    private let stalenessTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var isStale: Bool {
        guard state.runState != .paused,
              state.runState != .ended,
              state.runState != .idle else {
            return false
        }
        return now.timeIntervalSince(state.updatedAt) > 10
    }

    private var statusLabel: String {
        isStale ? L10n.waitingForWatch : state.runStateLabel
    }

    private var isOpenActivity: Bool {
        state.trackingMode.usesManualIntervals && state.currentTargetDistanceMeters == nil
    }

    private var primaryDistanceLabel: String {
        if isOpenActivity, state.cumulativeGPSDistanceMeters != nil {
            return L10n.gpsDistanceLabel
        }

        if state.trackingMode.usesManualIntervals {
            return L10n.manualDistance
        }

        if state.cumulativeGPSDistanceMeters != nil {
            return L10n.gpsDistanceLabel
        }

        return L10n.distance
    }

    private var primaryDistanceMeters: Double {
        if isOpenActivity, let gps = state.cumulativeGPSDistanceMeters {
            return gps
        }
        return state.cumulativeDistanceMeters
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            Text(Formatters.historySessionDateTimeString(from: state.startedAt))
                .font(.headline)
                .foregroundStyle(theme.text.neutral)

            HStack {
                Label(Formatters.timeString(from: state.elapsedSeconds), systemImage: "timer")
                    .foregroundStyle(theme.text.neutral)
                Spacer()
                Text(statusLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isStale ? .orange : theme.text.subtle)
            }

            HStack {
                CompanionMetricPill(title: L10n.laps, value: "\(state.completedLapCount)")
                CompanionMetricPill(
                    title: primaryDistanceLabel,
                    value: Formatters.distanceString(meters: primaryDistanceMeters, unit: .km)
                )
            }

            if let heartRate = state.currentHeartRate {
                Text(L10n.heartRateBPM(Int(heartRate)))
                    .font(.subheadline)
                    .foregroundStyle(theme.text.subtle)
            }
        }
        .onReceive(stalenessTimer) { now = $0 }
        .onAppear { now = Date() }
    }
}

private struct CompanionSessionRow: View {
    let session: Session
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    private var sessionUsesOpenIntervals: Bool {
        session.snapshotWorkoutPlan.distanceSegments.contains(where: \.usesOpenDistance)
    }

    private var summaryDistance: Double {
        sessionUsesOpenIntervals
            ? (session.totalGPSDistanceMeters ?? session.totalDistanceMeters)
            : session.totalDistanceMeters
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            HStack(alignment: .center, spacing: Tokens.Spacing.md) {
                Text(Formatters.historySessionDateTimeString(from: session.startedAt))
                    .font(.headline)
                    .foregroundStyle(theme.text.neutral)

                Spacer(minLength: Tokens.Spacing.md)

                if session.isImportedFromWatch {
                    CompanionImportBadge(title: L10n.fromAppleWatch)
                }
            }

            Text(L10n.lapsSummary(session.activeLapCount, Formatters.speedString(metersPerSecond: session.averageSpeedMetersPerSecond)))
                .font(.subheadline)
                .foregroundStyle(theme.text.subtle)

            Text(
                L10n.timeSummary(
                    Formatters.timeString(from: session.activeDurationSeconds),
                    summaryDistance > 0
                        ? Formatters.distanceString(meters: summaryDistance, unit: settings.distanceUnit)
                        : L10n.dash
                )
            )
            .font(.subheadline)
            .foregroundStyle(theme.text.subtle)
        }
        .companionCardChrome()
    }
}

private struct CompanionSessionDetailView: View {
    let session: Session

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        List {
            Section {
                CompanionImportStatusCard(session: session)
                    .listRowCardChrome()
            }

            Section(L10n.summary) {
                LabeledContent(L10n.started, value: Formatters.historySessionDateTimeString(from: session.startedAt))
                LabeledContent(L10n.ended, value: Formatters.historySessionDateTimeString(from: session.endedAt))
                LabeledContent(L10n.source, value: session.companionSourceDisplayName)
                LabeledContent(L10n.importStatus, value: L10n.importComplete)
                LabeledContent(L10n.mode, value: session.mode.displayName)
                LabeledContent(L10n.time, value: Formatters.timeString(from: session.activeDurationSeconds))
                LabeledContent(L10n.distance, value: Formatters.distanceString(meters: session.totalDistanceMeters, unit: .km))
                if let gpsDistance = session.totalGPSDistanceMeters {
                    LabeledContent(L10n.gpsDistanceLabel, value: Formatters.distanceString(meters: gpsDistance, unit: .km))
                }
            }

            Section(L10n.laps) {
                ForEach(sortedLaps, id: \.id) { lap in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lap.lapType == .rest ? L10n.rest : L10n.lapIndex(lap.index))
                            .font(.headline)
                        Text(Formatters.lapSummaryString(lap: lap, trackingMode: session.mode, unit: .km))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let heartRate = lap.averageHeartRateBPM {
                            Text(L10n.heartRateBPM(Int(heartRate)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(L10n.session)
    }
}

private struct CompanionImportBadge: View {
    let title: String
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.text.emphasis)
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(theme.background.emphasis(settings.primaryAccentColor))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(theme.stroke.emphasis(settings.primaryAccentColor), lineWidth: Tokens.LineWidth.thin)
            )
            .clipShape(Capsule(style: .continuous))
    }
}

private struct CompanionImportStatusCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(L10n.importedSession)
                    .font(.headline)

                if session.isImportedFromWatch {
                    CompanionImportBadge(title: L10n.fromAppleWatch)
                }
            }

            Text(L10n.importedFromSource(session.companionSourceDisplayName))
                .font(.subheadline.weight(.semibold))

            Text(L10n.importedSessionSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private extension View {
    func themedCompanionList() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
    }

    func listRowCardChrome() -> some View {
        self
            .listRowInsets(EdgeInsets(top: Tokens.Spacing.xs, leading: Tokens.Spacing.lg, bottom: Tokens.Spacing.xs, trailing: Tokens.Spacing.lg))
            .listRowBackground(Color.clear)
    }

    func companionCardChrome() -> some View {
        modifier(CompanionCardChrome())
    }
}

private struct CompanionCardChrome: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                    .fill(theme.background.neutral)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                    .stroke(theme.stroke.neutral, lineWidth: Tokens.LineWidth.thin)
            )
    }
}

private extension LiveWorkoutStateRecord {
    var runStateLabel: String {
        switch runState {
        case .idle:
            return L10n.runStateIdle
        case .ready:
            return L10n.runStateReady
        case .active:
            return L10n.runStateActive
        case .rest:
            return L10n.runStateRest
        case .paused:
            return L10n.runStatePaused
        case .ending:
            return L10n.runStateEnding
        case .ended:
            return L10n.runStateEnded
        }
    }
}

private extension Session {
    var isImportedFromWatch: Bool {
        deviceSource.localizedCaseInsensitiveContains("watch")
    }

    var companionSourceDisplayName: String {
        if isImportedFromWatch {
            return "Apple Watch"
        }

        let trimmedSource = deviceSource.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSource.isEmpty ? L10n.sourceUnknown : trimmedSource
    }
}
