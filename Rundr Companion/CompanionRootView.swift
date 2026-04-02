import SwiftData
import SwiftUI
import UIKit

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
    @State private var flashingSegmentIDs: Set<UUID> = []

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
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(CompanionNoPressOpacityButtonStyle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteSegment(segment)
                                } label: {
                                    Label(L10n.delete, systemImage: "trash")
                                }
                            }
                            .listRowCardChrome(
                                rowInsets: Tokens.ListRowInsets.card,
                                fillColor: flashingSegmentIDs.contains(segment.id)
                                    ? theme.background.emphasisAction(settings.primaryAccentColor)
                                    : nil
                            )
                            .contentShape(Rectangle())
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
            .onChange(of: settings.distanceSegments) { oldValue, newValue in
                syncLastAddedValues()
                flashChangedSegments(oldSegments: oldValue, newSegments: newValue)
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

    private func flashChangedSegments(oldSegments: [DistanceSegment], newSegments: [DistanceSegment]) {
        let oldByID = Dictionary(uniqueKeysWithValues: oldSegments.map { ($0.id, $0) })
        let changedOrAdded = Set(
            newSegments.compactMap { segment in
                guard let oldSegment = oldByID[segment.id] else { return segment.id }
                return oldSegment == segment ? nil : segment.id
            }
        )

        guard !changedOrAdded.isEmpty else { return }

        withAnimation(.easeOut(duration: 0.15)) {
            flashingSegmentIDs.formUnion(changedOrAdded)
        }

        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    flashingSegmentIDs.subtract(changedOrAdded)
                }
            }
        }
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
                        CompanionTrackingModeSettingsDetailView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.mode,
                            value: settings.trackingMode.displayName,
                            systemImage: "location"
                        )
                    }

                    NavigationLink {
                        CompanionDistanceUnitSettingsDetailView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.unit,
                            value: settings.distanceUnit.displayName,
                            systemImage: "ruler"
                        )
                    }

                    NavigationLink {
                        CompanionRestModeSettingsDetailView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.restMode,
                            value: settings.restMode.displayName,
                            systemImage: "figure.cooldown"
                        )
                    }

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

