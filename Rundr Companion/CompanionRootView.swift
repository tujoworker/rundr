import SwiftData
import SwiftUI

struct CompanionRootView: View {
    @EnvironmentObject private var settings: SettingsStore

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
        .tint(settings.primaryAccentColor)
    }
}

private struct CompanionWorkoutsView: View {
    @EnvironmentObject private var syncManager: WatchConnectivitySyncManager
    @EnvironmentObject private var persistence: PersistenceManager
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme
    @Query(sort: [SortDescriptor(\Session.startedAt, order: .reverse)]) private var sessions: [Session]
    @State private var visibleSessionCount = 2
    @State private var selectedSegment: DistanceSegment?
    @State private var lastAddedDistanceMeters: Double = DistanceSegment.default.distanceMeters
    @State private var lastAddedUsesOpenDistance = false
    @State private var lastAddedRepeatCount: Int = 0
    @State private var lastAddedRestSeconds: Int = 0
    @State private var lastAddedLastRestSeconds: Int = 0
    @State private var lastAddedTargetPace: Int = 0
    @State private var lastAddedTargetTime: Int = 0
    @State private var addSegmentBounceTrigger = 0

    private var visibleLiveWorkoutState: LiveWorkoutStateRecord? {
        guard let state = syncManager.liveWorkoutState,
              !state.isTerminalState,
              sessions.contains(where: { $0.id == state.sessionID }) == false else {
            return nil
        }

        return state
    }

    private var segments: [DistanceSegment] {
        let storedSegments = settings.distanceSegments
        return storedSegments.isEmpty ? [.default] : WorkoutPlanSupport.normalizedSegments(storedSegments)
    }

    private var visibleSessions: ArraySlice<Session> {
        sessions.prefix(visibleSessionCount)
    }

    private var canLoadMoreSessions: Bool {
        sessions.count > visibleSessionCount
    }

