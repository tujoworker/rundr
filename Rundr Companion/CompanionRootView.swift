import SwiftData
import SwiftUI
import UIKit
 
struct CompanionRootView: View {
    @EnvironmentObject private var persistence: PersistenceManager
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var transferCoordinator: CompanionTransferCoordinator
    @State private var selectedTab: CompanionTab = .workouts

    private enum CompanionTab: Hashable {
        case workouts
        case browser
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CompanionWorkoutsView()
                .tag(CompanionTab.workouts)
                .tabItem {
                    Label(L10n.workouts, systemImage: "figure.run")
                }

            CompanionBrowserView {
                selectedTab = .workouts
            }
            .tag(CompanionTab.browser)
                .tabItem {
                    Label(L10n.browser, systemImage: "square.grid.2x2")
                }

            CompanionSettingsView()
                .tag(CompanionTab.settings)
                .tabItem {
                    Label(L10n.more, systemImage: "ellipsis.circle")
                }
        }
        .tint(settings.primaryAccentColor)
        .sheet(item: $transferCoordinator.sharePayload, onDismiss: transferCoordinator.cleanupSharedFile) { payload in
            CompanionShareSheet(activityItems: [payload.url])
        }
        .fileImporter(
            isPresented: $transferCoordinator.isImporterPresented,
            allowedContentTypes: [.rundrPlan, .rundrSession]
        ) { result in
            transferCoordinator.handleImportResult(result, settings: settings, persistence: persistence)
        }
        .alert(item: $transferCoordinator.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(L10n.ok))
            )
        }
        .onOpenURL { url in
            guard url.isFileURL else { return }
            transferCoordinator.importTransfer(from: url, settings: settings, persistence: persistence)
        }
    }
}

private enum CompanionPresetRoute: Hashable {
    case new
    case saved(UUID)
    case predefined(String)
}