private struct CompanionTrackingModeSettingsDetailView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(TrackingMode.allCases) { mode in
                    Button {
                        settings.trackingMode = WorkoutPlanSupport.resolvedTrackingMode(
                            requestedTrackingMode: mode,
                            segments: settings.distanceSegments,
                            currentTrackingMode: settings.trackingMode
                        )
                    } label: {
                        HStack(spacing: Tokens.Spacing.md) {
                            Text(mode.displayName)
                                .foregroundStyle(theme.text.neutral)

                            Spacer()

                            if settings.trackingMode == mode {
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
        .navigationTitle(L10n.mode)
        .navigationBarTitleDisplayMode(.inline)
        .themedCompanionSettingsList()
    }
}

private struct CompanionDistanceUnitSettingsDetailView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(DistanceUnit.allCases) { unit in
                    Button {
                        settings.distanceUnit = unit
                    } label: {
                        HStack(spacing: Tokens.Spacing.md) {
                            Text(unit.displayName)
                                .foregroundStyle(theme.text.neutral)

                            Spacer()

                            if settings.distanceUnit == unit {
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
        .navigationTitle(L10n.distanceUnit)
        .navigationBarTitleDisplayMode(.inline)
        .themedCompanionSettingsList()
    }
}

private struct CompanionRestModeSettingsDetailView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(RestMode.allCases) { mode in
                    Button {
                        settings.restMode = mode
                    } label: {
                        HStack(spacing: Tokens.Spacing.md) {
                            Text(mode.displayName)
                                .foregroundStyle(theme.text.neutral)

                            Spacer()

                            if settings.restMode == mode {
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
        .navigationTitle(L10n.restMode)
        .navigationBarTitleDisplayMode(.inline)
        .themedCompanionSettingsList()
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
                .font(.system(size: Tokens.FontSize.md, weight: .regular, design: .rounded))
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
                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .symbolEffect(.bounce, value: addSegmentBounceTrigger)

                            Spacer()
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
    private struct MetricItem: Identifiable {
        let id = UUID()
        let title: String
        let value: String
    }

    let segment: DistanceSegment
    let distanceUnit: DistanceUnit
    @Environment(\.appTheme) private var theme

    private var title: String {
        segment.usesOpenDistance
            ? L10n.openDistance
            : Formatters.distanceString(meters: segment.distanceMeters, unit: distanceUnit)
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

    private var showsLastRest: Bool {
        segment.lastRestSeconds != nil
    }

    private var showsTarget: Bool {
        segment.targetTimeSeconds != nil || segment.targetPaceSecondsPerKm != nil
    }

    private var metricItems: [MetricItem] {
        var items: [MetricItem] = [
            MetricItem(title: L10n.repeats, value: repeatValue),
            MetricItem(title: L10n.rest, value: restValue)
        ]

        if showsLastRest {
            items.append(MetricItem(title: L10n.lastRest, value: lastRestValue))
        }

        if showsTarget {
            items.append(MetricItem(title: targetLabel, value: targetValue))
        }

        return items
    }

    private var metricRows: [[MetricItem]] {
        stride(from: 0, to: metricItems.count, by: 3).map { start in
            Array(metricItems[start..<min(start + 3, metricItems.count)])
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.md) {
                    Text(title)
                        .font(.system(size: Tokens.FontSize.xxxl + Tokens.Spacing.xxs, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.text.neutral)

                    Spacer(minLength: Tokens.Spacing.md)

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.subtle)
                }

                VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                    ForEach(Array(metricRows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: Tokens.Spacing.xxxxl) {
                            ForEach(row) { item in
                                CompanionMetricPill(title: item.title, value: item.value)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CompanionSegmentEditorView: View {
    private enum EditableField: String, Identifiable {
        case distance
        case repeats
        case rest
        case lastRest
        case time
        case pace

        var id: String { rawValue }

        var sharedField: CompanionSegmentEditorField {
            switch self {
            case .distance:
                return .distance
            case .repeats:
                return .repeats
            case .rest:
                return .rest
            case .lastRest:
                return .lastRest
            case .time:
                return .time
            case .pace:
                return .pace
            }
        }

        var title: String {
            switch self {
            case .distance:
                return L10n.distance
            case .repeats:
                return L10n.repeats
            case .rest:
                return L10n.rest
            case .lastRest:
                return L10n.lastRest
            case .time:
                return L10n.time
            case .pace:
                return L10n.pace
            }
        }
    }

    @Environment(\.appTheme) private var theme

    @State private var segment: DistanceSegment
    @State private var distanceText: String
    @State private var hasCommitted = false
    @State private var isLastRestInfoPresented = false
    @State private var editableField: EditableField?
    @State private var bouncingField: EditableField?
    @State private var editableValueText = ""
    let distanceUnit: DistanceUnit
    let onSave: (DistanceSegment) -> Void
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
    private let distanceKeypadRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

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

    private var canConfigureLastRest: Bool {
        SegmentEditSheetRules.canConfigureLastRest(
            repeatCount: segment.repeatCount ?? 0,
            restSeconds: segment.restSeconds ?? 0
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
                    Stepper(value: Binding(
                        get: { displayedDistanceValue() },
                        set: { updateDisplayedDistanceValue($0) }
                    ), in: 0...distanceMaximumValue, step: distanceStep) {
                        editableStepperContent(
                            title: distanceLabel,
                            value: distanceText,
                            field: .distance
                        )
                    }
                    .listRowCardChrome(
                        rowInsets: editorRowInsets,
                        contentInsets: editorRowContentInsets
                    )
                    .scaleEffect(bouncingField == .distance ? 0.97 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)
                }

                Stepper(value: Binding(
                    get: { segment.repeatCount ?? 0 },
                    set: {
                        segment.repeatCount = $0 > 0 ? $0 : nil
                        segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
                            lastRestSeconds: segment.lastRestSeconds,
                            repeatCount: segment.repeatCount
                        )
                    }
                ), in: 0...99, step: 1) {
                    editableStepperContent(
                        title: L10n.repeats,
                        value: segment.repeatCount.map(String.init) ?? L10n.unlimited,
                        field: .repeats
                    )
                }
                .listRowCardChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )
                .scaleEffect(bouncingField == .repeats ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)

                Stepper(value: Binding(
                    get: { segment.restSeconds ?? 0 },
                    set: { segment.restSeconds = $0 > 0 ? $0 : nil }
                ), in: 0...600, step: 15) {
                    editableStepperContent(
                        title: L10n.rest,
                        value: segment.restSeconds.map { Formatters.timeString(from: Double($0)) } ?? L10n.manual,
                        field: .rest
                    )
                }
                .listRowCardChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )
                .scaleEffect(bouncingField == .rest ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)

                Stepper(value: Binding(
                    get: { segment.lastRestSeconds ?? 0 },
                    set: {
                        guard canConfigureLastRest else {
                            isLastRestInfoPresented = true
                            return
                        }

                        segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
                            lastRestSeconds: $0 > 0 ? $0 : nil,
                            repeatCount: segment.repeatCount
                        )
                    }
                ), in: 0...600, step: 15) {
                    editableStepperContent(
                        title: L10n.lastRest,
                        value: segment.lastRestSeconds.map { Formatters.timeString(from: Double($0)) } ?? L10n.off,
                        field: .lastRest
                    )
                }
                .listRowCardChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )
                .scaleEffect(bouncingField == .lastRest ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)

                Stepper(value: Binding(
                    get: { Int(segment.targetTimeSeconds ?? 0) },
                    set: {
                        let updatedTargets = SegmentEditorValueRules.updatedTargetsAfterSettingTime(
                            seconds: $0,
                            currentPaceSecondsPerKm: segment.targetPaceSecondsPerKm
                        )
                        segment.targetTimeSeconds = updatedTargets.targetTimeSeconds
                        segment.targetPaceSecondsPerKm = updatedTargets.targetPaceSecondsPerKm
                    }
                ), in: 0...7200, step: 5) {
                    editableStepperContent(
                        title: L10n.time,
                        value: segment.targetTimeSeconds.map { Formatters.timeString(from: $0) } ?? L10n.off,
                        field: .time
                    )
                }
                .listRowCardChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )
                .scaleEffect(bouncingField == .time ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)

                if !segment.usesOpenDistance {
                    Stepper(value: Binding(
                        get: { Int(segment.targetPaceSecondsPerKm ?? 0) },
                        set: {
                            let updatedTargets = SegmentEditorValueRules.updatedTargetsAfterSettingPace(
                                secondsPerKm: $0,
                                currentTargetTimeSeconds: segment.targetTimeSeconds
                            )
                            segment.targetTimeSeconds = updatedTargets.targetTimeSeconds
                            segment.targetPaceSecondsPerKm = updatedTargets.targetPaceSecondsPerKm
                        }
                    ), in: 0...1200, step: 5) {
                        editableStepperContent(
                            title: L10n.pace,
                            value: segment.targetPaceSecondsPerKm.map {
                                Formatters.compactPaceString(secondsPerKm: $0, unit: distanceUnit)
                            } ?? L10n.off,
                            field: .pace
                        )
                    }
                    .listRowCardChrome(
                        rowInsets: editorRowInsets,
                        contentInsets: editorRowContentInsets
                    )
                    .scaleEffect(bouncingField == .pace ? 0.97 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)
                }
            }
        }
        .navigationTitle(L10n.editInterval)
        .themedCompanionList()
        .onAppear(perform: normalizeEditingState)
        .onChange(of: segment.distanceGoalMode) { _, _ in
            segment.targetPaceSecondsPerKm = SegmentEditorValueRules.normalizedTargetPace(
                for: segment.distanceGoalMode,
                targetPaceSecondsPerKm: segment.targetPaceSecondsPerKm
            )
        }
        .onDisappear(perform: commitIfNeeded)
        .alert(L10n.lastRestNeedsRepeatsTitle, isPresented: $isLastRestInfoPresented) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.lastRestNeedsRepeatsMessage)
        }
        .sheet(item: $editableField) { field in
            CompanionNumericKeypadSheet(
                title: field.title,
                text: $editableValueText,
                valueSuffix: field == .distance ? distanceUnitSuffix : nil,
                emptyDisplayValue: emptyDisplayValue(for: field),
                keypadRows: keypadRows(for: field),
                onTapKey: { key in
                    handleKeyTap(key, for: field)
                },
                onCancel: {
                    editableField = nil
                },
                onDone: {
                    commitEditableField(field)
                    editableField = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func editableStepperContent(title: String, value: String, field: EditableField) -> some View {
        HStack(spacing: Tokens.Spacing.md) {
            Text(title)

            Spacer(minLength: Tokens.Spacing.md)

            Text(value)
                .foregroundStyle(theme.text.neutral)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canOpenEditor(for: field) else { return }
            bouncingField = field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                bouncingField = nil
                beginEditing(field)
            }
        }
    }

    private func canOpenEditor(for field: EditableField) -> Bool {
        CompanionSegmentEditorRules.canOpenEditor(
            field: field.sharedField,
            lastRestSeconds: segment.lastRestSeconds
        )
    }

    private func emptyDisplayValue(for field: EditableField) -> String? {
        CompanionSegmentEditorRules.emptyDisplayValue(for: field.sharedField)
    }

    private var distanceLabel: String {
        switch distanceUnit {
        case .km:
            return L10n.distanceMetersShort
        case .miles:
            return L10n.distanceFeetShort
        }
    }

    private var distanceUnitSuffix: String {
        let openParen = distanceLabel.firstIndex(of: "(")
        let closeParen = distanceLabel.lastIndex(of: ")")
        if let openParen, let closeParen, openParen < closeParen {
            let start = distanceLabel.index(after: openParen)
            return String(distanceLabel[start..<closeParen])
        }
        return distanceLabel
    }

    private var distanceStep: Double {
        displayedDistanceValue() >= 1000 ? 100 : 50
    }

    private var distanceMaximumValue: Double {
        switch distanceUnit {
        case .km:
            return 10_000
        case .miles:
            return 5_280_000
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

        segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
            lastRestSeconds: segment.lastRestSeconds,
            repeatCount: segment.repeatCount
        )
        segment.targetPaceSecondsPerKm = SegmentEditorValueRules.normalizedTargetPace(
            for: segment.distanceGoalMode,
            targetPaceSecondsPerKm: segment.targetPaceSecondsPerKm
        )

        onSave(segment)
    }

    private func normalizeEditingState() {
        segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
            lastRestSeconds: segment.lastRestSeconds,
            repeatCount: segment.repeatCount
        )
        segment.targetPaceSecondsPerKm = SegmentEditorValueRules.normalizedTargetPace(
            for: segment.distanceGoalMode,
            targetPaceSecondsPerKm: segment.targetPaceSecondsPerKm
        )
    }

    private func beginEditing(_ field: EditableField) {
        switch field {
        case .distance:
            editableValueText = distanceText
        case .repeats:
            editableValueText = segment.repeatCount.map(String.init) ?? ""
        case .rest:
            editableValueText = segment.restSeconds.map { Formatters.timeString(from: Double($0)) } ?? ""
        case .lastRest:
            guard canConfigureLastRest else {
                isLastRestInfoPresented = true
                return
            }
            editableValueText = segment.lastRestSeconds.map { Formatters.timeString(from: Double($0)) } ?? ""
        case .time:
            editableValueText = segment.targetTimeSeconds.map { Formatters.timeString(from: $0) } ?? ""
        case .pace:
            editableValueText = segment.targetPaceSecondsPerKm.map { Formatters.timeString(from: $0) } ?? ""
        }

        editableField = field
    }

    private func commitEditableField(_ field: EditableField) {
        switch field {
        case .distance:
            guard let value = Double(editableValueText), value > 0 else { return }
            updateDisplayedDistanceValue(value)
        case .repeats:
            let repeats = min(max(SegmentEditInputParser.parseRepeatCount(from: editableValueText), 0), 99)
            segment.repeatCount = repeats > 0 ? repeats : nil
            segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
                lastRestSeconds: segment.lastRestSeconds,
                repeatCount: segment.repeatCount
            )
        case .rest:
            let rest = min(max(SegmentEditInputParser.parseDurationSeconds(from: editableValueText), 0), 600)
            segment.restSeconds = rest > 0 ? rest : nil
        case .lastRest:
            guard canConfigureLastRest else {
                isLastRestInfoPresented = true
                return
            }
            let lastRest = min(max(SegmentEditInputParser.parseDurationSeconds(from: editableValueText), 0), 600)
            segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
                lastRestSeconds: lastRest > 0 ? lastRest : nil,
                repeatCount: segment.repeatCount
            )
        case .time:
            let time = min(max(SegmentEditInputParser.parseDurationSeconds(from: editableValueText), 0), 7200)
            let updatedTargets = SegmentEditorValueRules.updatedTargetsAfterSettingTime(
                seconds: time,
                currentPaceSecondsPerKm: segment.targetPaceSecondsPerKm
            )
            segment.targetTimeSeconds = updatedTargets.targetTimeSeconds
            segment.targetPaceSecondsPerKm = updatedTargets.targetPaceSecondsPerKm
        case .pace:
            let pace = min(max(SegmentEditInputParser.parseDurationSeconds(from: editableValueText), 0), 1200)
            let updatedTargets = SegmentEditorValueRules.updatedTargetsAfterSettingPace(
                secondsPerKm: pace,
                currentTargetTimeSeconds: segment.targetTimeSeconds
            )
            segment.targetTimeSeconds = updatedTargets.targetTimeSeconds
            segment.targetPaceSecondsPerKm = updatedTargets.targetPaceSecondsPerKm
        }
    }

    private func displayedDistanceValue() -> Double {
        switch distanceUnit {
        case .km:
            return segment.distanceMeters
        case .miles:
            return segment.distanceMeters * 3.28084
        }
    }

    private func updateDisplayedDistanceValue(_ newValue: Double) {
        let clamped = max(newValue, 0)
        switch distanceUnit {
        case .km:
            segment.distanceMeters = clamped
        case .miles:
            segment.distanceMeters = clamped / 3.28084
        }
        distanceText = CompanionSegmentEditorView.distanceText(for: segment, unit: distanceUnit)
    }

    private func keypadRows(for field: EditableField) -> [[String]] {
        switch field {
        case .distance:
            return distanceKeypadRows
        case .repeats:
            return repeatKeypadRows
        case .rest, .lastRest, .time, .pace:
            return durationKeypadRows
        }
    }

    private func handleKeyTap(_ key: String, for field: EditableField) {
        switch field {
        case .distance:
            SegmentEditInputParser.applyDistanceKey(key, to: &editableValueText)
        case .repeats:
            SegmentEditInputParser.applyRepeatKey(key, to: &editableValueText)
        case .rest, .lastRest, .time, .pace:
            SegmentEditInputParser.applyDurationKey(key, to: &editableValueText)
        }
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

private struct CompanionNumericKeypadSheet: View {
    let title: String
    @Binding var text: String
    let valueSuffix: String?
    let emptyDisplayValue: String?
    let keypadRows: [[String]]
    let onTapKey: (String) -> Void
    let onCancel: () -> Void
    let onDone: () -> Void
    @Environment(\.appTheme) private var theme

    private var displayedValue: String {
        let baseValue = text.isEmpty ? (emptyDisplayValue ?? " ") : text
        guard let valueSuffix, !valueSuffix.isEmpty else { return baseValue }
        return "\(baseValue) \(valueSuffix)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Tokens.Spacing.lg) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                        .fill(theme.background.neutralAction)

                    Text(displayedValue)
                        .font(.system(size: Tokens.FontSize.xxxl, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.text.neutral)
                        .padding(.leading, Tokens.Spacing.xxxxl)
                        .padding(.trailing, Tokens.Spacing.lg)
                        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .leading)
                }

                VStack(spacing: Tokens.Spacing.sm) {
                    ForEach(0..<keypadRows.count, id: \.self) { rowIndex in
                        HStack(spacing: Tokens.Spacing.sm) {
                            ForEach(keypadRows[rowIndex], id: \.self) { key in
                                CompanionKeypadButton(key: key) {
                                    onTapKey(key)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.xl)
            .padding(.vertical, Tokens.Spacing.lg)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.cancel, action: onCancel)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done, action: onDone)
                }
            }
        }
    }
}

private struct CompanionKeypadButton: View {
    let key: String
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: Tokens.FontSize.lg, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                        .fill(theme.background.neutralInteraction)
                )
        }
        .buttonStyle(.plain)
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

private struct CompanionSessionStatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private struct CompanionSessionDetailView: View {
    let session: Session
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var persistence: PersistenceManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var isDeleteConfirmationPresented = false

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.startedAt < $1.startedAt }
    }