    var body: some View {
        NavigationStack {
            List {
                if let liveWorkoutState = visibleLiveWorkoutState {
                    Section {
                        CompanionLiveWorkoutCard(state: liveWorkoutState)
                            .padding(.leading, Tokens.Spacing.xl)
                            .listRowCardChrome(rowInsets: Tokens.ListRowInsets.card)
                    } header: {
                        CompanionHomeSectionHeader(title: L10n.liveOnAppleWatch)
                    }
                }

                if settings.trackingMode.usesManualIntervals {
                    Section {
                        ForEach(segments) { segment in
                            Button {
                                selectedSegment = segment
                            } label: {
                                CompanionSegmentRow(segment: segment, distanceUnit: settings.distanceUnit)
                                    .padding(.leading, Tokens.Spacing.xl)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteSegment(segment)
                                } label: {
                                    Label(L10n.delete, systemImage: "trash")
                                }
                            }
                            .listRowCardChrome(rowInsets: Tokens.ListRowInsets.card)
                        }

                        Button {
                            animateSegmentAddition()
                        } label: {
                            HStack {
                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: Tokens.ControlSize.companionAddIcon, weight: .semibold))
                                    .foregroundStyle(settings.primaryAccentColor)
                                    .symbolEffect(.bounce, value: addSegmentBounceTrigger)

                                Spacer()
                            }
                            .padding(.vertical, Tokens.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(Tokens.ListRowInsets.card)
                        .listRowBackground(Color.clear)
                    } header: {
                        CompanionHomeSectionHeader(title: L10n.intervalsTitle)
                    }
                }

                Section {
                    if sessions.isEmpty {
                        Text(L10n.noSyncedSessionsYet)
                            .font(.subheadline)
                            .foregroundStyle(theme.text.subtle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, Tokens.Spacing.xl)
                            .listRowCardChrome(rowInsets: Tokens.ListRowInsets.card)
                    } else {
                        ForEach(visibleSessions, id: \.id) { session in
                            NavigationLink {
                                CompanionSessionDetailView(session: session)
                            } label: {
                                CompanionSessionRow(session: session)
                                    .padding(.leading, Tokens.Spacing.xl)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    persistence.deleteSession(session)
                                } label: {
                                    Label(L10n.delete, systemImage: "trash")
                                }
                            }
                            .listRowCardChrome(rowInsets: Tokens.ListRowInsets.card)
                        }

                        if canLoadMoreSessions {
                            Button(L10n.loadMore) {
                                withAnimation(.snappy(duration: 0.3, extraBounce: 0.08)) {
                                    visibleSessionCount += 4
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.headline)
                            .foregroundStyle(settings.primaryAccentColor)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                        }
                    }
                } header: {
                    CompanionHomeSectionHeader(title: L10n.syncedSessions)
                }
            }
            .onAppear(perform: syncLastAddedValues)
            .navigationDestination(item: $selectedSegment) { segment in
                CompanionSegmentEditorView(
                    segment: segment,
                    distanceUnit: settings.distanceUnit
                ) { updatedSegment in
                    commitSegment(updatedSegment)
                }
            }
            .onChange(of: settings.distanceSegments) { _, _ in
                syncLastAddedValues()
            }
            .navigationTitle(L10n.workouts)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .themedCompanionList()
        }
    }

    private func syncLastAddedValues() {
        let lastSegment = settings.distanceSegments.last
        lastAddedDistanceMeters = lastSegment?.distanceMeters ?? DistanceSegment.default.distanceMeters
        lastAddedUsesOpenDistance = lastSegment?.usesOpenDistance ?? false
        lastAddedRepeatCount = lastSegment?.repeatCount ?? 0
        lastAddedRestSeconds = lastSegment?.restSeconds ?? 0
        lastAddedLastRestSeconds = lastSegment?.lastRestSeconds ?? 0
        lastAddedTargetPace = Int(lastSegment?.targetPaceSecondsPerKm ?? 0)
        lastAddedTargetTime = Int(lastSegment?.targetTimeSeconds ?? 0)
    }

    private func animateSegmentAddition() {
        addSegmentBounceTrigger += 1
        withAnimation(.snappy(duration: 0.3, extraBounce: 0.12)) {
            addSegment()
        }
    }

    private func addSegment() {
        var updatedSegments = segments
        updatedSegments.append(
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
        settings.distanceSegments = WorkoutPlanSupport.normalizedSegments(updatedSegments)
    }

    private func deleteSegment(_ segment: DistanceSegment) {
        var updatedSegments = segments
        updatedSegments.removeAll { $0.id == segment.id }
        if updatedSegments.isEmpty {
            updatedSegments = [.default]
        }
        settings.distanceSegments = WorkoutPlanSupport.normalizedSegments(updatedSegments)
    }

    private func commitSegment(_ updatedSegment: DistanceSegment) {
        var updatedSegments = segments
        guard let index = updatedSegments.firstIndex(where: { $0.id == updatedSegment.id }) else { return }
        updatedSegments[index] = updatedSegment

        if !updatedSegment.usesOpenDistance {
            lastAddedDistanceMeters = updatedSegment.distanceMeters
        }
        lastAddedUsesOpenDistance = updatedSegment.usesOpenDistance
        lastAddedRepeatCount = updatedSegment.repeatCount ?? 0
        lastAddedRestSeconds = updatedSegment.restSeconds ?? 0
        lastAddedLastRestSeconds = updatedSegment.lastRestSeconds ?? 0
        lastAddedTargetPace = Int(updatedSegment.targetPaceSecondsPerKm ?? 0)
        lastAddedTargetTime = Int(updatedSegment.targetTimeSeconds ?? 0)

        if updatedSegment.usesOpenDistance, settings.trackingMode == .distanceDistance {
            settings.trackingMode = .dual
        }

        settings.distanceSegments = WorkoutPlanSupport.normalizedSegments(updatedSegments)
    }
}

private struct CompanionBrowserView: View {
    var body: some View {
        NavigationStack {
            CompanionPresetLibraryView()
        }
    }
}

private struct CompanionPresetLibraryView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section(L10n.myIntervals) {
                if settings.intervalPresets.isEmpty {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                        Text(L10n.noSavedIntervalsYet)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(theme.text.neutral)

                        Text(L10n.savedIntervalsPlaceholderDetail)
                            .font(.subheadline)
                            .foregroundStyle(theme.text.subtle)
                    }
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
                            .tint(.red)
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
        .navigationBarTitleDisplayMode(.large)
        .themedCompanionList()
    }
}