private struct CompanionWorkoutsView: View {
    @EnvironmentObject private var syncManager: WatchConnectivitySyncManager
    @EnvironmentObject private var persistence: PersistenceManager
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme
    @Query(sort: [SortDescriptor(\Session.startedAt, order: .reverse)]) private var sessions: [Session]
    @State private var visibleSessionCount = 2
    @State private var selectedSegment: DistanceSegment?
    @State private var selectedSession: Session?
    @State private var lastAddedDistanceMeters: Double = DistanceSegment.default.distanceMeters
    @State private var lastAddedUsesOpenDistance = false
    @State private var lastAddedRepeatCount: Int = 0
    @State private var lastAddedRestSeconds: Int = 0
    @State private var lastAddedLastRestSeconds: Int = 0
    @State private var lastAddedTargetPace: Int = 0
    @State private var lastAddedTargetTime: Int = 0
    @State private var addSegmentBounceTrigger = 0
    @State private var flashingSegmentIDs: Set<UUID> = []
    @State private var lastObservedSegments: [DistanceSegment] = []
    @State private var segmentEditMode: EditMode = .inactive

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
        return storedSegments.isEmpty ? [] : WorkoutPlanSupport.normalizedSegments(storedSegments)
    }

    private var visibleSessions: ArraySlice<Session> {
        sessions.prefix(visibleSessionCount)
    }

    private var canLoadMoreSessions: Bool {
        sessions.count > visibleSessionCount
    }

    private var workoutsCellContentInsets: EdgeInsets { CompanionSessionPlanStyle.cellContentInsets }

    private var workoutsSectionHeaderLeadingInset: CGFloat { CompanionSessionPlanStyle.sectionHeaderLeadingInset }

    private var workoutsRowInsets: EdgeInsets { CompanionSessionPlanStyle.rowInsets }

    private var canReorderSegments: Bool {
        segments.count > 1
    }

    private var isReorderingSegments: Bool {
        segmentEditMode.isEditing
    }

    private var reorderButtonTitle: String {
        isReorderingSegments ? L10n.done : L10n.reorder
    }

    private var canActivateReorder: Bool {
        canReorderSegments || isReorderingSegments
    }

    var body: some View {
        NavigationStack {
            List {
                if let liveWorkoutState = visibleLiveWorkoutState {
                    Section {
                        CompanionHomeSectionHeader(title: L10n.liveOnAppleWatch)
                            .padding(.leading, workoutsSectionHeaderLeadingInset)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        HStack(spacing: 0) {
                            CompanionLiveWorkoutCard(state: liveWorkoutState)
                                .padding(
                                    EdgeInsets(
                                        top: workoutsCellContentInsets.leading,
                                        leading: workoutsCellContentInsets.leading,
                                        bottom: workoutsCellContentInsets.leading,
                                        trailing: workoutsCellContentInsets.trailing
                                    )
                                )
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .listRowCardChrome(rowInsets: workoutsRowInsets, contentInsets: EdgeInsets())
                    }
                    .listSectionSeparator(.hidden)
                }

                Section {
                    HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.md) {
                        CompanionHomeSectionHeader(title: L10n.intervalsTitle)

                        Spacer(minLength: Tokens.Spacing.md)

                        if canReorderSegments {
                            Button(reorderButtonTitle) {
                                segmentEditMode = isReorderingSegments ? .inactive : .active
                            }
                                .foregroundStyle(theme.isDark ? theme.text.subtle : settings.primaryAccentColor)
                        }
                    }
                    .padding(.top, CompanionSessionPlanStyle.headerTopSpacing)
                    .padding(.leading, workoutsSectionHeaderLeadingInset)
                    .padding(.trailing, workoutsSectionHeaderLeadingInset)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    if segments.isEmpty {
                        CompanionEmptyStateCard(
                            title: L10n.noSessionPlanIntervalsTitle,
                            detail: L10n.noSessionPlanIntervalsDetail
                        )
                        .listRowCardChrome(
                            rowInsets: workoutsRowInsets,
                            contentInsets: workoutsCellContentInsets
                        )
                    } else {
                        ForEach(segments) { segment in
                            Button {
                                guard !isReorderingSegments else { return }
                                selectedSegment = segment
                            } label: {
                                HStack(spacing: 0) {
                                    CompanionSegmentRow(segment: segment, distanceUnit: settings.distanceUnit)
                                        .padding(workoutsCellContentInsets)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(CompanionNoPressOpacityButtonStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        deleteSegment(segment)
                                    }
                                } label: {
                                    Label(L10n.delete, systemImage: "trash")
                                }
                            }
                            .listRowCardChrome(
                                rowInsets: workoutsRowInsets,
                                contentInsets: EdgeInsets(),
                                fillColor: flashingSegmentIDs.contains(segment.id)
                                    ? theme.background.emphasisAction(settings.primaryAccentColor)
                                    : nil
                            )
                            .animation(.easeInOut(duration: 0.25), value: flashingSegmentIDs.contains(segment.id))
                            .contentShape(Rectangle())
                        }
                        .onMove(perform: moveSegments)
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
                    .listRowInsets(workoutsRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listSectionSeparator(.hidden)

                Section {
                    CompanionHomeSectionHeader(title: L10n.syncedSessions)
                        .padding(.leading, workoutsSectionHeaderLeadingInset)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if sessions.isEmpty {
                        CompanionEmptyStateCard(title: L10n.noSyncedSessionsYet)
                            .listRowCardChrome(
                                rowInsets: workoutsRowInsets,
                                contentInsets: workoutsCellContentInsets
                            )
                    } else {
                        ForEach(visibleSessions, id: \.id) { session in
                            Button {
                                selectedSession = session
                            } label: {
                                HStack(spacing: 0) {
                                    CompanionSessionRow(session: session)
                                        .padding(workoutsCellContentInsets)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    persistence.deleteSession(session)
                                } label: {
                                    Label(L10n.delete, systemImage: "trash")
                                }
                            }
                            .listRowCardChrome(rowInsets: workoutsRowInsets, contentInsets: EdgeInsets())
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
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .listSectionSeparator(.hidden)
            }
            .onAppear {
                syncLastAddedValues()
                if !lastObservedSegments.isEmpty, lastObservedSegments != settings.distanceSegments {
                    flashChangedSegments(oldSegments: lastObservedSegments, newSegments: settings.distanceSegments)
                }
                lastObservedSegments = settings.distanceSegments
            }
            .navigationDestination(item: $selectedSegment) { segment in
                CompanionSegmentEditorView(
                    segment: segment,
                    distanceUnit: settings.distanceUnit
                ) { updatedSegment in
                    commitSegment(updatedSegment)
                } onDelete: { segmentToDelete in
                    deleteSegment(segmentToDelete, keepsAtLeastOne: false)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedSession != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedSession = nil
                    }
                }
            )) {
                if let selectedSession {
                    CompanionSessionDetailView(session: selectedSession)
                }
            }
            .onChange(of: settings.distanceSegments) { oldValue, newValue in
                syncLastAddedValues()
                flashChangedSegments(oldSegments: oldValue, newSegments: newValue)
                lastObservedSegments = newValue
            }
            .navigationTitle(L10n.workouts)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .themedCompanionList()
            .environment(\.editMode, $segmentEditMode)
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
        updatedSegments.append(WorkoutPlanSupport.nextSegmentForAppend(from: updatedSegments))
        applySegments(updatedSegments)
    }

    private func moveSegments(fromOffsets: IndexSet, toOffset: Int) {
        applySegments(
            WorkoutPlanSupport.reorderedSegments(
                segments,
                fromOffsets: fromOffsets,
                toOffset: toOffset
            )
        )
    }

    private func deleteSegment(_ segment: DistanceSegment, keepsAtLeastOne: Bool = true) {
        var updatedSegments = segments
        updatedSegments.removeAll { $0.id == segment.id }

        if keepsAtLeastOne || !updatedSegments.isEmpty {
            applySegments(updatedSegments)
        } else {
            settings.distanceSegments = []
            settings.trackingMode = .distanceDistance
        }
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

        applySegments(updatedSegments)
    }

    private func applySegments(_ updatedSegments: [DistanceSegment]) {
        let normalizedSegments = WorkoutPlanSupport.normalizedSegments(updatedSegments)
        settings.distanceSegments = normalizedSegments
        settings.trackingMode = normalizedSegments.contains(where: \.usesOpenDistance) ? .dual : .distanceDistance
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

        withAnimation(.easeInOut(duration: 0.25)) {
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
    let onUseActivity: () -> Void

    var body: some View {
        NavigationStack {
            CompanionPresetLibraryView(onUseActivity: onUseActivity)
        }
    }
}

private struct CompanionPresetLibraryView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme
    @State private var selectedRoute: CompanionPresetRoute?
    let onUseActivity: () -> Void

    private var browseCellContentInsets: EdgeInsets {
        let baseInsets = Tokens.ContentInsets.companionCard

        return EdgeInsets(
            top: baseInsets.top,
            leading: baseInsets.leading * 2,
            bottom: baseInsets.bottom,
            trailing: baseInsets.trailing * 2
        )
    }

    private var browseSectionHeaderLeadingInset: CGFloat {
        Tokens.ContentInsets.companionCard.leading * 2
    }

    private var browseRowInsets: EdgeInsets {
        let baseInsets = Tokens.ListRowInsets.card
        let horizontalInset = (Tokens.Spacing.xxl + Tokens.Spacing.xxxl) / 2

        return EdgeInsets(
            top: baseInsets.top,
            leading: horizontalInset,
            bottom: baseInsets.bottom,
            trailing: horizontalInset
        )
    }

    private func titleComponents(
        workoutPlan: WorkoutPlanSnapshot,
        customTitle: String? = nil,
        fallbackTitle: String? = nil
    ) -> String {
        WorkoutPlanListTitleResolver.title(
            for: workoutPlan,
            customTitle: customTitle,
            fallbackTitle: fallbackTitle,
            unit: settings.distanceUnit
        )
    }

    var body: some View {
        List {
            Section {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.md) {
                    CompanionHomeSectionHeader(title: L10n.myIntervals)

                    Spacer(minLength: Tokens.Spacing.md)

                    Button {
                        selectedRoute = .new
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: Tokens.ControlSize.companionAddIcon, weight: .semibold))
                            .foregroundStyle(settings.primaryAccentColor)
                            .frame(width: Tokens.ControlSize.companionAddIcon, height: Tokens.ControlSize.companionAddIcon)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.addInterval)
                }
                .padding(.leading, browseSectionHeaderLeadingInset)
                .padding(.trailing, browseSectionHeaderLeadingInset)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if settings.intervalPresets.isEmpty {
                    CompanionEmptyStateCard(
                        title: L10n.noSavedIntervalsYet,
                        detail: L10n.savedIntervalsPlaceholderDetail
                    )
                    .listRowCardChrome(
                        rowInsets: browseRowInsets,
                        contentInsets: browseCellContentInsets
                    )
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                } else {
                    ForEach(settings.intervalPresets) { preset in
                        let title = titleComponents(
                            workoutPlan: preset.workoutPlan,
                            customTitle: preset.trimmedCustomTitle
                        )

                        Button {
                            selectedRoute = .saved(preset.id)
                        } label: {
                            HStack(spacing: 0) {
                                CompanionPresetRowView(
                                    title: title,
                                    subtitle: preset.workoutPlan.displayDetail(unit: settings.distanceUnit),
                                    usageCount: settings.presetUsageCount(for: preset.workoutPlan)
                                )
                                .padding(browseCellContentInsets)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                settings.deleteIntervalPreset(id: preset.id)
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                            }
                        }
                        .listRowCardChrome(
                            rowInsets: browseRowInsets,
                            contentInsets: EdgeInsets()
                        )
                        .contentShape(Rectangle())
                    }
                }
            }
            .listSectionSeparator(.hidden)

            Section {
                CompanionHomeSectionHeader(title: L10n.predefined)
                    .padding(.top, Tokens.Spacing.xxxl)
                    .padding(.leading, browseSectionHeaderLeadingInset)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                ForEach(SettingsStore.predefinedIntervalPresets) { preset in
                    let title = titleComponents(
                        workoutPlan: preset.workoutPlan,
                        fallbackTitle: preset.title
                    )

                    Button {
                        selectedRoute = .predefined(preset.id)
                    } label: {
                        HStack(spacing: 0) {
                            CompanionPresetRowView(
                                title: title,
                                subtitle: preset.workoutPlan.displayDetail(unit: settings.distanceUnit),
                                usageCount: settings.presetUsageCount(for: preset.workoutPlan)
                            )
                            .padding(browseCellContentInsets)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowCardChrome(
                        rowInsets: browseRowInsets,
                        contentInsets: EdgeInsets()
                    )
                    .contentShape(Rectangle())
                }
            }
            .listSectionSeparator(.hidden)
        }
        .navigationTitle(L10n.browser)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedRoute) { route in
            CompanionPresetRouteDestinationView(route: route, onUseActivity: onUseActivity)
        }
        .themedCompanionList()
    }
}

private struct CompanionPresetRouteDestinationView: View {
    let route: CompanionPresetRoute
    let onUseActivity: () -> Void

    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        switch route {
        case .new:
            CompanionWorkoutEditorView(
                headerTitle: L10n.newInterval,
                subtitle: nil,
                initialWorkoutPlan: WorkoutPlanSnapshot(trackingMode: .distanceDistance),
                initialCustomTitle: nil,
                initialCustomDescription: nil,
                initialStoredPresetID: nil,
                showsCustomTitle: true,
                showsInlineUseItNowButton: false,
                autoSaveOnSegmentDone: true
            ) { workoutPlan, customTitle, customDescription, storedPresetID in
                _ = settings.saveIntervalPreset(
                    workoutPlan,
                    customTitle: customTitle,
                    existingPresetID: storedPresetID,
                    customDescription: customDescription,
                    updatesDescription: true
                )
                settings.apply(workoutPlan: workoutPlan)
                onUseActivity()
            }

        case let .saved(presetID):
            if let preset = settings.intervalPresets.first(where: { $0.id == presetID }) {
                CompanionWorkoutEditorView(
                    headerTitle: L10n.editInterval,
                    subtitle: preset.trimmedCustomTitle ?? L10n.presetCountSummary(preset.workoutPlan.distanceSegments.count),
                    initialWorkoutPlan: preset.workoutPlan,
                    initialCustomTitle: preset.customTitle,
                    initialCustomDescription: preset.customDescription,
                    initialStoredPresetID: preset.id,
                    showsCustomTitle: true,
                    showsInlineUseItNowButton: true,
                    autoSaveOnSegmentDone: true
                ) { workoutPlan, customTitle, customDescription, storedPresetID in
                    _ = settings.saveIntervalPreset(
                        workoutPlan,
                        customTitle: customTitle,
                        existingPresetID: storedPresetID ?? preset.id,
                        customDescription: customDescription,
                        updatesDescription: true
                    )
                    settings.apply(workoutPlan: workoutPlan)
                    onUseActivity()
                }
            } else {
                EmptyView()
            }

        case let .predefined(presetID):
            if let preset = SettingsStore.predefinedIntervalPresets.first(where: { $0.id == presetID }) {
                CompanionWorkoutEditorView(
                    headerTitle: L10n.adjustSettings,
                    subtitle: preset.title,
                    initialWorkoutPlan: preset.workoutPlan,
                    initialCustomTitle: preset.title,
                    initialCustomDescription: preset.description,
                    initialStoredPresetID: nil,
                    showsCustomTitle: true,
                    showsInlineUseItNowButton: true,
                    autoSaveOnSegmentDone: true
                ) { workoutPlan, customTitle, customDescription, storedPresetID in
                    let normalizedTitle = IntervalPreset.sanitizeTitle(customTitle)
                    let effectiveTitle = normalizedTitle == IntervalPreset.sanitizeTitle(preset.title)
                        ? nil
                        : normalizedTitle
                    let normalizedDescription = IntervalPreset.sanitizeDescription(customDescription)
                    if IntervalPresetSignature(workoutPlan: workoutPlan) != preset.signature
                        || effectiveTitle != nil
                        || normalizedDescription != IntervalPreset.sanitizeDescription(preset.description) {
                        _ = settings.saveIntervalPreset(
                            workoutPlan,
                            customTitle: effectiveTitle,
                            existingPresetID: storedPresetID,
                            customDescription: normalizedDescription,
                            updatesDescription: true
                        )
                    }
                    settings.apply(workoutPlan: workoutPlan)
                    onUseActivity()
                }
            } else {
                EmptyView()
            }
        }
    }
}

private struct CompanionSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var transferCoordinator: CompanionTransferCoordinator

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CompanionRestModeSettingsDetailView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.restMode,
                            value: settings.restMode.displayName,
                            systemImage: "figure.cooldown"
                        )
                    }
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)

                    NavigationLink {
                        CompanionDistanceUnitSettingsDetailView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.unit,
                            value: settings.distanceUnit.displayName,
                            systemImage: "ruler"
                        )
                    }
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)

                    NavigationLink {
                        CompanionAppearanceSettingsDetailView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.appearance,
                            value: settings.appearanceMode.displayName,
                            systemImage: "circle.lefthalf.filled"
                        )
                    }
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)

                    NavigationLink {
                        CompanionColorSettingsDetailView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.color,
                            value: settings.primaryColor.displayName,
                            systemImage: "paintpalette.fill"
                        )
                    }
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)
                }

                Section {
                    Button {
                        transferCoordinator.presentImporter()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.importFile,
                            value: "",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.plain)
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)
                }

                Section {
                    NavigationLink {
                        CompanionIntroView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.intro,
                            value: "",
                            systemImage: "sparkles"
                        )
                    }
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)

                    NavigationLink {
                        CompanionHelpView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.help,
                            value: "",
                            systemImage: "questionmark.circle"
                        )
                    }
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)

                    NavigationLink {
                        CompanionAboutDetailView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.about,
                            value: "",
                            systemImage: "info.circle"
                        )
                    }
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)

                    NavigationLink {
                        CompanionPrivacyPolicyView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.privacyPolicy,
                            value: "",
                            systemImage: "hand.raised"
                        )
                    }
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)

                    NavigationLink {
                        CompanionTermsOfUseView()
                    } label: {
                        CompanionSettingsNavigationRow(
                            title: L10n.termsOfUse,
                            value: "",
                            systemImage: "doc.text"
                        )
                    }
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.overviewRowContentInsets)
                }
            }
            .navigationTitle(L10n.preferences)
            .navigationBarTitleDisplayMode(.large)
            .themedCompanionSettingsList()
        }
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

                            CompanionSelectionCheckmark(
                                isSelected: settings.distanceUnit == unit,
                                tint: settings.primaryAccentColor
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.detailRowContentInsets)
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

                            CompanionSelectionCheckmark(
                                isSelected: settings.restMode == mode,
                                tint: settings.primaryAccentColor
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.detailRowContentInsets)
                }
            }

            Section {
                CompanionHelpCard(topic: .autoRest)
                    .listRowInsets(CompanionPreferencesStyle.detailRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                CompanionHelpCard(topic: .restMode)
                    .listRowInsets(CompanionPreferencesStyle.detailRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
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

private struct CompanionEmptyStateCard: View {
    let title: String
    var detail: String? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.text.neutral)

            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.text.subtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, CompanionSessionPlanStyle.emptyStateVerticalPadding)
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

                            CompanionSelectionCheckmark(
                                isSelected: settings.appearanceMode == mode,
                                tint: settings.primaryAccentColor
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.detailRowContentInsets)
                }
            }

            Section {
                CompanionSettingsToggleRow(
                    title: L10n.syncAppearanceMode,
                    detail: L10n.syncAppearanceModeDetail,
                    systemImage: "circle.lefthalf.filled",
                    isOn: $settings.syncAppearanceMode
                )
                .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.detailRowContentInsets)
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

                            CompanionSelectionCheckmark(
                                isSelected: settings.primaryColor == color,
                                tint: settings.primaryAccentColor
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .companionSettingsOptionRowChrome(contentInsets: CompanionPreferencesStyle.detailRowContentInsets)
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
    var value: String? = nil
    var tintColor: Color? = nil
    let systemImage: String
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    private var iconBackgroundColor: Color {
        theme.background.neutralInteraction
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.md) {
            CompanionSettingsLeadingIcon(systemImage: systemImage, tintColor: tintColor)

            Text(title)
                .foregroundStyle(theme.text.neutral)

            Spacer()

            if let value, !value.isEmpty {
                Text(value)
                    .foregroundStyle(theme.text.subtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var companionSettingsIcon: some View {
        let iconTint = tintColor ?? settings.primaryAccentColor
        let icon = Image(systemName: systemImage)
            .font(.system(size: Tokens.FontSize.md, weight: .semibold))

        icon
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(iconTint)
    }
}

private struct CompanionSettingsToggleRow: View {
    let title: String
    var detail: String? = nil
    let systemImage: String
    @Binding var isOn: Bool

    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.md) {
            CompanionSettingsLeadingIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                Text(title)
                    .foregroundStyle(theme.text.neutral)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(theme.text.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Tokens.Spacing.md)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(settings.primaryAccentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct CompanionSettingsLeadingIcon: View {
    let systemImage: String
    var tintColor: Color? = nil
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        companionSettingsIcon
            .frame(width: 28, height: 28)
            .background {
                if !theme.isDark {
                    RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                        .fill(theme.background.neutralInteraction)
                }
            }
    }

    @ViewBuilder
    private var companionSettingsIcon: some View {
        let iconTint = tintColor ?? settings.primaryAccentColor
        let icon = Image(systemName: systemImage)
            .font(.system(size: Tokens.FontSize.md, weight: .semibold))

        icon
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(iconTint)
    }
}

private enum CompanionPreferencesStyle {
    static var detailRowInsets: EdgeInsets {
        EdgeInsets(
            top: 0,
            leading: Tokens.ListRowInsets.companionCard.leading,
            bottom: 0,
            trailing: Tokens.ListRowInsets.companionCard.trailing
        )
    }

    static var overviewRowContentInsets: EdgeInsets {
        let baseInsets = Tokens.ContentInsets.companionCard
        let horizontalInset = baseInsets.leading

        return EdgeInsets(
            top: Tokens.Spacing.xxxl,
            leading: horizontalInset,
            bottom: Tokens.Spacing.xxxl,
            trailing: horizontalInset
        )
    }

    static var detailRowContentInsets: EdgeInsets {
        let horizontalInset = Tokens.ContentInsets.companionCard.leading

        return EdgeInsets(
            top: Tokens.Spacing.xxxl,
            leading: horizontalInset,
            bottom: Tokens.Spacing.xxxl,
            trailing: horizontalInset
        )
    }
}

private struct CompanionSelectionCheckmark: View {
    let isSelected: Bool
    let tint: Color

    var body: some View {
        Image(systemName: "checkmark")
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .opacity(isSelected ? 1 : 0)
            .frame(width: 18, alignment: .trailing)
    }
}

private struct CompanionMetricPill: View {
    enum TextStyle {
        case rounded
        case regular
    }

    let title: String
    let value: String
    var valueLineLimit: Int? = nil
    var textStyle: TextStyle = .rounded
    @Environment(\.appTheme) private var theme

    private var titleFont: Font {
        switch textStyle {
        case .rounded:
            .system(size: Tokens.FontSize.md, weight: .regular, design: .rounded)
        case .regular:
            .subheadline
        }
    }

    private var valueFont: Font {
        switch textStyle {
        case .rounded:
            .headline.weight(.semibold)
        case .regular:
            .body.weight(.semibold)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(theme.text.subtle)
            Text(value)
                .font(valueFont)
                .foregroundStyle(theme.text.neutral)
                .lineLimit(valueLineLimit)
                .truncationMode(.tail)
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
        HStack(alignment: .top, spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.md) {
                    if let badgeCount = CompanionPresetBadgeResolver.badgeCount(usageCount: usageCount) {
                        CompanionPresetUsageBadge(count: badgeCount)
                    }

                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.text.neutral)

                    Spacer(minLength: Tokens.Spacing.md)

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.subtle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: Tokens.Spacing.xxxxl) {
                    CompanionMetricPill(
                        title: L10n.intervalsTitle,
                        value: subtitle,
                        valueLineLimit: 2,
                        textStyle: .regular
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Tokens.Spacing.xs)
        .padding(.bottom, Tokens.Spacing.sm)
    }
}

private struct CompanionPresetUsageBadge: View {
    let count: Int
    @Environment(\.appTheme) private var theme
    private let opticalLift: CGFloat = 2

    var body: some View {
        Text(L10n.usedCount(count))
            .font(.system(size: Tokens.FontSize.sm, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.text.bold)
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xxxs)
            .background(theme.background.countBadge)
            .clipShape(Capsule(style: .continuous))
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[.firstTextBaseline] + opticalLift
            }
    }
}

private struct CompanionWorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var transferCoordinator: CompanionTransferCoordinator
    @Environment(\.appTheme) private var theme

    let headerTitle: String
    let subtitle: String?
    let initialWorkoutPlan: WorkoutPlanSnapshot
    let initialCustomTitle: String?
    let initialCustomDescription: String?
    let initialStoredPresetID: UUID?
    let showsCustomTitle: Bool
    let showsInlineUseItNowButton: Bool
    let autoSaveOnSegmentDone: Bool
    let onContinue: (WorkoutPlanSnapshot, String?, String?, UUID?) -> Void

    @State private var trackingMode: TrackingMode = .distanceDistance
    @State private var restMode: RestMode = .manual
    @State private var distanceUnit: DistanceUnit = .km
    @State private var segments: [DistanceSegment] = []
    @State private var customTitle: String = ""
    @State private var customDescription: String = ""
    @State private var storedPresetID: UUID?
    @State private var selectedSegment: DistanceSegment?
    @State private var addSegmentBounceTrigger = 0
    @State private var hasLoadedSnapshot = false
    @State private var isUseActivityConfirmationPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var segmentEditMode: EditMode = .inactive

    private var canDeletePreset: Bool {
        storedPresetID != nil
    }

    private var canReorderSegments: Bool {
        segments.count > 1
    }

    private var isReorderingSegments: Bool {
        segmentEditMode.isEditing
    }

    private var reorderButtonTitle: String {
        isReorderingSegments ? L10n.done : L10n.reorder
    }

    private var canActivateReorder: Bool {
        canReorderSegments || isReorderingSegments
    }

    private var customTitleRowContentInsets: EdgeInsets {
        EdgeInsets(
            top: Tokens.Spacing.xxxxl,
            leading: Tokens.Spacing.xxxl,
            bottom: Tokens.Spacing.xxxxl,
            trailing: Tokens.Spacing.xxxl
        )
    }

    private var showsCustomDescription: Bool {
        showsCustomTitle || initialCustomDescription != nil || !customDescription.isEmpty
    }

    private var showsCustomMetadataSection: Bool {
        showsCustomTitle || showsCustomDescription
    }

    var body: some View {
        List {
            if showsCustomMetadataSection {
                Section {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                        if showsCustomTitle {
                            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                                Text(L10n.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.text.subtle)

                                TextField(
                                    "",
                                    text: $customTitle,
                                    prompt: Text(L10n.optionalTitlePlaceholder)
                                        .foregroundStyle(theme.text.subtle)
                                )
                                .textInputAutocapitalization(.words)
                                .multilineTextAlignment(.leading)
                                .font(.body.weight(.medium))
                                .foregroundStyle(theme.text.neutral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if showsCustomDescription {
                            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                                Text(L10n.description)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.text.subtle)

                                TextField(
                                    "",
                                    text: $customDescription,
                                    prompt: Text(L10n.optionalDescriptionPlaceholder)
                                        .foregroundStyle(theme.text.subtle),
                                    axis: .vertical
                                )
                                .lineLimit(1...3)
                                .multilineTextAlignment(.leading)
                                .font(.subheadline)
                                .foregroundStyle(theme.text.neutral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .listRowCardChrome(
                        rowInsets: CompanionSessionPlanStyle.rowInsets,
                        contentInsets: customTitleRowContentInsets
                    )
                }
                .listSectionSeparator(.hidden)
            }

            Section {
                HStack(alignment: .center, spacing: Tokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                        CompanionHomeSectionHeader(title: L10n.intervalsTitle)

                        if canActivateReorder {
                            Button(reorderButtonTitle) {
                                segmentEditMode = isReorderingSegments ? .inactive : .active
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.isDark ? theme.text.subtle : settings.primaryAccentColor)
                        }
                    }

                    Spacer(minLength: Tokens.Spacing.md)

                    if showsInlineUseItNowButton {
                        Button {
                            isUseActivityConfirmationPresented = true
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: Tokens.ControlSize.companionAddIcon, weight: .semibold))
                                .foregroundStyle(settings.primaryAccentColor)
                                .frame(width: Tokens.ControlSize.companionAddIcon, height: Tokens.ControlSize.companionAddIcon)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.useItNow)
                    }
                }
                .padding(
                    .top,
                    (showsCustomMetadataSection ? Tokens.Spacing.xxxl : 0) + CompanionSessionPlanStyle.headerTopSpacing
                )
                .padding(.leading, CompanionSessionPlanStyle.cellContentInsets.leading)
                .padding(.trailing, CompanionSessionPlanStyle.cellContentInsets.trailing)
                .padding(.bottom, Tokens.Spacing.xs)
                .listRowInsets(CompanionSessionPlanStyle.rowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if segments.isEmpty {
                    CompanionEmptyStateCard(
                        title: L10n.noSessionPlanIntervalsTitle,
                        detail: L10n.noSessionPlanIntervalsDetail
                    )
                    .listRowCardChrome(
                        rowInsets: CompanionSessionPlanStyle.rowInsets,
                        contentInsets: CompanionSessionPlanStyle.cellContentInsets
                    )
                } else {
                    ForEach(segments) { segment in
                        Button {
                            guard !isReorderingSegments else { return }
                            selectedSegment = segment
                        } label: {
                            HStack(spacing: 0) {
                                CompanionSegmentRow(segment: segment, distanceUnit: distanceUnit)
                                    .padding(CompanionSessionPlanStyle.cellContentInsets)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(CompanionNoPressOpacityButtonStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowCardChrome(
                            rowInsets: CompanionSessionPlanStyle.rowInsets,
                            contentInsets: EdgeInsets()
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    deleteSegment(segment)
                                }
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .onMove(perform: moveSegments)
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
                .listRowInsets(CompanionSessionPlanStyle.rowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listSectionSeparator(.hidden)

        }
        .navigationTitle(headerTitle)
        .themedCompanionList()
        .navigationDestination(item: $selectedSegment) { segment in
            CompanionSegmentEditorView(
                segment: segment,
                distanceUnit: distanceUnit
            ) { updatedSegment in
                commitSegment(updatedSegment)
            } onDelete: { segmentToDelete in
                deleteSegment(segmentToDelete, keepsAtLeastOne: false)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isUseActivityConfirmationPresented = true
                    } label: {
                        Label(L10n.useItNow, systemImage: "play.fill")
                    }

                    Button {
                        transferCoordinator.sharePlan(
                            workoutPlan: currentWorkoutPlan(),
                            title: IntervalPreset.sanitizeTitle(customTitle),
                            description: IntervalPreset.sanitizeDescription(customDescription),
                            settings: settings
                        )
                    } label: {
                        Label(L10n.sharePlan, systemImage: "square.and.arrow.up")
                    }

                    if canDeletePreset {
                        Button(role: .destructive) {
                            isDeleteConfirmationPresented = true
                        } label: {
                            Label(L10n.deletePlan, systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert(L10n.useActivityConfirmationTitle, isPresented: $isUseActivityConfirmationPresented) {
            Button(L10n.yes) {
                commitWorkoutPlan()
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
        .onAppear(perform: loadSnapshot)
        .environment(\.editMode, $segmentEditMode)
    }

    private func loadSnapshot() {
        guard !hasLoadedSnapshot else { return }
        hasLoadedSnapshot = true

        let snapshot = initialWorkoutPlan
        trackingMode = snapshot.trackingMode == .gps ? .distanceDistance : snapshot.trackingMode
        restMode = snapshot.restMode
        distanceUnit = settings.distanceUnit
        segments = snapshot.distanceSegments
        customTitle = initialCustomTitle ?? ""
        customDescription = initialCustomDescription ?? ""
        storedPresetID = initialStoredPresetID
        syncTrackingModeWithSegments()
    }

    private func animateSegmentAddition() {
        addSegmentBounceTrigger += 1
        withAnimation(.snappy(duration: 0.3, extraBounce: 0.12)) {
            addSegment()
        }
    }

    private func addSegment() {
        segments.append(WorkoutPlanSupport.nextSegmentForAppend(from: segments))
        segments = WorkoutPlanSupport.normalizedSegments(segments)
        syncTrackingModeWithSegments()
        persistPresetAfterEditIfNeeded()
    }

    private func moveSegments(fromOffsets: IndexSet, toOffset: Int) {
        segments = WorkoutPlanSupport.reorderedSegments(
            segments,
            fromOffsets: fromOffsets,
            toOffset: toOffset
        )
        syncTrackingModeWithSegments()
        persistPresetAfterEditIfNeeded()
    }

    private func deleteSegments(at offsets: IndexSet) {
        segments.remove(atOffsets: offsets)
        segments = WorkoutPlanSupport.normalizedSegments(segments)
        syncTrackingModeWithSegments()
        persistPresetAfterEditIfNeeded()
    }

    private func deleteSegment(_ segment: DistanceSegment, keepsAtLeastOne: Bool = true) {
        segments.removeAll { $0.id == segment.id }
        if keepsAtLeastOne || !segments.isEmpty {
            segments = WorkoutPlanSupport.normalizedSegments(segments)
        }
        syncTrackingModeWithSegments()
        persistPresetAfterEditIfNeeded()
    }

    private func commitSegment(_ updatedSegment: DistanceSegment) {
        guard let index = segments.firstIndex(where: { $0.id == updatedSegment.id }) else { return }
        segments[index] = updatedSegment
        segments = WorkoutPlanSupport.normalizedSegments(segments)
        syncTrackingModeWithSegments()
        persistPresetAfterEditIfNeeded()
    }

    private func currentWorkoutPlan() -> WorkoutPlanSnapshot {
        WorkoutPlanSupport.makeWorkoutPlan(
            requestedTrackingMode: trackingMode,
            currentTrackingMode: settings.trackingMode,
            fallbackDistance: initialWorkoutPlan.distanceLapDistanceMeters,
            segments: segments,
            restMode: restMode
        )
    }

    private func persistPresetAfterEditIfNeeded() {
        guard autoSaveOnSegmentDone, showsCustomTitle else { return }

        let savedPreset = settings.saveIntervalPreset(
            currentWorkoutPlan(),
            customTitle: customTitle,
            existingPresetID: storedPresetID,
            customDescription: customDescription,
            updatesDescription: true
        )
        storedPresetID = savedPreset?.id ?? storedPresetID
        if let savedPreset {
            customTitle = savedPreset.customTitle ?? customTitle
            customDescription = savedPreset.customDescription ?? customDescription
        }
    }

    private func commitWorkoutPlan() {
        let workoutPlan = currentWorkoutPlan()
        settings.distanceUnit = distanceUnit
        onContinue(
            workoutPlan,
            IntervalPreset.sanitizeTitle(customTitle),
            IntervalPreset.sanitizeDescription(customDescription),
            storedPresetID
        )
        dismiss()
    }

    private func deletePreset() {
        guard let storedPresetID else { return }
        settings.deleteIntervalPreset(id: storedPresetID)
        dismiss()
    }

    private func syncTrackingModeWithSegments() {
        let requiresGPS = segments.contains(where: \.usesOpenDistance)
        trackingMode = requiresGPS ? .dual : .distanceDistance
    }
}

private enum CompanionSessionPlanStyle {
    static var headerTopSpacing: CGFloat {
        Tokens.Spacing.lg
    }

    static var emptyStateVerticalPadding: CGFloat {
        Tokens.Spacing.xl
    }

    static var titleOnlyRowMinHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .title3).lineHeight + (emptyStateVerticalPadding * 2)
    }

    static var cellContentInsets: EdgeInsets {
        let baseInsets = Tokens.ContentInsets.companionCard

        return EdgeInsets(
            top: baseInsets.top,
            leading: baseInsets.leading * 2,
            bottom: baseInsets.bottom,
            trailing: baseInsets.trailing * 2
        )
    }

    static var sectionHeaderLeadingInset: CGFloat {
        Tokens.ContentInsets.companionCard.leading * 2
    }

    static var rowInsets: EdgeInsets {
        let baseInsets = Tokens.ListRowInsets.card
        let horizontalInset = (Tokens.Spacing.xxl + Tokens.Spacing.xxxl) / 2

        return EdgeInsets(
            top: baseInsets.top,
            leading: horizontalInset,
            bottom: baseInsets.bottom,
            trailing: horizontalInset
        )
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
        segment.intervalRowHeadline(unit: distanceUnit)
    }

    private var repeatValue: String {
        segment.repeatCount.map(String.init) ?? L10n.unlimited
    }

    private var restValue: String {
        segment.restSeconds.map { Formatters.compactTimeString(from: Double($0)) } ?? L10n.restManual
    }

    private var activeRecoveryValue: String {
        segment.activeRecoverySeconds.map { Formatters.compactTimeString(from: Double($0)) } ?? L10n.off
    }

    private var lastRestValue: String {
        segment.lastRestSeconds.map { Formatters.compactTimeString(from: Double($0)) } ?? L10n.off
    }

    private var targetLabel: String {
        segment.targetTimeSeconds != nil ? L10n.time : L10n.pace
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
        segment.usesRecovery && segment.lastRestSeconds != nil
    }

    private var showsTarget: Bool {
        segment.targetPaceSecondsPerKm != nil || (!segment.usesOpenDistance && segment.targetTimeSeconds != nil)
    }

    private var metricItems: [MetricItem] {
        var items: [MetricItem] = []

        if segment.intervalRowShowsPrimaryMetricInDetails {
            items.append(
                MetricItem(
                    title: segment.intervalRowPrimaryLabel,
                    value: segment.intervalRowPrimaryValue(unit: distanceUnit)
                )
            )
        }

        if segment.usesActiveRecovery {
            items.append(
                MetricItem(
                    title: L10n.recovery,
                    value: activeRecoveryValue
                )
            )
        }

        if segment.usesRestRecovery {
            items.append(
                MetricItem(
                    title: L10n.rest,
                    value: restValue
                )
            )
        }

        if let count = segment.repeatCount {
            let repeatItem = MetricItem(title: L10n.repeats, value: String(count))
            if segment.usesOpenDistance {
                items.append(repeatItem)
            } else {
                items.insert(repeatItem, at: 0)
            }
        }

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

    private var metricLayoutSignature: String {
        metricItems
            .map { "\($0.title):\($0.value)" }
            .joined(separator: "|")
    }

    private var usesTitleOnlyLayout: Bool {
        metricItems.isEmpty
    }

    private var verticalPadding: EdgeInsets {
        if usesTitleOnlyLayout {
            return EdgeInsets(
                top: CompanionSessionPlanStyle.emptyStateVerticalPadding,
                leading: 0,
                bottom: CompanionSessionPlanStyle.emptyStateVerticalPadding,
                trailing: 0
            )
        }

        return EdgeInsets(
            top: Tokens.Spacing.xs,
            leading: 0,
            bottom: Tokens.Spacing.sm,
            trailing: 0
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.md) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.text.neutral)

                    Spacer(minLength: Tokens.Spacing.md)

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.subtle)
                }

                VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                    Grid(alignment: .leading, horizontalSpacing: Tokens.Spacing.xxxxl, verticalSpacing: Tokens.Spacing.md) {
                        ForEach(Array(metricRows.enumerated()), id: \.offset) { _, row in
                            GridRow(alignment: .top) {
                                ForEach(row) { item in
                                    CompanionMetricPill(title: item.title, value: item.value, textStyle: .regular)
                                }

                                ForEach(0..<max(0, 3 - row.count), id: \.self) { _ in
                                    Color.clear
                                        .gridCellUnsizedAxes([.horizontal, .vertical])
                                }
                            }
                        }
                        .animation(.snappy(duration: 0.28, extraBounce: 0.0), value: metricLayoutSignature)
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: usesTitleOnlyLayout ? CompanionSessionPlanStyle.titleOnlyRowMinHeight : 0,
            alignment: .topLeading
        )
        .padding(verticalPadding)
    }
}

private struct CompanionSegmentEditorView: View {
    private enum EditableField: String, Identifiable {
        case distance
        case repeats
        case activeRecovery
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
            case .activeRecovery:
                return .activeRecovery
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
            case .activeRecovery:
                return L10n.activeRecovery
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

        var systemImage: String {
            switch self {
            case .distance:
                return "ruler"
            case .repeats:
                return "repeat"
            case .activeRecovery:
                return "figure.run"
            case .rest:
                return "figure.cooldown"
            case .lastRest:
                return "flag.checkered"
            case .time:
                return "stopwatch"
            case .pace:
                return "speedometer"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var settings: SettingsStore

    @State private var segment: DistanceSegment
    @State private var distanceText: String
    @State private var segmentNameText: String
    @State private var hasCommitted = false
    @State private var isDistanceTypeHelpPresented = false
    @State private var isActiveRecoveryHelpPresented = false
    @State private var isLastRestHelpPresented = false
    @State private var isLastRestInfoPresented = false
    @State private var editableField: EditableField?
    @State private var bouncingField: EditableField?
    @State private var editableValueText = ""
    @State private var recoveryMemory: SegmentRecoveryEditorMemory
    let distanceUnit: DistanceUnit
    let onSave: (DistanceSegment) -> Void
    let onDelete: (DistanceSegment) -> Void
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
        CompanionPreferencesStyle.detailRowInsets
    }

    private var editorRowContentInsets: EdgeInsets {
        CompanionPreferencesStyle.detailRowContentInsets
    }

    private var canConfigureLastRest: Bool {
        segment.usesRecovery && SegmentEditSheetRules.canConfigureLastRest(
            repeatCount: segment.repeatCount ?? 0,
            restSeconds: segment.restSeconds ?? 0
        )
    }

    init(
        segment: DistanceSegment,
        distanceUnit: DistanceUnit,
        onSave: @escaping (DistanceSegment) -> Void,
        onDelete: @escaping (DistanceSegment) -> Void
    ) {
        _segment = State(initialValue: segment)
        _distanceText = State(initialValue: CompanionSegmentEditorView.distanceText(for: segment, unit: distanceUnit))
        _segmentNameText = State(initialValue: segment.trimmedName ?? "")
        _recoveryMemory = State(
            initialValue: SegmentRecoveryEditorMemory(
                restSeconds: segment.restSeconds ?? 0,
                lastRestSeconds: segment.lastRestSeconds ?? 0,
                activeRecoverySeconds: segment.activeRecoverySeconds ?? 0
            )
        )
        self.distanceUnit = distanceUnit
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: Tokens.Spacing.md) {
                    CompanionSettingsLeadingIcon(systemImage: "road.lanes")

                    HStack(spacing: Tokens.Spacing.xs) {
                        Text(L10n.intervalType)

                        Button {
                            isDistanceTypeHelpPresented = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: Tokens.FontSize.xl, weight: .semibold))
                                .foregroundStyle(theme.isDark ? theme.text.subtle : settings.primaryAccentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.helpIntervalTypeTitle)
                    }

                    Spacer(minLength: Tokens.Spacing.md)

                    Picker("", selection: $segment.distanceGoalMode) {
                        Text(L10n.distanceInterval).tag(DistanceGoalMode.distance)
                        Text(L10n.timeInterval).tag(DistanceGoalMode.time)
                    }
                    .labelsHidden()
                }
                .padding(.trailing, Tokens.Spacing.sm)
                .companionSettingsOptionRowChrome(
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
                    .companionSettingsOptionRowChrome(
                        rowInsets: editorRowInsets,
                        contentInsets: editorRowContentInsets
                    )
                    .scaleEffect(bouncingField == .distance ? 0.97 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)
                }

                if segment.usesOpenDistance {
                    timeTargetRow
                }

                Stepper(value: Binding(
                    get: { segment.repeatCount ?? 0 },
                    set: {
                        segment.repeatCount = $0 > 0 ? $0 : nil
                        segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
                            lastRestSeconds: segment.lastRestSeconds,
                            repeatCount: segment.repeatCount
                        )
                        syncRecoveryMemory()
                    }
                ), in: 0...99, step: 1) {
                    editableStepperContent(
                        title: L10n.repeats,
                        value: segment.repeatCount.map(String.init) ?? L10n.unlimited,
                        field: .repeats
                    )
                }
                .companionSettingsOptionRowChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )
                .scaleEffect(bouncingField == .repeats ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)

                Stepper(value: Binding(
                    get: { segment.activeRecoverySeconds ?? 0 },
                    set: {
                        let currentSeconds = segment.activeRecoverySeconds ?? 0
                        let updatedSeconds: Int

                        if $0 > currentSeconds {
                            updatedSeconds = SegmentEditorValueRules.incrementedRecoveryDurationSeconds(
                                currentDurationSeconds: currentSeconds
                            )
                        } else if $0 < currentSeconds {
                            updatedSeconds = SegmentEditorValueRules.decrementedRecoveryDurationSeconds(
                                currentDurationSeconds: currentSeconds
                            )
                        } else {
                            updatedSeconds = currentSeconds
                        }

                        updateActiveRecoverySeconds(updatedSeconds)
                    }
                ), in: 0...600, step: 15) {
                    editableStepperContent(
                        title: L10n.activeRecovery,
                        value: segment.activeRecoverySeconds.map { Formatters.timeString(from: Double($0)) } ?? L10n.off,
                        field: .activeRecovery
                    )
                }
                .companionSettingsOptionRowChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )
                .scaleEffect(bouncingField == .activeRecovery ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)

                Stepper(value: Binding(
                    get: { segment.restSeconds ?? 0 },
                    set: {
                        let currentSeconds = segment.restSeconds ?? 0
                        let updatedSeconds: Int

                        if $0 > currentSeconds {
                            updatedSeconds = SegmentEditorValueRules.incrementedRecoveryDurationSeconds(
                                currentDurationSeconds: currentSeconds
                            )
                        } else if $0 < currentSeconds {
                            updatedSeconds = SegmentEditorValueRules.decrementedRecoveryDurationSeconds(
                                currentDurationSeconds: currentSeconds
                            )
                        } else {
                            updatedSeconds = currentSeconds
                        }

                        updateRestSeconds(updatedSeconds)
                    }
                ), in: 0...600, step: 15) {
                    editableStepperContent(
                        title: L10n.rest,
                        value: segment.restSeconds.map { Formatters.timeString(from: Double($0)) } ?? L10n.manual,
                        field: .rest
                    )
                }
                .companionSettingsOptionRowChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )
                .scaleEffect(bouncingField == .rest ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)

                Stepper(value: Binding(
                    get: { segment.usesRecovery ? (segment.lastRestSeconds ?? 0) : 0 },
                    set: {
                        guard canConfigureLastRest else {
                            isLastRestInfoPresented = true
                            return
                        }

                        let currentSeconds = segment.usesRecovery ? (segment.lastRestSeconds ?? 0) : 0
                        let resolvedSeconds: Int

                        if $0 > currentSeconds {
                            resolvedSeconds = SegmentEditorValueRules.incrementedRecoveryDurationSeconds(
                                currentDurationSeconds: currentSeconds
                            )
                        } else if $0 < currentSeconds {
                            resolvedSeconds = SegmentEditorValueRules.decrementedRecoveryDurationSeconds(
                                currentDurationSeconds: currentSeconds
                            )
                        } else {
                            resolvedSeconds = currentSeconds
                        }

                        segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
                            lastRestSeconds: resolvedSeconds > 0 ? resolvedSeconds : nil,
                            repeatCount: segment.repeatCount
                        )
                        syncRecoveryMemory()
                    }
                ), in: 0...600, step: 15) {
                    editableStepperContent(
                        title: L10n.lastRest,
                        value: segment.lastRestSeconds.map { Formatters.timeString(from: Double($0)) } ?? L10n.off,
                        field: .lastRest
                    )
                }
                .companionSettingsOptionRowChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )
                .opacity(shouldAppearDisabled(field: .lastRest) ? 0.62 : 1)
                .scaleEffect(bouncingField == .lastRest ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)

                if !segment.usesOpenDistance {
                    timeTargetRow
                }

                if !segment.usesOpenDistance {
                    Stepper(value: Binding(
                        get: { Int(segment.targetPaceSecondsPerKm ?? 0) },
                        set: {
                            let currentPaceSeconds = Int(segment.targetPaceSecondsPerKm ?? 0)
                            let resolvedPaceSeconds: Int

                            if $0 > currentPaceSeconds {
                                resolvedPaceSeconds = SegmentEditorValueRules.incrementedTargetPaceSeconds(
                                    currentPaceSecondsPerKm: currentPaceSeconds
                                )
                            } else if $0 < currentPaceSeconds {
                                resolvedPaceSeconds = SegmentEditorValueRules.decrementedTargetPaceSeconds(
                                    currentPaceSecondsPerKm: currentPaceSeconds
                                )
                            } else {
                                resolvedPaceSeconds = currentPaceSeconds
                            }

                            let updatedTargets = SegmentEditorValueRules.updatedTargetsAfterSettingPace(
                                secondsPerKm: resolvedPaceSeconds,
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
                    .companionSettingsOptionRowChrome(
                        rowInsets: editorRowInsets,
                        contentInsets: editorRowContentInsets
                    )
                    .scaleEffect(bouncingField == .pace ? 0.97 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)
                }

                HStack(spacing: Tokens.Spacing.md) {
                    CompanionSettingsLeadingIcon(systemImage: "character.textbox")

                    Text(L10n.segmentName)

                    Spacer(minLength: Tokens.Spacing.md)

                    HStack(spacing: Tokens.Spacing.xs) {
                        TextField(
                            "",
                            text: $segmentNameText,
                            prompt: Text(L10n.optionalSegmentNamePlaceholder)
                                .foregroundStyle(theme.text.subtle)
                        )
                        .font(.body.weight(.bold))
                        .textInputAutocapitalization(.words)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(theme.text.neutral)
                    }
                    .padding(.trailing, Tokens.Spacing.xs)
                }
                .companionSettingsOptionRowChrome(
                    rowInsets: editorRowInsets,
                    contentInsets: editorRowContentInsets
                )
            }
        }
        .navigationTitle(L10n.editInterval)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        deleteSegment()
                    } label: {
                        Label(L10n.deleteInterval, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .themedCompanionSettingsList()
        .onAppear(perform: normalizeEditingState)
        .onChange(of: segment.distanceGoalMode) { _, _ in
            segment.targetPaceSecondsPerKm = SegmentEditorValueRules.normalizedTargetPace(
                for: segment.distanceGoalMode,
                targetPaceSecondsPerKm: segment.targetPaceSecondsPerKm
            )
            segment.targetTimeSeconds = SegmentEditorValueRules.normalizedTargetTime(
                for: segment.distanceGoalMode,
                targetTimeSeconds: segment.targetTimeSeconds
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
        .sheet(isPresented: $isDistanceTypeHelpPresented) {
            NavigationStack {
                List {
                    Section {
                        CompanionHelpCard(topic: .distanceType)
                            .listRowInsets(CompanionPreferencesStyle.detailRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .navigationTitle(L10n.intervalType)
                .navigationBarTitleDisplayMode(.inline)
                .themedCompanionSettingsList()
            }
        }
        .sheet(isPresented: $isActiveRecoveryHelpPresented) {
            NavigationStack {
                List {
                    Section {
                        CompanionHelpCard(topic: .activeRecovery)
                            .listRowInsets(CompanionPreferencesStyle.detailRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .navigationTitle(L10n.helpActiveRecoveryTitle)
                .navigationBarTitleDisplayMode(.inline)
                .themedCompanionSettingsList()
            }
        }
        .sheet(isPresented: $isLastRestHelpPresented) {
            NavigationStack {
                List {
                    Section {
                        CompanionHelpCard(topic: .lastRest)
                            .listRowInsets(CompanionPreferencesStyle.detailRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .navigationTitle(L10n.helpLastRestTitle)
                .navigationBarTitleDisplayMode(.inline)
                .themedCompanionSettingsList()
            }
        }
    }

    @ViewBuilder
    private func editableStepperContent(title: String, value: String, field: EditableField) -> some View {
        HStack(spacing: Tokens.Spacing.md) {
            CompanionSettingsLeadingIcon(systemImage: field.systemImage)

            HStack(alignment: .bottom, spacing: Tokens.Spacing.xs) {
                Text(title)

                if field == .activeRecovery {
                    Button {
                        isActiveRecoveryHelpPresented = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: Tokens.FontSize.xl, weight: .semibold))
                            .foregroundStyle(theme.isDark ? theme.text.subtle : settings.primaryAccentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.helpActiveRecoveryTitle)
                }

                if field == .lastRest {
                    Button {
                        isLastRestHelpPresented = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: Tokens.FontSize.xl, weight: .semibold))
                            .foregroundStyle(theme.isDark ? theme.text.subtle : settings.primaryAccentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.helpLastRestTitle)
                }
            }

            Spacer(minLength: Tokens.Spacing.md)

            Text(value)
                .font(.body.weight(.bold))
                .foregroundStyle(theme.text.neutral)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch tapAction(for: field) {
            case .openEditor:
                break
            case .showUnavailableInfo:
                isLastRestInfoPresented = true
                return
            case .ignore:
                return
            }

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

    private func tapAction(for field: EditableField) -> CompanionSegmentEditorTapAction {
        CompanionSegmentEditorRules.tapAction(
            for: field.sharedField,
            recoveryType: segment.recoveryType,
            repeatCount: segment.repeatCount,
            restSeconds: segment.restSeconds,
            lastRestSeconds: segment.lastRestSeconds
        )
    }

    private func shouldAppearDisabled(field: EditableField) -> Bool {
        CompanionSegmentEditorRules.shouldAppearDisabled(
            field: field.sharedField,
            recoveryType: segment.recoveryType,
            repeatCount: segment.repeatCount,
            restSeconds: segment.restSeconds
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

    private var timeTargetRow: some View {
        let minimumTargetTime = SegmentEditorValueRules.minimumTargetTimeSeconds(for: segment.distanceGoalMode)

        return Stepper(value: Binding(
            get: { max(Int(segment.targetTimeSeconds ?? 0), minimumTargetTime) },
            set: {
                let updatedTargets = SegmentEditorValueRules.updatedTargetsAfterSettingTime(
                    seconds: $0,
                    currentPaceSecondsPerKm: segment.targetPaceSecondsPerKm
                )
                segment.targetTimeSeconds = SegmentEditorValueRules.normalizedTargetTime(
                    for: segment.distanceGoalMode,
                    targetTimeSeconds: updatedTargets.targetTimeSeconds
                )
                segment.targetPaceSecondsPerKm = updatedTargets.targetPaceSecondsPerKm
            }
        ), in: minimumTargetTime...7200, step: 5) {
            editableStepperContent(
                title: L10n.time,
                value: segment.targetTimeSeconds.map { Formatters.timeString(from: $0) }
                    ?? (segment.distanceGoalMode == .time
                        ? Formatters.timeString(from: Double(minimumTargetTime))
                        : L10n.off),
                field: .time
            )
        }
        .companionSettingsOptionRowChrome(
            rowInsets: editorRowInsets,
            contentInsets: editorRowContentInsets
        )
        .scaleEffect(bouncingField == .time ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.62), value: bouncingField)
    }

    private func commitIfNeeded() {
        guard !hasCommitted else { return }
        hasCommitted = true
        segment.name = SegmentEditorValueRules.normalizedName(segmentNameText)

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
        segment.normalizeRecoveryConfiguration()
        if !segment.usesRecovery {
            segment.lastRestSeconds = nil
        }
        segment.targetPaceSecondsPerKm = SegmentEditorValueRules.normalizedTargetPace(
            for: segment.distanceGoalMode,
            targetPaceSecondsPerKm: segment.targetPaceSecondsPerKm
        )
        segment.targetTimeSeconds = SegmentEditorValueRules.normalizedTargetTime(
            for: segment.distanceGoalMode,
            targetTimeSeconds: segment.targetTimeSeconds
        )

        onSave(segment)
    }

    private func deleteSegment() {
        guard !hasCommitted else { return }
        hasCommitted = true
        onDelete(segment)
        dismiss()
    }

    private func normalizeEditingState() {
        segment.name = SegmentEditorValueRules.normalizedName(segmentNameText)
        segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
            lastRestSeconds: segment.lastRestSeconds,
            repeatCount: segment.repeatCount
        )
        segment.normalizeRecoveryConfiguration()
        if !segment.usesRecovery {
            segment.lastRestSeconds = nil
        }
        segment.targetPaceSecondsPerKm = SegmentEditorValueRules.normalizedTargetPace(
            for: segment.distanceGoalMode,
            targetPaceSecondsPerKm: segment.targetPaceSecondsPerKm
        )
        segment.targetTimeSeconds = SegmentEditorValueRules.normalizedTargetTime(
            for: segment.distanceGoalMode,
            targetTimeSeconds: segment.targetTimeSeconds
        )
        syncRecoveryMemory()
    }

    private func beginEditing(_ field: EditableField) {
        switch field {
        case .distance:
            editableValueText = distanceText
        case .repeats:
            editableValueText = segment.repeatCount.map(String.init) ?? ""
        case .activeRecovery:
            editableValueText = segment.activeRecoverySeconds.map { Formatters.timeString(from: Double($0)) } ?? ""
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
            syncRecoveryMemory()
        case .activeRecovery:
            let activeRecoverySeconds = min(max(SegmentEditInputParser.parseDurationSeconds(from: editableValueText), 0), 600)
            updateActiveRecoverySeconds(activeRecoverySeconds)
        case .rest:
            let rest = min(max(SegmentEditInputParser.parseDurationSeconds(from: editableValueText), 0), 600)
            updateRestSeconds(rest)
        case .lastRest:
            guard canConfigureLastRest else {
                isLastRestInfoPresented = true
                return
            }
            let lastRest = min(max(SegmentEditInputParser.parseDurationSeconds(from: editableValueText), 0), 600)
            updateLastRestSeconds(lastRest)
        case .time:
            let time = min(max(SegmentEditInputParser.parseDurationSeconds(from: editableValueText), 0), 7200)
            let updatedTargets = SegmentEditorValueRules.updatedTargetsAfterSettingTime(
                seconds: time,
                currentPaceSecondsPerKm: segment.targetPaceSecondsPerKm
            )
            segment.targetTimeSeconds = SegmentEditorValueRules.normalizedTargetTime(
                for: segment.distanceGoalMode,
                targetTimeSeconds: updatedTargets.targetTimeSeconds
            )
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

    private func updateActiveRecoverySeconds(_ seconds: Int) {
        let normalizedSeconds = max(seconds, 0)
        segment.activeRecoverySeconds = normalizedSeconds > 0 ? normalizedSeconds : nil
        segment.normalizeRecoveryConfiguration()
        syncRecoveryMemory()
    }

    private func updateRestSeconds(_ seconds: Int) {
        let normalizedSeconds = max(seconds, 0)
        segment.restSeconds = normalizedSeconds > 0 ? normalizedSeconds : nil
        segment.normalizeRecoveryConfiguration()
        syncRecoveryMemory()
    }

    private func updateLastRestSeconds(_ seconds: Int) {
        let normalizedSeconds = max(seconds, 0)
        segment.lastRestSeconds = SegmentEditorValueRules.normalizedLastRestSeconds(
            lastRestSeconds: normalizedSeconds > 0 ? normalizedSeconds : nil,
            repeatCount: segment.repeatCount
        )
        syncRecoveryMemory()
    }

    private func syncRecoveryMemory() {
        recoveryMemory = SegmentRecoveryEditorMemory(
            restSeconds: segment.restSeconds ?? 0,
            lastRestSeconds: segment.lastRestSeconds ?? 0,
            activeRecoverySeconds: segment.activeRecoverySeconds ?? 0
        )
    }

    private func keypadRows(for field: EditableField) -> [[String]] {
        switch field {
        case .distance:
            return distanceKeypadRows
        case .repeats:
            return repeatKeypadRows
        case .activeRecovery, .rest, .lastRest, .time, .pace:
            return durationKeypadRows
        }
    }

    private func handleKeyTap(_ key: String, for field: EditableField) {
        switch field {
        case .distance:
            SegmentEditInputParser.applyDistanceKey(key, to: &editableValueText)
        case .repeats:
            SegmentEditInputParser.applyRepeatKey(key, to: &editableValueText)
        case .activeRecovery, .rest, .lastRest, .time, .pace:
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
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.md) {
                Text(Formatters.historySessionDateTimeString(from: state.startedAt))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.text.neutral)
            }

            Text(statusLabel)
                .font(.system(size: Tokens.FontSize.md, weight: .regular, design: .rounded))
                .foregroundStyle(settings.primaryAccentColor)

            HStack(alignment: .top, spacing: Tokens.Spacing.xxxxl) {
                CompanionMetricPill(title: L10n.laps, value: "\(state.completedLapCount)", textStyle: .regular)
                CompanionMetricPill(title: L10n.duration, value: Formatters.timeString(from: state.elapsedSeconds), textStyle: .regular)
                CompanionMetricPill(
                    title: primaryDistanceLabel,
                    value: Formatters.distanceString(meters: primaryDistanceMeters, unit: settings.distanceUnit),
                    textStyle: .regular
                )
            }
            .padding(.top, Tokens.Spacing.xl)

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
        .padding(.top, Tokens.Spacing.xs)
        .padding(.bottom, Tokens.Spacing.sm)
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
    private struct MetricItem: Identifiable {
        let id = UUID()
        let title: String
        let value: String
    }

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

    private var metricItems: [MetricItem] {
        [
            MetricItem(title: L10n.laps, value: "\(session.activeLapCount)"),
            MetricItem(title: L10n.pace, value: summaryPace),
            MetricItem(title: L10n.duration, value: Formatters.timeString(from: session.activeDurationSeconds)),
            MetricItem(
                title: L10n.distance,
                value: summaryDistance > 0
                    ? Formatters.distanceString(meters: summaryDistance, unit: settings.distanceUnit)
                    : L10n.dash
            )
        ]
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
                    Text(Formatters.historySessionDateTimeString(from: session.startedAt))
                        .font(.title3.weight(.semibold))
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
                                CompanionMetricPill(title: item.title, value: item.value, textStyle: .regular)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Tokens.Spacing.xs)
    }
}

private struct CompanionSessionStatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private struct CompanionSessionSummarySection {
    let title: String
    let items: [CompanionSessionStatItem]
}

private enum CompanionSessionSummaryRouting {
    static func sections(for session: Session, distanceUnit: DistanceUnit) -> [CompanionSessionSummarySection] {
        let primaryItems = SessionHistorySummaryRouting.primaryItems(for: session, distanceUnit: distanceUnit)
            .map { CompanionSessionStatItem(label: $0.label, value: $0.value) }
        let activeRecoveryItems = SessionHistorySummaryRouting.activeRecoveryItems(for: session, distanceUnit: distanceUnit)
            .map { CompanionSessionStatItem(label: $0.label, value: $0.value) }

        var sections = [
            CompanionSessionSummarySection(
                title: L10n.summary,
                items: primaryItems
            )
        ]

        if !activeRecoveryItems.isEmpty {
            sections.append(
                CompanionSessionSummarySection(
                    title: L10n.activeRecovery,
                    items: activeRecoveryItems
                )
            )
        }

        return sections
    }
}

private struct CompanionSessionDetailView: View {
    let session: Session
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var persistence: PersistenceManager
    @EnvironmentObject private var transferCoordinator: CompanionTransferCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var isReuseConfirmationPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var matchingSourceSession: Session?

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.startedAt < $1.startedAt }
    }

    private var headerTitle: HistoryDateRangeParts {
        Formatters.historySessionDateRangeParts(start: session.startedAt, end: session.endedAt)
    }

    private var targetSegmentsByLapID: [UUID: DistanceSegment] {
        SessionLapTargetResolver.targetSegments(
            for: sortedLaps,
            workoutPlan: session.snapshotWorkoutPlan,
            trackingMode: session.mode
        )
    }

    private var summarySections: [CompanionSessionSummarySection] {
        CompanionSessionSummaryRouting.sections(for: session, distanceUnit: settings.distanceUnit)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                ForEach(Array(summarySections.enumerated()), id: \.offset) { index, section in
                    HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.sm) {
                        Text(section.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(theme.text.neutral)
                            .padding(.leading, Tokens.ContentInsets.companionCard.leading + Tokens.Spacing.sm + Tokens.Spacing.xs)

                        Spacer(minLength: 0)

                        if index == 0 {
                            Text(headerTitle.timeText)
                                .font(.subheadline)
                                .foregroundStyle(theme.text.subtle)
                                .padding(.trailing, Tokens.ContentInsets.companionCard.leading + Tokens.Spacing.sm + Tokens.Spacing.xs)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, index == 0 ? 0 : Tokens.Spacing.md)

                    CompanionSessionStatsView(items: section.items)
                }

                Text(L10n.laps)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.text.neutral)
                    .padding(.leading, Tokens.ContentInsets.companionCard.leading + Tokens.Spacing.sm + Tokens.Spacing.xs)
                    .padding(.trailing, Tokens.Spacing.xs)
                    .padding(.top, Tokens.Spacing.md)

                ForEach(sortedLaps, id: \.id) { lap in
                    CompanionSessionLapRow(
                        lap: lap,
                        targetSegment: targetSegmentsByLapID[lap.id],
                        trackingMode: session.mode,
                        distanceUnit: settings.distanceUnit
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            CompanionListBackgroundView()
        }
        .navigationTitle(headerTitle.dayText)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isReuseConfirmationPresented = true
                    } label: {
                        Label(L10n.reusePlan, systemImage: "arrow.clockwise")
                    }

                    Button {
                        transferCoordinator.shareSession(session)
                    } label: {
                        Label(L10n.shareSession, systemImage: "square.and.arrow.up")
                    }

                    Button {
                        matchingSourceSession = session
                    } label: {
                        Label(L10n.showMatchingSessions, systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Label(L10n.deleteSession, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert(L10n.useActivityConfirmationTitle, isPresented: $isReuseConfirmationPresented) {
            Button(L10n.yes) {
                settings.apply(workoutPlan: session.snapshotWorkoutPlan)
                dismiss()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.useActivityConfirmationMessage)
        }
        .alert(L10n.deleteSession, isPresented: $isDeleteConfirmationPresented) {
            Button(L10n.delete, role: .destructive) {
                persistence.deleteSession(session)
                dismiss()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteSessionConfirmMessage)
        }
        .navigationDestination(item: $matchingSourceSession) { sourceSession in
            CompanionMatchingSessionsView(sourceSession: sourceSession)
        }
    }
}

private struct CompanionMatchingSessionsView: View {
    let sourceSession: Session

    @EnvironmentObject private var persistence: PersistenceManager
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    @State private var matchingSessions: [Session] = []

    private var sectionTitle: String {
        settings.title(for: sourceSession.snapshotWorkoutPlan)
    }

    var body: some View {
        List {
            Section {
                if matchingSessions.isEmpty {
                    CompanionEmptyStateCard(title: L10n.noOtherMatchingSessionsYet)
                        .listRowCardChrome(
                            rowInsets: CompanionSessionPlanStyle.rowInsets,
                            contentInsets: CompanionSessionPlanStyle.cellContentInsets
                        )
                } else {
                    ForEach(matchingSessions, id: \.id) { session in
                        NavigationLink {
                            CompanionSessionDetailView(session: session)
                        } label: {
                            HStack(spacing: 0) {
                                CompanionSessionRow(session: session)
                                    .padding(CompanionSessionPlanStyle.cellContentInsets)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .listRowCardChrome(
                            rowInsets: CompanionSessionPlanStyle.rowInsets,
                            contentInsets: EdgeInsets()
                        )
                    }
                }
            } header: {
                CompanionHomeSectionHeader(title: sectionTitle)
                    .padding(.leading, CompanionSessionPlanStyle.sectionHeaderLeadingInset)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(L10n.matchingSessions)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .themedCompanionList()
        .onAppear(perform: loadMatchingSessions)
    }

    private func loadMatchingSessions() {
        matchingSessions = persistence.fetchMatchingSessions(for: sourceSession)
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
    let targetSegment: DistanceSegment?
    let trackingMode: TrackingMode
    let distanceUnit: DistanceUnit
    @Environment(\.appTheme) private var theme

    private let badgeOpticalLift: CGFloat = 2

    private let columns = [
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading),
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading)
    ]

    private var isRestLap: Bool {
        lap.lapType.isRecovery
    }

    private var isActiveRecoveryLap: Bool {
        lap.lapType == .activeRecovery
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
        presentation.title
    }

    private var presentation: HistoryLapPresentation {
        HistoryLapPresentation.make(
            lap: lap,
            targetSegment: targetSegment,
            trackingMode: trackingMode,
            distanceUnit: distanceUnit
        )
    }

    private var activeHeaderTimeFont: Font {
        if isActiveRecoveryLap {
            return .body.weight(.medium)
        }

        return .system(size: CompanionSessionLapRowLayout.titleFontSize, weight: .medium)
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
        presentation.statItems.map { CompanionSessionStatItem(label: $0.label, value: $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack(alignment: isRestLap ? .center : .firstTextBaseline, spacing: Tokens.Spacing.sm) {
                if isRestLap {
                    Text(presentation.title)
                        .font(.system(size: CompanionSessionLapRowLayout.titleFontSize, weight: .semibold))
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
                        .font(activeHeaderTimeFont)
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

enum CompanionSessionLapRowLayout {
    static let titleFontSize: CGFloat = Tokens.FontSize.xxl + Tokens.Spacing.xxxs
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
            .listStyle(.plain)
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
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background {
                CompanionListBackgroundView()
                    .ignoresSafeArea()
            }
    }

    func listRowCardChrome(
        rowInsets: EdgeInsets = Tokens.ListRowInsets.companionCard,
        contentInsets: EdgeInsets = Tokens.ContentInsets.companionCard,
        fillColor: Color? = nil
    ) -> some View {
        modifier(CompanionListRowChrome(rowInsets: rowInsets, contentInsets: contentInsets, fillColor: fillColor))
    }

    func companionSettingsOptionRowChrome(
        rowInsets: EdgeInsets = EdgeInsets(
            top: 0,
            leading: Tokens.ListRowInsets.companionCard.leading,
            bottom: 0,
            trailing: Tokens.ListRowInsets.companionCard.trailing
        ),
        contentInsets: EdgeInsets
    ) -> some View {
        modifier(CompanionSettingsOptionRowChrome(rowInsets: rowInsets, contentInsets: contentInsets))
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

private struct CompanionSettingsOptionRowChrome: ViewModifier {
    let rowInsets: EdgeInsets
    let contentInsets: EdgeInsets
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(contentInsets)
            .listRowInsets(rowInsets)
            .listRowBackground(theme.background.history)
    }
}

struct CompanionListBackgroundView: View {
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
            return currentRecoveryType == .activeRecovery ? L10n.activeRecovery : L10n.runStateRest
        case .paused:
            return L10n.runStatePaused
        case .ending:
            return L10n.runStateEnding
        case .ended:
            return L10n.runStateEnded
        }
    }
}

private enum SessionLapTargetResolver {
    static func targetSegments(
        for laps: [Lap],
        workoutPlan: WorkoutPlanSnapshot,
        trackingMode: TrackingMode
    ) -> [UUID: DistanceSegment] {
        guard trackingMode.usesManualIntervals, !workoutPlan.distanceSegments.isEmpty else {
            return [:]
        }

        var targetsByLapID: [UUID: DistanceSegment] = [:]
        var segmentIndex = 0
        var repeatsDone = 0

        for lap in laps where lap.lapType == .active {
            let safeIndex = min(segmentIndex, workoutPlan.distanceSegments.count - 1)
            let segment = workoutPlan.distanceSegments[safeIndex]
            targetsByLapID[lap.id] = segment

            repeatsDone += 1
            if let repeatCount = segment.repeatCount,
               repeatsDone >= repeatCount,
               segmentIndex + 1 < workoutPlan.distanceSegments.count {
                segmentIndex += 1
                repeatsDone = 0
            }
        }

        return targetsByLapID
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