    private var headerTitle: HistoryDateRangeParts {
        Formatters.historySessionDateRangeParts(start: session.startedAt, end: session.endedAt)
    }

    private var sessionUsesOpenIntervals: Bool {
        session.snapshotWorkoutPlan.distanceSegments.contains(where: \.usesOpenDistance)
    }

    private var sessionStats: [CompanionSessionStatItem] {
        let firstSegment = session.snapshotWorkoutPlan.distanceSegments.first
        var items: [CompanionSessionStatItem] = [
            CompanionSessionStatItem(label: L10n.laps, value: String(session.activeLapCount)),
            CompanionSessionStatItem(label: L10n.duration, value: Formatters.timeString(from: session.activeDurationSeconds))
        ]

        if let targetTime = firstSegment?.targetTimeSeconds {
            items.append(CompanionSessionStatItem(label: L10n.targetTimeLabel, value: Formatters.compactTimeString(from: targetTime)))
        }

        let primaryDistanceForPace: Double
        if session.mode.usesManualIntervals && !sessionUsesOpenIntervals {
            primaryDistanceForPace = session.totalDistanceMeters
            items.append(
                CompanionSessionStatItem(
                    label: L10n.distance,
                    value: session.totalDistanceMeters > 0
                        ? Formatters.distanceString(meters: session.totalDistanceMeters, unit: settings.distanceUnit)
                        : L10n.dash
                )
            )
        } else if session.mode == .gps || (session.mode == .dual && sessionUsesOpenIntervals) {
            let gpsDistance = session.totalGPSDistanceMeters ?? session.totalDistanceMeters
            primaryDistanceForPace = gpsDistance
            items.append(
                CompanionSessionStatItem(
                    label: L10n.gpsDistanceLabel,
                    value: gpsDistance > 0
                        ? Formatters.distanceString(meters: gpsDistance, unit: settings.distanceUnit)
                        : L10n.dash
                )
            )
        } else {
            primaryDistanceForPace = session.totalDistanceMeters
        }

        if session.mode == .dual && !sessionUsesOpenIntervals {
            items.append(
                CompanionSessionStatItem(
                    label: L10n.gpsDistanceLabel,
                    value: session.totalGPSDistanceMeters.flatMap { gpsDistanceMeters in
                        gpsDistanceMeters > 0
                            ? Formatters.distanceString(meters: gpsDistanceMeters, unit: settings.distanceUnit)
                            : nil
                    } ?? L10n.dash
                )
            )
        }

        items.append(
            CompanionSessionStatItem(
                label: L10n.averagePaceLabel,
                value: primaryDistanceForPace > 0
                    ? Formatters.paceString(
                        distanceMeters: primaryDistanceForPace,
                        durationSeconds: session.activeDurationSeconds,
                        unit: settings.distanceUnit
                    )
                    : L10n.dash
            )
        )

        return items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.sm) {
                    Text(L10n.details)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.text.neutral)
                        .padding(.leading, Tokens.ContentInsets.companionCard.leading + Tokens.Spacing.sm + Tokens.Spacing.xs)