private struct CompanionSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CompanionAppearanceSettingsDetailView()
                        } label: {
                            CompanionSettingsNavigationRow(
                                title: L10n.appearance,
                                value: settings.appearanceMode.displayName,
                                systemImage: "circle.lefthalf.filled"
                            )
                        }

                        NavigationLink {
                            CompanionColorSettingsDetailView()
                        } label: {
                            CompanionSettingsNavigationRow(
                                title: L10n.color,
                                value: settings.primaryColor.displayName,
                                tintColor: settings.primaryColor.color,
                                systemImage: "paintpalette.fill"
                            )
                        }
                    }
                }
            .navigationTitle(L10n.settings)
                .navigationBarTitleDisplayMode(.large)
            .themedCompanionSettingsList()
        }
    }
}

private struct CompanionHomeSectionHeader: View {
    let title: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.md) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.text.neutral)
        }
    }
}

private struct CompanionAppearanceSettingsDetailView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        settings.appearanceMode = mode
                    } label: {
                        HStack(spacing: Tokens.Spacing.md) {
                            Text(mode.displayName)
                                .foregroundStyle(theme.text.neutral)

                            Spacer()

                            if settings.appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(settings.primaryAccentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(L10n.appearance)
        .navigationBarTitleDisplayMode(.inline)
        .themedCompanionSettingsList()
    }
}

private struct CompanionColorSettingsDetailView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
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
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(settings.primaryAccentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(L10n.color)
        .navigationBarTitleDisplayMode(.inline)
        .themedCompanionSettingsList()
    }
}

private struct CompanionSettingsNavigationRow: View {
    let title: String
    let value: String
    var tintColor: Color? = nil
    let systemImage: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        let iconTint = tintColor ?? theme.text.neutral

        HStack(spacing: Tokens.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                    .fill(iconTint.opacity(theme.isDark ? Tokens.Opacity.fillAccent : 0.14))
                    .frame(width: 28, height: 28)

                Image(systemName: systemImage)
                    .font(.system(size: Tokens.FontSize.md, weight: .semibold))
                    .foregroundStyle(iconTint)
            }

            Text(title)
                .foregroundStyle(theme.text.neutral)

            Spacer()

            Text(value)
                .foregroundStyle(theme.text.subtle)
        }
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
                .font(.headline.weight(.semibold))
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
    @State private var selectedSegment: DistanceSegment?
    @State private var showsOpenDistanceBanner = false
    @State private var addSegmentBounceTrigger = 0

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
                            selectedSegment = segment
                        } label: {
                            CompanionSegmentRow(segment: segment, distanceUnit: distanceUnit)
                        }
                        .buttonStyle(.plain)
                        .listRowCardChrome()
                    }
                    .onDelete(perform: deleteSegments)

                    Button {
                        animateSegmentAddition()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .symbolEffect(.bounce, value: addSegmentBounceTrigger)
                            Text(L10n.addInterval)
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.emphasis)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Spacing.md)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
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
        .navigationDestination(item: $selectedSegment) { segment in
            CompanionSegmentEditorView(
                segment: segment,
                distanceUnit: distanceUnit
            ) { updatedSegment in
                commitSegment(updatedSegment)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.done) {
                    commitWorkoutPlan()
                }
            }
        }
        .onAppear(perform: loadSnapshot)
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

    private func animateSegmentAddition() {
        addSegmentBounceTrigger += 1
        withAnimation(.snappy(duration: 0.3, extraBounce: 0.12)) {
            addSegment()
        }
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

    private var repeatValue: String {
        segment.repeatCount.map(String.init) ?? L10n.unlimited
    }

    private var restValue: String {
        segment.restSeconds.map { Formatters.compactTimeString(from: Double($0)) } ?? L10n.manual
    }

    private var lastRestValue: String {
        segment.lastRestSeconds.map { Formatters.compactTimeString(from: Double($0)) } ?? L10n.off
    }

    private var targetLabel: String {
        segment.targetTimeSeconds != nil ? L10n.targetTimeLabel : L10n.targetPaceLabel
    }

    private var targetValue: String {
        if let targetTime = segment.targetTimeSeconds {
            return Formatters.compactTimeString(from: targetTime)
        }

        if let targetPace = segment.targetPaceSecondsPerKm {
            return Formatters.compactPaceString(secondsPerKm: targetPace, unit: distanceUnit)
        }

        return L10n.off
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.md) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.text.neutral)

                    Spacer(minLength: Tokens.Spacing.md)

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.subtle)
                }

                HStack(alignment: .top, spacing: Tokens.Spacing.xxxxl) {
                    CompanionMetricPill(title: L10n.repeats, value: repeatValue)
                    CompanionMetricPill(title: L10n.rest, value: restValue)
                    CompanionMetricPill(title: L10n.lastRest, value: lastRestValue)
                    CompanionMetricPill(title: targetLabel, value: targetValue)
                }
            }
        }
    }
}