                    Spacer(minLength: 0)

                    Text(headerTitle.timeText)
                        .font(.subheadline)
                        .foregroundStyle(theme.text.subtle)
                        .padding(.trailing, Tokens.ContentInsets.companionCard.leading + Tokens.Spacing.sm + Tokens.Spacing.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CompanionSessionStatsView(items: sessionStats)

                Text(L10n.laps)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.text.neutral)
                    .padding(.leading, Tokens.ContentInsets.companionCard.leading + Tokens.Spacing.sm + Tokens.Spacing.xs)
                    .padding(.trailing, Tokens.Spacing.xs)
                    .padding(.top, Tokens.Spacing.md)

                ForEach(sortedLaps, id: \.id) { lap in
                    CompanionSessionLapRow(lap: lap, trackingMode: session.mode, distanceUnit: settings.distanceUnit)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.xs)
        }
        .navigationTitle(headerTitle.dayText)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(L10n.redoActivity) {
                        settings.apply(workoutPlan: session.snapshotWorkoutPlan)
                        dismiss()
                    }

                    Button(L10n.deleteSession, role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .background(Color.clear)
        .alert(L10n.deleteSession, isPresented: $isDeleteConfirmationPresented) {
            Button(L10n.delete, role: .destructive) {
                persistence.deleteSession(session)
                dismiss()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteSessionConfirmMessage)
        }
    }
}

private struct CompanionSessionStatsView: View {
    let items: [CompanionSessionStatItem]
    @Environment(\.appTheme) private var theme

    private let columns = [
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading),
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Spacing.lg) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text(item.label)
                        .font(.subheadline)
                        .foregroundStyle(theme.text.subtle)
                        .padding(.top, Tokens.Spacing.xs)

                    Text(item.value)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.text.neutral)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(
            EdgeInsets(
                top: Tokens.ContentInsets.companionCard.top + Tokens.Spacing.sm,
                leading: Tokens.ContentInsets.companionCard.leading + Tokens.Spacing.sm,
                bottom: Tokens.ContentInsets.companionCard.bottom + Tokens.Spacing.sm,
                trailing: Tokens.ContentInsets.companionCard.trailing
            )
        )
        .background(theme.background.history)
        .cornerRadius(Tokens.Radius.companionListCell)
        .padding(.horizontal, Tokens.Spacing.xs)
        .padding(.bottom, Tokens.Spacing.xs)
    }
}

private struct CompanionSessionLapRow: View {
    let lap: Lap
    let trackingMode: TrackingMode
    let distanceUnit: DistanceUnit
    @Environment(\.appTheme) private var theme

    private let badgeOpticalLift: CGFloat = 2

    private let columns = [
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading),
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading)
    ]

    private var isRestLap: Bool {
        lap.lapType == .rest
    }

    private var badgeTitle: String {
        String(lap.index)
    }

    private var isSingleDigitLap: Bool {
        badgeTitle.count == 1
    }

    private var badgeMinSide: CGFloat {
        Tokens.FontSize.xxl + Tokens.Spacing.xs
    }

    private var activeHeaderTime: String {
        Formatters.compactTimeString(from: lap.durationSeconds)
    }

    private var rowInsets: EdgeInsets {
        if isRestLap {
            return EdgeInsets(
                top: Tokens.ContentInsets.companionCard.top,
                leading: Tokens.ContentInsets.companionCard.leading + Tokens.Spacing.sm,
                bottom: Tokens.ContentInsets.companionCard.bottom,
                trailing: Tokens.ContentInsets.companionCard.trailing
            )
        }

        return EdgeInsets(
            top: Tokens.ContentInsets.companionCard.top + Tokens.Spacing.sm,
            leading: Tokens.ContentInsets.companionCard.leading + Tokens.Spacing.sm,
            bottom: Tokens.ContentInsets.companionCard.bottom + Tokens.Spacing.sm,
            trailing: Tokens.ContentInsets.companionCard.trailing
        )
    }

    private var detailItems: [CompanionSessionStatItem] {
        var items: [CompanionSessionStatItem] = []

        guard !isRestLap else {
            if let averageHeartRateBPM = lap.averageHeartRateBPM {
                items.append(CompanionSessionStatItem(label: L10n.heartRate, value: "\(Int(averageHeartRateBPM)) bpm"))
            }
            return items
        }

        if trackingMode.usesManualIntervals {
            items.append(
                CompanionSessionStatItem(
                    label: L10n.distance,
                    value: lap.distanceMeters > 0
                        ? Formatters.distanceString(meters: lap.distanceMeters, unit: distanceUnit)
                        : L10n.dash
                )
            )

            items.append(
                CompanionSessionStatItem(
                    label: L10n.pace,
                    value: lap.distanceMeters > 0
                        ? Formatters.paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: distanceUnit)
                        : L10n.dash
                )
            )
        }

        if trackingMode.usesGPSDistance {
            let gpsDistance = trackingMode == .gps ? lap.distanceMeters : (lap.gpsDistanceMeters ?? 0)

            items.append(
                CompanionSessionStatItem(
                    label: L10n.gpsDistanceLabel,
                    value: gpsDistance > 0
                        ? Formatters.distanceString(meters: gpsDistance, unit: distanceUnit)
                        : L10n.dash
                )
            )

            items.append(
                CompanionSessionStatItem(
                    label: L10n.gpsPaceLabel,
                    value: gpsDistance > 0
                        ? Formatters.paceString(distanceMeters: gpsDistance, durationSeconds: lap.durationSeconds, unit: distanceUnit)
                        : L10n.dash
                )
            )
        }

        if let averageHeartRateBPM = lap.averageHeartRateBPM {
            items.append(CompanionSessionStatItem(label: L10n.heartRate, value: "\(Int(averageHeartRateBPM)) bpm"))
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack(alignment: isRestLap ? .center : .firstTextBaseline, spacing: Tokens.Spacing.sm) {
                if isRestLap {
                    Text(L10n.rest)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.historyRest)

                    Text(Formatters.compactTimeString(from: lap.durationSeconds))
                        .font(.headline.weight(.regular))
                        .foregroundStyle(theme.text.historyRest)
                } else {
                    Text(badgeTitle)
                        .font(.system(size: Tokens.FontSize.lg, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text.bold)
                        .frame(
                            minWidth: badgeMinSide,
                            minHeight: badgeMinSide
                        )
                        .background(
                            RoundedRectangle(
                                cornerRadius: isSingleDigitLap ? badgeMinSide / 2 : Tokens.Radius.medium,
                                style: .continuous
                            )
                                .fill(theme.background.bold)
                        )
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions[.firstTextBaseline] + badgeOpticalLift
                        }

                    Text(activeHeaderTime)
                        .font(.body.weight(.medium))
                        .foregroundStyle(theme.text.neutral)
                }
            }
            .padding(.top, isRestLap ? 0 : Tokens.Spacing.sm)
            .padding(.bottom, isRestLap ? 0 : Tokens.Spacing.sm)

            LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Spacing.lg) {
                ForEach(detailItems) { item in
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                        Text(item.label)
                            .font(.subheadline)
                            .foregroundStyle(isRestLap ? theme.text.historyRest : theme.text.subtle)
                            .padding(.top, Tokens.Spacing.xs)

                        Text(item.value)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isRestLap ? theme.text.historyRest : theme.text.neutral)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(rowInsets)
        .background(isRestLap ? theme.background.historyRest : theme.background.history)
        .cornerRadius(Tokens.Radius.companionListCell)
        .padding(.horizontal, Tokens.Spacing.xs)
        .padding(.bottom, Tokens.Spacing.xs)
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
        contentInsets: EdgeInsets = Tokens.ContentInsets.companionCard,
        fillColor: Color? = nil
    ) -> some View {
        modifier(CompanionListRowChrome(rowInsets: rowInsets, contentInsets: contentInsets, fillColor: fillColor))
    }

    func companionCardChrome() -> some View {
        self
    }
}

private struct CompanionNoPressOpacityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

private struct CompanionListRowChrome: ViewModifier {
    let rowInsets: EdgeInsets
    let contentInsets: EdgeInsets
    let fillColor: Color?
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(contentInsets)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                    .fill(fillColor ?? theme.background.history)
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