private struct CompanionSegmentEditorView: View {
    @Environment(\.appTheme) private var theme

    @State private var segment: DistanceSegment
    @State private var distanceText: String
    @State private var hasCommitted = false
    let distanceUnit: DistanceUnit
    let onSave: (DistanceSegment) -> Void

    private var editorRowInsets: EdgeInsets {
        Tokens.ListRowInsets.card
    }

    private var editorRowContentInsets: EdgeInsets {
        EdgeInsets(
            top: Tokens.Spacing.xxxxl,
            leading: Tokens.Spacing.xxxl,
            bottom: Tokens.Spacing.xxxxl,
            trailing: Tokens.Spacing.xxxl
        )
    }

    init(segment: DistanceSegment, distanceUnit: DistanceUnit, onSave: @escaping (DistanceSegment) -> Void) {
        _segment = State(initialValue: segment)
        _distanceText = State(initialValue: CompanionSegmentEditorView.distanceText(for: segment, unit: distanceUnit))
        self.distanceUnit = distanceUnit
        self.onSave = onSave
    }

    var body: some View {
        List {
            Section {
                Picker(L10n.distanceType, selection: $segment.distanceGoalMode) {
                    Text(L10n.fixedDistance).tag(DistanceGoalMode.fixed)
                    Text(L10n.openDistance).tag(DistanceGoalMode.open)
                }
                .padding(.trailing, Tokens.Spacing.sm)
                .listRowCardChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )

                if !segment.usesOpenDistance {
                    HStack(spacing: Tokens.Spacing.md) {
                        Text(distanceLabel)
                            .font(.body.weight(.medium))
                            .foregroundStyle(theme.text.neutral)

                        Spacer(minLength: Tokens.Spacing.md)

                        TextField("", text: $distanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(theme.text.neutral)
                            .frame(maxWidth: 140)
                            .padding(.trailing, Tokens.Spacing.sm)
                    }
                    .listRowCardChrome(
                        rowInsets: editorRowInsets,
                        contentInsets: editorRowContentInsets
                    )
                }

                Stepper(value: Binding(
                    get: { segment.repeatCount ?? 0 },
                    set: { segment.repeatCount = $0 > 0 ? $0 : nil }
                ), in: 0...99) {
                    LabeledContent(L10n.repeats, value: segment.repeatCount.map(String.init) ?? L10n.unlimited)
                }
                .listRowCardChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )

                Stepper(value: Binding(
                    get: { segment.restSeconds ?? 0 },
                    set: { segment.restSeconds = $0 > 0 ? $0 : nil }
                ), in: 0...600) {
                    LabeledContent(L10n.rest, value: segment.restSeconds.map { "\($0)s" } ?? L10n.manual)
                }
                .listRowCardChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )

                Stepper(value: Binding(
                    get: { segment.lastRestSeconds ?? 0 },
                    set: { segment.lastRestSeconds = $0 > 0 ? $0 : nil }
                ), in: 0...600) {
                    LabeledContent(L10n.lastRest, value: segment.lastRestSeconds.map { "\($0)s" } ?? L10n.off)
                }
                .listRowCardChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )

                Stepper(value: Binding(
                    get: { Int(segment.targetTimeSeconds ?? 0) },
                    set: { segment.targetTimeSeconds = $0 > 0 ? Double($0) : nil }
                ), in: 0...7200) {
                    LabeledContent(L10n.time, value: segment.targetTimeSeconds.map { Formatters.timeString(from: $0) } ?? L10n.off)
                }
                .listRowCardChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )

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
                    .listRowCardChrome(
                        rowInsets: editorRowInsets,
                        contentInsets: editorRowContentInsets
                    )
                }
            }
        }
        .navigationTitle(L10n.editInterval)
        .themedCompanionList()
        .onDisappear(perform: commitIfNeeded)
    }

    private var distanceLabel: String {
        switch distanceUnit {
        case .km:
            return L10n.distanceMetersShort
        case .miles:
            return L10n.distanceFeetShort
        }
    }

    private func commitIfNeeded() {
        guard !hasCommitted else { return }
        hasCommitted = true

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
    @EnvironmentObject private var settings: SettingsStore
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
                    value: Formatters.distanceString(meters: primaryDistanceMeters, unit: settings.distanceUnit)
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

    private var summaryPace: String {
        guard summaryDistance > 0 else { return L10n.dash }
        return Formatters.paceString(
            distanceMeters: summaryDistance,
            durationSeconds: session.activeDurationSeconds,
            unit: settings.distanceUnit
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                Text(Formatters.historySessionDateTimeString(from: session.startedAt))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.text.neutral)

                HStack(alignment: .top, spacing: Tokens.Spacing.xxxxl) {
                    CompanionMetricPill(title: L10n.laps, value: "\(session.activeLapCount)")
                    CompanionMetricPill(title: L10n.pace, value: summaryPace)
                    CompanionMetricPill(title: L10n.duration, value: Formatters.timeString(from: session.activeDurationSeconds))
                    CompanionMetricPill(
                        title: L10n.distance,
                        value: summaryDistance > 0
                            ? Formatters.distanceString(meters: summaryDistance, unit: settings.distanceUnit)
                            : L10n.dash
                    )
                }
            }

            Spacer(minLength: Tokens.Spacing.md)

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.text.subtle)
                .padding(.top, Tokens.Spacing.xs)
        }
    }
}

private struct CompanionSessionDetailView: View {
    let session: Session
    @EnvironmentObject private var settings: SettingsStore

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
                LabeledContent(L10n.distance, value: Formatters.distanceString(meters: session.totalDistanceMeters, unit: settings.distanceUnit))
                if let gpsDistance = session.totalGPSDistanceMeters {
                    LabeledContent(L10n.gpsDistanceLabel, value: Formatters.distanceString(meters: gpsDistance, unit: settings.distanceUnit))
                }
            }

            Section(L10n.laps) {
                ForEach(sortedLaps, id: \.id) { lap in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lap.lapType == .rest ? L10n.rest : L10n.lapIndex(lap.index))
                            .font(.headline)
                        Text(Formatters.lapSummaryString(lap: lap, trackingMode: session.mode, unit: settings.distanceUnit))
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
        .themedCompanionList()
    }
}

private struct CompanionImportBadge: View {
    let title: String
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(settings.primaryAccentColor)
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(settings.primaryAccentColor.opacity(0.12))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(settings.primaryAccentColor.opacity(0.18), lineWidth: Tokens.LineWidth.thin)
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

private struct CompanionScreenBackground: View {
    let accentColor: Color
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            theme.background.app(accentColor)

            LinearGradient(
                colors: [
                    theme.appGradientStart(accent: accentColor),
                    theme.appGradientEnd(accent: accentColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private extension View {
    @ViewBuilder
    func companionListBackground() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background {
                CompanionListBackgroundView()
                    .ignoresSafeArea()
            }
    }

    func themedCompanionList() -> some View {
        self.companionListBackground()
    }

    func themedCompanionSettingsList() -> some View {
        self.companionListBackground()
    }

    func listRowCardChrome(
        rowInsets: EdgeInsets = Tokens.ListRowInsets.companionCard,
        contentInsets: EdgeInsets = Tokens.ContentInsets.companionCard
    ) -> some View {
        modifier(CompanionListRowChrome(rowInsets: rowInsets, contentInsets: contentInsets))
    }

    func companionCardChrome() -> some View {
        self
    }
}

private struct CompanionListRowChrome: ViewModifier {
    let rowInsets: EdgeInsets
    let contentInsets: EdgeInsets
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(contentInsets)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                    .fill(theme.background.history)
            )
            .listRowInsets(rowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private struct CompanionListBackgroundView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        CompanionScreenBackground(accentColor: settings.primaryAccentColor)
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
