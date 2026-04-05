import SwiftUI
import WatchKit

struct ActiveSessionView: View {
    @EnvironmentObject var workoutController: WorkoutSessionController
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var syncManager: WatchConnectivitySyncManager

    var onSessionEnded: () -> Void
    @State private var isTimerBounceActive = false
    @State private var isTimerGlowActive = false
    @State private var displayedTimerStatusBadgeText: String?
    @State private var isTimerStatusBadgeVisible = false
    @State private var isLapHistoryDragging = false
    @State private var lastAnimatedLapCount = 0
    @State private var lapEditorState: LapEditorState?
    @State private var bounceTask: Task<Void, Never>?
    @State private var glowTask: Task<Void, Never>?
    @State private var timerStatusBadgeHideTask: Task<Void, Never>?
    @State private var timerStatusBadgeShowTask: Task<Void, Never>?
    @State private var restTransitionTask: Task<Void, Never>?
    @State private var isShowingSessionComplete = false
    @State private var isEndingSession = false
    @State private var hasDismissedCompletedSession = false
    @State private var completedSessionDismissTask: Task<Void, Never>?
    @State private var selectedPage: Int = 1
    @State private var isShowingEndConfirmation = false
    @State private var pendingLapAnimationCount: Int?

    private let defaultLapDistanceText = "400"

    private var primaryColor: Color {
        settings.primaryAccentColor
    }

    private var isResting: Bool {
        workoutController.runState == .rest
    }

    private var isActiveRecovery: Bool {
        workoutController.runState == .rest && workoutController.currentRecoveryType == .activeRecovery
    }

    private var isRestingAfterRecovery: Bool {
        workoutController.runState == .rest && workoutController.currentRecoveryType != .activeRecovery
    }

    private var isWorkoutPaused: Bool {
        workoutController.runState == .paused
    }

    private var restButtonShowsEndRest: Bool {
        if workoutController.runState == .paused {
            return workoutController.willResumeIntoRest
        }
        return isRestingAfterRecovery
    }

    private var restButtonLabel: String {
        if workoutController.runState == .paused && workoutController.willResumeIntoActiveRecovery {
            return L10n.endActiveRecovery
        }

        if restButtonShowsEndRest {
            return L10n.endRest
        }

        return settings.restMode == .autoDetect ? L10n.restModeAuto : L10n.markAsRest
    }

    private var currentLapNumber: Int {
        workoutController.completedLaps.filter { $0.lapType == .active }.count + 1
    }

    private var lapCounterTotal: Int? {
        guard let total = workoutController.totalPlannedIntervals, total > 0 else { return nil }
        return total
    }

    private var showsSessionCompletionIndicator: Bool {
        ActiveSessionHeaderRouting.showsSessionCompletionIndicator(
            remainingPlannedIntervals: workoutController.remainingPlannedIntervals
        )
    }

    private var showsLapCounterBadge: Bool {
        switch workoutController.runState {
        case .active, .rest, .paused, .ending:
            return true
        case .idle, .ready, .ended:
            return false
        }
    }

    private func timerTopLabel(_ detail: String? = nil, includeLap: Bool = true) -> String {
        var components: [String] = []
        if includeLap && !showsLapCounterBadge {
            components.append(L10n.lapIndex(currentLapNumber))
        }

        if let detail, !detail.isEmpty {
            components.append(detail)
        }

        return components.joined(separator: " · ")
    }

    private var timerTopLabel: String {
        if workoutController.trackingMode.usesManualIntervals {
            let distanceStr = workoutController.currentTargetDistanceMeters.map {
                Formatters.distanceString(meters: $0, unit: settings.distanceUnit)
            }
            let timeStr = workoutController.currentTargetTimeSeconds.map {
                Formatters.compactTimeString(from: $0)
            }

            let intervalDetail: String?
            if let distanceStr, let timeStr {
                intervalDetail = L10n.targetDisplay(distanceStr, timeStr)
            } else if let distanceStr {
                intervalDetail = distanceStr
            } else if let timeStr {
                intervalDetail = timeStr
            } else {
                intervalDetail = nil
            }

            if let segmentName = workoutController.currentSegmentName,
               let intervalDetail,
               !intervalDetail.isEmpty {
                return timerTopLabel(L10n.segmentSummary(segmentName, intervalDetail))
            }

            if let segmentName = workoutController.currentSegmentName {
                return timerTopLabel(segmentName)
            }

            return timerTopLabel(intervalDetail)
        }
        return timerTopLabel()
    }

    private var timerStatusBadgeText: String? {
        ActiveSessionTimerBadgeContent.statusText(
            runState: workoutController.runState,
            willResumeIntoRest: workoutController.willResumeIntoRest,
            willResumeIntoActiveRecovery: workoutController.willResumeIntoActiveRecovery,
            currentRecoveryType: workoutController.currentRecoveryType,
            restDurationSeconds: workoutController.restDurationSeconds
        )
    }

    @Environment(\.appTheme) private var theme

    private var timerBorderOverlay: some View {
        Capsule()
            .strokeBorder(
                restButtonShowsEndRest
                    ? (theme.isDark ? theme.stroke.emphasisAction(primaryColor) : Color.white)
                    : theme.stroke.emphasisAction(primaryColor),
                style: StrokeStyle(
                    lineWidth: Tokens.LineWidth.thick,
                    lineCap: restButtonShowsEndRest ? .round : .butt,
                    lineJoin: restButtonShowsEndRest ? .round : .miter,
                    dash: restButtonShowsEndRest ? [0, 6] : []
                )
            )
    }

    private var timerBounceAnimation: Animation {
        isTimerBounceActive ? .easeOut(duration: 0.1) : .easeOut(duration: 0.6)
    }

    private var timerGlowAnimation: Animation {
        isTimerGlowActive ? .easeOut(duration: 0.08) : .easeOut(duration: 0.9)
    }

    private var lapGlowOverlay: some View {
        Capsule()
            .stroke(Color.white.opacity(isTimerGlowActive ? 0.6 : 0), lineWidth: Tokens.LineWidth.thick)
            .blur(radius: isTimerGlowActive ? 3 : 0)
            .animation(timerGlowAnimation, value: isTimerGlowActive)
    }

    private var displayedLapCounter: Int {
        currentLapNumber
    }

    private var lapCounterPrimaryOpacity: Double {
        restButtonShowsEndRest ? 0.8 : 1
    }

    private var lapCounterPrimaryColor: Color {
        restButtonShowsEndRest ? primaryColor : theme.text.bold
    }

    @ViewBuilder
    private var timerTopOverlay: some View {
        if showsLapCounterBadge {
            let labelFont = Font.system(size: Tokens.FontSize.base, weight: .regular, design: .rounded)

            VStack(spacing: Tokens.Spacing.xxs) {
                HStack(spacing: 5) {
                    if let total = lapCounterTotal {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(displayedLapCounter)")
                                .font(.system(size: Tokens.FontSize.xxl, weight: .bold, design: .rounded))
                                .foregroundStyle(lapCounterPrimaryColor)
                                .opacity(lapCounterPrimaryOpacity)
                            Text("/\(total)")
                                .font(.system(size: Tokens.FontSize.xs, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.text.bold)
                        }
                        .padding(.horizontal, Tokens.Spacing.xs)
                        .padding(.vertical, 0)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                                .fill(theme.background.bold)
                        )
                    } else {
                        Text("\(displayedLapCounter)")
                            .font(.system(size: Tokens.FontSize.xxl, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(lapCounterPrimaryColor)
                            .opacity(lapCounterPrimaryOpacity)
                            .padding(.horizontal, Tokens.Spacing.xs)
                            .padding(.vertical, 0)
                            .background(
                                RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                                    .fill(theme.background.bold)
                            )
                    }

                    if !timerTopLabel.isEmpty {
                        Text(timerTopLabel)
                            .font(labelFont)
                            .foregroundStyle(theme.text.neutral)
                    }

                    if showsSessionCompletionIndicator {
                        Image(systemName: "checkmark")
                            .font(.system(size: Tokens.FontSize.sm, weight: .bold))
                            .foregroundStyle(theme.text.neutral)
                    }
                }
            }
            .overlay(alignment: .top) {
                Text(displayedTimerStatusBadgeText ?? "")
                    .font(StatusBadgeStyle.font)
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, StatusBadgeStyle.horizontalPadding)
                    .padding(.vertical, StatusBadgeStyle.verticalPadding)
                    .background(StatusBadgeStyle.background(theme))
                    .opacity(isTimerStatusBadgeVisible ? 1 : 0)
                    .offset(y: -Tokens.Spacing.badgeLift)
            }
        } else {
            Text(timerTopLabel)
                .font(.system(size: Tokens.FontSize.base, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.text.subtle)
                .opacity(timerTopLabel.isEmpty ? 0 : 1)
        }
    }

    @ViewBuilder
    private var sessionTimerView: some View {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width
        let t = max(0, min(1, (screenWidth - 162) / (205 - 162)))
        let timerFontSize = round(60 + t * 40)
        ZStack(alignment: .top) {
            Button {
                handleLapTap()
            } label: {
                Text(Formatters.precisionTimeString(from: workoutController.lapElapsedSeconds))
                    .font(.system(size: timerFontSize, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .foregroundStyle(theme.text.emphasis)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Tokens.Spacing.md)
                    .padding(.vertical, Tokens.Spacing.sm)
                    .frame(maxHeight: 120)
                    .background(Capsule().fill(theme.background.emphasisAction(primaryColor)))
                    .overlay(timerBorderOverlay)
                    .overlay(lapGlowOverlay)
                    .scaleEffect(isTimerBounceActive ? 1.11 : 1)
                    .animation(timerBounceAnimation, value: isTimerBounceActive)
                    .brightness(isTimerGlowActive ? 0.3 : 0)
                    .shadow(color: Color.white.opacity(isTimerGlowActive ? 0.5 : 0), radius: 18)
                    .shadow(color: primaryColor.opacity(isTimerGlowActive ? 0.72 : 0), radius: 24)
                    .animation(timerGlowAnimation, value: isTimerGlowActive)
                    .padding(.horizontal, Tokens.Spacing.xs)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            timerTopOverlay
                .offset(y: -31)
        }
    }

    private let topHeaderHeight: CGFloat = 66
    private let contentVerticalOffset: CGFloat = -4
    private let lapHistoryContainerTrailingPadding: CGFloat = 12
    private let timerCardsSpacing: CGFloat = 6
    private let timerStatusBadgeAnimationDuration = 0.18
    private let timerStatusBadgeAppearanceDelay = 0.5
    private var timerStatusBadgeAnimation: Animation {
        .easeInOut(duration: timerStatusBadgeAnimationDuration)
    }

    @ViewBuilder
    private var heartRateOverlay: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: "heart.fill")
                .font(.system(size: Tokens.FontSize.xs, weight: .semibold))
                .foregroundStyle(theme.text.emphasis)

            Text(Formatters.heartRateString(bpm: workoutController.currentHeartRate))
                .font(.system(size: Tokens.FontSize.sm, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text.emphasis)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var pageIndicatorView: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            ForEach(0..<2, id: \.self) { page in
                Circle()
                    .fill(page == selectedPage ? theme.background.bold : theme.background.neutralAction)
                    .frame(
                        width: page == selectedPage ? Tokens.Spacing.sm : Tokens.Spacing.xs,
                        height: page == selectedPage ? Tokens.Spacing.sm : Tokens.Spacing.xs
                    )
            }
        }
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xs)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var controlsPage: some View {
        ScrollView {
            VStack(spacing: Tokens.Spacing.xxl) {
                Button {
                    handleRestButtonTap()
                } label: {
                    VStack(spacing: Tokens.Spacing.sm) {
                        WorkoutControlIcon(
                            systemName: restButtonShowsEndRest ? "arrow.counterclockwise" : "figure.cooldown",
                            baseColor: primaryColor,
                            size: 78,
                            isDashed: restButtonShowsEndRest,
                            iconFontSizeOverride: 34
                        )
                        Text(restButtonLabel)
                            .font(.system(size: Tokens.FontSize.sm, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.text.subtle)
                    }
                }
                .buttonStyle(RestPressStyle())

                HStack {
                    Button {
                        isShowingEndConfirmation = true
                    } label: {
                        VStack(spacing: Tokens.Spacing.sm) {
                            WorkoutControlIcon(
                                systemName: "xmark",
                                baseColor: primaryColor,
                                isSecondary: true
                            )
                            Text(L10n.endSession)
                                .font(.system(size: Tokens.FontSize.sm, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.text.subtle)
                        }
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(L10n.areYouSure, isPresented: $isShowingEndConfirmation, titleVisibility: .visible) {
                        Button(L10n.endWorkout, role: .destructive) {
                            finishSession()
                        }
                        Button(L10n.cancel, role: .cancel) {}
                    }

                    Spacer(minLength: Tokens.Spacing.xl)

                    Button {
                        switch ActiveSessionControlRouting.pauseResumeAction(for: workoutController.runState) {
                        case .resume:
                            workoutController.resumeSession()
                        case .pause:
                            workoutController.pauseSession()
                        }
                        animateControlPageReturn()
                    } label: {
                        VStack(spacing: Tokens.Spacing.sm) {
                            WorkoutControlIcon(
                                systemName: isWorkoutPaused ? "play.fill" : "pause.fill",
                                baseColor: primaryColor,
                                isSecondary: true
                            )
                            Text(isWorkoutPaused ? L10n.resume : L10n.pause)
                                .font(.system(size: Tokens.FontSize.sm, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.text.subtle)
                        }
                    }
                    .buttonStyle(RestPressStyle())
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Tokens.Spacing.xxxl + Tokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private var trackingPage: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: topHeaderHeight + 16)

            Spacer(minLength: 0)

            VStack(spacing: timerCardsSpacing) {
                sessionTimerView

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Tokens.Spacing.md) {
                            if workoutController.completedLaps.isEmpty {
                                PlaceholderLapCardView(accentColor: primaryColor)
                                    .offset(x: -Tokens.Spacing.md)
                            } else {
                                ForEach(workoutController.completedLaps, id: \.id) { lap in
                                    Button {
                                        presentLapEditor(for: lap)
                                    } label: {
                                        LapCardView(lap: lap, trackingMode: workoutController.trackingMode, distanceUnit: settings.distanceUnit, accentColor: primaryColor, isLatest: lap.id == workoutController.completedLaps.last?.id)
                                    }
                                    .buttonStyle(LapCardPressStyle())
                                    .id(lap.id)
                                }
                            }
                        }
                        .padding(.leading, Tokens.Spacing.md)
                        .padding(.trailing, Tokens.Spacing.md)
                        .frame(minWidth: WKInterfaceDevice.current().screenBounds.width, alignment: .trailing)
                    }
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .contentShape(Rectangle())
                    .onAppear {
                        scrollLapHistoryToLatest(using: proxy, animated: false)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { _ in
                                isLapHistoryDragging = true
                            }
                            .onEnded { _ in
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(120))
                                    isLapHistoryDragging = false
                                }
                            }
                    )
                    .onChange(of: workoutController.completedLaps.count) {
                        scrollLapHistoryToLatest(using: proxy, animated: true)

                        let lapCount = workoutController.completedLaps.count
                        if ActiveSessionTimerAnimationRouting.shouldAnimateOnLapCountChange(
                            lapCount: lapCount,
                            lastAnimatedLapCount: lastAnimatedLapCount,
                            pendingLapAnimationCount: pendingLapAnimationCount
                        ) {
                            animateTimerForNewLap()
                        }
                        pendingLapAnimationCount = ActiveSessionTimerAnimationRouting.resolvedPendingLapAnimationCount(
                            lapCount: lapCount,
                            pendingLapAnimationCount: pendingLapAnimationCount
                        )
                        lastAnimatedLapCount = lapCount
                    }
                }
                .frame(height: 64)
                .padding(.trailing, lapHistoryContainerTrailingPadding)
            }
            .padding(.bottom, 4)
        }
        .offset(y: contentVerticalOffset)
    }

    var body: some View {
        ZStack {
            AppScreenBackground(accentColor: primaryColor)

            TabView(selection: $selectedPage) {
                controlsPage.tag(0)
                trackingPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedPage)
        }
        .overlay(alignment: .topLeading) {
            let screenWidth = WKInterfaceDevice.current().screenBounds.width
            heartRateOverlay
                .padding(.leading, screenWidth * 0.07 + 6)
                .offset(y: -46)
        }
        .overlay(alignment: .top) {
            pageIndicatorView
                .offset(y: -44)
        }
        .overlay {
            ZStack {
                RadialGradient(
                    colors: [
                        Color.white.opacity(isTimerGlowActive ? 0.14 : 0),
                        primaryColor.opacity(isTimerGlowActive ? 0.2 : 0),
                        .clear
                    ],
                    center: .center,
                    startRadius: Tokens.Spacing.xxxl,
                    endRadius: 170
                )
                .animation(timerGlowAnimation, value: isTimerGlowActive)
                .ignoresSafeArea()

            }
            .allowsHitTesting(false)
        }
        .overlay {
            if isShowingSessionComplete {
                SessionCompleteView(
                    accentColor: primaryColor,
                    onDismiss: dismissCompletedSessionIfNeeded
                )
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isShowingSessionComplete)
        .fullScreenCover(isPresented: Binding(
            get: { lapEditorState != nil },
            set: { presented in
                if !presented {
                    lapEditorState = nil
                }
            }
        )) {
            if let lapEditorState {
                LapEditorScreen(
                    editor: lapEditorState,
                    distanceUnit: settings.distanceUnit,
                    accentColor: primaryColor,
                    onDismiss: { finalState in
                        saveLapEditor(finalState)
                        self.lapEditorState = nil
                    },
                    onDelete: { editor in
                        workoutController.deleteLap(id: editor.id)
                        self.lapEditorState = nil
                    }
                )
            }
        }
        .onAppear {
            lastAnimatedLapCount = workoutController.completedLaps.count
            syncTimerStatusBadge(animated: false)
        }
        .onChange(of: timerStatusBadgeText) {
            syncTimerStatusBadge(animated: true)
        }
        .onDisappear {
            completedSessionDismissTask?.cancel()
            restTransitionTask?.cancel()
            timerStatusBadgeHideTask?.cancel()
            timerStatusBadgeShowTask?.cancel()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
    }

    private func finishSession() {
        guard !isEndingSession else { return }

        isEndingSession = true
        workoutController.prepareForSessionEnd()
        workoutController.commitFinalLap()
        isShowingSessionComplete = true

        Task {
            await endSession()
            await MainActor.run {
                scheduleCompletedSessionDismissal()
            }
        }
    }

    private func endSession() async {
        let routeLocations = workoutController.collectedRouteLocations
        let session = await workoutController.endSession()
        if let session {
            persistence.saveSession(session)
            syncManager.queueCompletedSession(session)
            settings.storeSessionIntervalPresetIfUnique(session.snapshotWorkoutPlan)
            settings.recordPresetUsage(for: session.snapshotWorkoutPlan)
            Task.detached {
                do {
                    let uuid = try await self.healthKitManager.saveWorkout(session: session, routeLocations: routeLocations)
                    await MainActor.run {
                        session.healthKitWorkoutUUID = uuid
                        session.updatedAt = Date()
                        try? self.persistence.modelContext.save()
                    }
                } catch {
                    print("HealthKit export failed: \(error)")
                }
            }
        }
    }

    private func scheduleCompletedSessionDismissal() {
        completedSessionDismissTask?.cancel()
        completedSessionDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                dismissCompletedSessionIfNeeded()
            }
        }
    }

    private func dismissCompletedSessionIfNeeded() {
        guard !hasDismissedCompletedSession else { return }

        hasDismissedCompletedSession = true
        completedSessionDismissTask?.cancel()
        completedSessionDismissTask = nil
        onSessionEnded()
    }

    private func syncTimerStatusBadge(animated: Bool) {
        timerStatusBadgeHideTask?.cancel()
        timerStatusBadgeShowTask?.cancel()
        let targetText = timerStatusBadgeText

        guard animated else {
            displayedTimerStatusBadgeText = targetText
            isTimerStatusBadgeVisible = false
            guard targetText != nil else { return }
            timerStatusBadgeShowTask = Task {
                try? await Task.sleep(for: .seconds(timerStatusBadgeAppearanceDelay))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(timerStatusBadgeAnimation) {
                        isTimerStatusBadgeVisible = true
                    }
                }
            }
            return
        }

        guard displayedTimerStatusBadgeText != nil else {
            displayedTimerStatusBadgeText = targetText
            guard targetText != nil else {
                isTimerStatusBadgeVisible = false
                return
            }
            isTimerStatusBadgeVisible = false
            timerStatusBadgeShowTask = Task {
                try? await Task.sleep(for: .seconds(timerStatusBadgeAppearanceDelay))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(timerStatusBadgeAnimation) {
                        isTimerStatusBadgeVisible = true
                    }
                }
            }
            return
        }

        withAnimation(timerStatusBadgeAnimation) {
            isTimerStatusBadgeVisible = false
        }
        timerStatusBadgeHideTask = Task {
            try? await Task.sleep(for: .milliseconds(Int(timerStatusBadgeAnimationDuration * 1000)))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                displayedTimerStatusBadgeText = targetText
                guard targetText != nil else { return }
                timerStatusBadgeShowTask = Task {
                    try? await Task.sleep(for: .seconds(timerStatusBadgeAppearanceDelay))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation(timerStatusBadgeAnimation) {
                            isTimerStatusBadgeVisible = true
                        }
                    }
                }
            }
        }
    }

    private func handleLapTap() {
        if isWorkoutPaused {
            workoutController.resumeSession()
            animateTimerForNewLap()
            return
        }

        pendingLapAnimationCount = ActiveSessionTimerAnimationRouting.nextPendingLapCount(
            currentLapCount: workoutController.completedLaps.count
        )
        animateTimerForNewLap()
        workoutController.markLap()
    }

    private func handleRestButtonTap() {
        switch ActiveSessionControlRouting.restButtonAction(
            for: workoutController.runState,
            currentRecoveryType: workoutController.currentRecoveryType
        ) {
        case .startRest:
            workoutController.startRest(shouldPlayHaptic: false)
        case .cancelRest:
            workoutController.cancelRest()
        case .toggleRestWhilePaused:
            workoutController.toggleRestWhilePaused()
        }

        animateControlPageReturn()
    }

    private func presentLapEditor(for lap: Lap) {
        let editableLapType = ActiveSessionLapEditorRouting.editableLapType(for: lap)
        let sourceSegment = ActiveSessionLapEditorRouting.sourceSegment(
            for: lap,
            laps: workoutController.completedLaps,
            distanceSegments: workoutController.distanceSegments,
            trackingMode: workoutController.trackingMode
        )
        let editableDistanceMeters = ActiveSessionLapEditorRouting.editableDistanceMeters(for: lap)
        let initialDistanceText = distanceText(from: editableDistanceMeters)
        let sourceAllowsDistanceInput = ActiveSessionLapEditorRouting.sourceAllowsDistanceInput(for: sourceSegment)
        lapEditorState = LapEditorState(
            id: lap.id,
            lapType: editableLapType,
            distanceText: sourceAllowsDistanceInput && ActiveSessionLapEditorRouting.usesDistanceInput(for: editableLapType)
                ? defaultDistanceTextIfNeeded(initialDistanceText)
                : initialDistanceText,
            editableDistanceMeters: editableDistanceMeters,
            sourceAllowsDistanceInput: sourceAllowsDistanceInput
        )
    }

    private func defaultDistanceTextIfNeeded(_ text: String) -> String {
        text.isEmpty ? defaultLapDistanceText : text
    }

    private func saveLapEditor(_ editor: LapEditorState) {
        workoutController.updateLap(
            id: editor.id,
            newType: editor.lapType,
            newDistanceMeters: editor.showsDistanceInput
                ? meters(from: defaultDistanceTextIfNeeded(editor.distanceText))
                : editor.editableDistanceMeters
        )
        lapEditorState = nil
    }

    private func distanceText(from meters: Double) -> String {
        let displayValue: Double
        switch settings.distanceUnit {
        case .km:
            displayValue = meters
        case .miles:
            displayValue = meters * 3.28084
        }

        guard displayValue > 0 else { return "" }
        return displayValue == floor(displayValue)
            ? String(format: "%.0f", displayValue)
            : String(format: "%g", displayValue)
    }

    private func meters(from distanceText: String) -> Double {
        let value = Double(distanceText) ?? 0
        switch settings.distanceUnit {
        case .km:
            return value
        case .miles:
            return value / 3.28084
        }
    }

    private func animateTimerForNewLap() {
        bounceTask?.cancel()
        glowTask?.cancel()

        isTimerGlowActive = true
        isTimerBounceActive = true

        bounceTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isTimerBounceActive = false
            }
        }

        glowTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isTimerGlowActive = false
            }
        }
    }

    private func animateControlPageReturn() {
        restTransitionTask?.cancel()
        restTransitionTask = Task {
            try? await Task.sleep(for: ActiveSessionControlRouting.pageTransitionDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                selectedPage = 1
            }
        }
    }

    private func scrollLapHistoryToLatest(using proxy: ScrollViewProxy, animated: Bool) {
        guard let latestLapID = ActiveSessionLapHistoryRouting.latestLapID(in: workoutController.completedLaps) else {
            return
        }

        Task { @MainActor in
            await Task.yield()
            if animated {
                withAnimation {
                    proxy.scrollTo(latestLapID, anchor: .trailing)
                }
            } else {
                proxy.scrollTo(latestLapID, anchor: .trailing)
            }
        }
    }
}

enum ActiveSessionControlRouting {
    enum RestButtonAction {
        case startRest
        case cancelRest
        case toggleRestWhilePaused
    }

    enum PauseResumeAction {
        case pause
        case resume
    }

    static let pageTransitionDelay = Duration.milliseconds(140)

    static func restButtonAction(
        for runState: WorkoutRunState,
        currentRecoveryType: SegmentRecoveryType? = nil
    ) -> RestButtonAction {
        switch runState {
        case .paused:
            return .toggleRestWhilePaused
        case .rest where currentRecoveryType != .activeRecovery:
            return .cancelRest
        case .idle, .ready, .active, .rest, .ending, .ended:
            return .startRest
        }
    }

    static func pauseResumeAction(for runState: WorkoutRunState) -> PauseResumeAction {
        runState == .paused ? .resume : .pause
    }
}

private enum StatusBadgeStyle {
    static let font = Font.system(size: Tokens.FontSize.md, weight: .regular, design: .rounded)
    static let horizontalPadding: CGFloat = Tokens.Spacing.sm
    static let verticalPadding: CGFloat = Tokens.Spacing.xxxs

    static func background(_ theme: AppTheme) -> some View {
        Capsule(style: .continuous)
            .fill(theme.background.statusBadge)
    }
}

enum ActiveSessionTimerBadgeContent {
    static func statusText(
        runState: WorkoutRunState,
        willResumeIntoRest: Bool,
        willResumeIntoActiveRecovery: Bool,
        currentRecoveryType: SegmentRecoveryType?,
        restDurationSeconds: Int? = nil
    ) -> String? {
        switch runState {
        case .paused:
            if willResumeIntoActiveRecovery {
                if let restDurationSeconds, restDurationSeconds > 0 {
                    return L10n.activeRecoveryModePausedStatusWithDuration(restDurationText(seconds: restDurationSeconds))
                }
                return L10n.activeRecoveryModePausedStatus
            }
            guard willResumeIntoRest else { return L10n.workoutPaused }
            if let restDurationSeconds, restDurationSeconds > 0 {
                return L10n.restModePausedStatusWithDuration(restDurationText(seconds: restDurationSeconds))
            }
            return L10n.restModePausedStatus
        case .rest:
            if currentRecoveryType == .activeRecovery {
                if let restDurationSeconds, restDurationSeconds > 0 {
                    return L10n.activeRecoveryModeStatusWithDuration(restDurationText(seconds: restDurationSeconds))
                }
                return L10n.activeRecoveryModeStatus
            }
            if let restDurationSeconds, restDurationSeconds > 0 {
                return L10n.restModeStatusWithDuration(restDurationText(seconds: restDurationSeconds))
            }
            return L10n.restModeStatus
        case .idle, .ready, .active, .ending, .ended:
            return nil
        }
    }

    private static func restDurationText(seconds: Int) -> String {
        let totalSeconds = max(0, seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60

        if minutes > 0, remainingSeconds > 0 {
            return "\(minutes)\(L10n.minutesAbbrev) \(remainingSeconds)\(L10n.secondsAbbrev)"
        }

        if minutes > 0 {
            return "\(minutes)\(L10n.minutesAbbrev)"
        }

        return "\(remainingSeconds)\(L10n.secondsAbbrev)"
    }
}

private struct LapEditorState: Identifiable {
    let id: UUID
    var lapType: LapType
    var distanceText: String
    var editableDistanceMeters: Double
    var sourceAllowsDistanceInput: Bool

    var showsDistanceInput: Bool {
        sourceAllowsDistanceInput && ActiveSessionLapEditorRouting.usesDistanceInput(for: lapType)
    }
}

enum ActiveSessionLapEditorRouting {
    static func editableLapType(for lap: Lap) -> LapType {
        lap.lapType
    }

    static func editableDistanceMeters(for lap: Lap) -> Double {
        guard usesDistanceInput(for: lap.lapType) else { return lap.distanceMeters }
        return lap.gpsDistanceMeters ?? lap.distanceMeters
    }

    static func sourceSegment(
        for lap: Lap,
        laps: [Lap],
        distanceSegments: [DistanceSegment],
        trackingMode: TrackingMode
    ) -> DistanceSegment? {
        guard trackingMode.usesManualIntervals, !distanceSegments.isEmpty else { return nil }

        let workoutPlan = WorkoutPlanSnapshot(
            trackingMode: trackingMode,
            distanceSegments: distanceSegments
        )
        let activeTargets = SessionLapTargetResolver.targetSegments(
            for: laps,
            workoutPlan: workoutPlan,
            trackingMode: trackingMode
        )

        if let activeSegment = activeTargets[lap.id] {
            return activeSegment
        }

        var lastActiveSegment: DistanceSegment?

        for completedLap in laps {
            if let activeSegment = activeTargets[completedLap.id] {
                lastActiveSegment = activeSegment
            }

            if completedLap.id == lap.id {
                return lastActiveSegment
            }
        }

        return nil
    }

    static func sourceAllowsDistanceInput(for sourceSegment: DistanceSegment?) -> Bool {
        sourceSegment?.usesOpenDistance != true
    }

    static func usesDistanceInput(for lapType: LapType) -> Bool {
        lapType != .rest
    }
}

private let latestCardHeight: CGFloat = 58
private let lapCardTopPadding: CGFloat = 10
private let lapCardLeadingPadding: CGFloat = 8
private let lapCardBottomPadding: CGFloat = 10
private let lapCardTrailingPadding: CGFloat = 14
struct PlaceholderLapCardView: View {
    var accentColor: Color = .blue
    @Environment(\.appTheme) private var theme

    private var borderColor: Color {
        theme.isDark ? theme.stroke.neutral : theme.stroke.emphasis(accentColor)
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Text("1")
                .font(.system(size: Tokens.FontSize.xxl, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.text.bold)
                .padding(.horizontal, Tokens.Spacing.xs)
                .padding(.vertical, 0)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                        .fill(theme.background.bold)
                )
                .opacity(0.6)
            Text(L10n.lapCardPlaceholder)
                .font(.system(size: 25, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.text.neutral.opacity(0.6))
        }
        .padding(.top, lapCardTopPadding)
        .padding(.leading, lapCardLeadingPadding)
        .padding(.bottom, lapCardBottomPadding)
        .padding(.trailing, lapCardTrailingPadding)
        .frame(height: latestCardHeight)
        .background(theme.background.emphasisCard(accentColor))
        .cornerRadius(Tokens.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.xl)
                .inset(by: Tokens.LineWidth.thin)
                .stroke(borderColor, lineWidth: Tokens.LineWidth.medium)
        )
    }
}

struct LapCardView: View {
    let lap: Lap
    let trackingMode: TrackingMode
    var distanceUnit: DistanceUnit = .km
    var accentColor: Color = .blue
    var isLatest: Bool = false
    @Environment(\.appTheme) private var theme

    private var isRecovery: Bool { lap.lapType.isRecovery }

    private var cardBackgroundColor: Color {
        if isRecovery {
            return theme.background.bold
        }

        return theme.background.emphasisCard(accentColor)
    }

    private var borderColor: Color {
        theme.isDark ? theme.stroke.neutral : theme.stroke.emphasis(accentColor)
    }

    var body: some View {
        Group {
            if isRecovery {
                Text(Formatters.compactTimeString(from: lap.durationSeconds))
                    .font(.system(size: 25, weight: .medium, design: .rounded))
                    .monospacedDigit()
            } else {
                HStack(spacing: Tokens.Spacing.sm) {
                    Text("\(lap.index)")
                        .font(.system(size: Tokens.FontSize.xxl, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.text.bold)
                        .padding(.horizontal, Tokens.Spacing.xs)
                        .padding(.vertical, 0)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                                .fill(theme.background.bold)
                        )
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Formatters.compactTimeString(from: lap.durationSeconds))
                            .font(.system(size: 25, weight: .medium, design: .rounded))
                            .monospacedDigit()
                        Text(Formatters.paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: distanceUnit))
                            .font(.system(size: Tokens.FontSize.xl, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        if trackingMode == .dual,
                           let gpsDistanceMeters = lap.gpsDistanceMeters,
                           gpsDistanceMeters > 0 {
                            Text(L10n.gpsDistance(Formatters.distanceString(meters: gpsDistanceMeters, unit: distanceUnit)))
                                .font(.system(size: Tokens.FontSize.xs, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.top, lapCardTopPadding)
        .padding(.leading, lapCardLeadingPadding)
        .padding(.bottom, lapCardBottomPadding)
        .padding(.trailing, isRecovery ? lapCardLeadingPadding : lapCardTrailingPadding)
        .frame(height: latestCardHeight)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundColor(isRecovery ? theme.text.bold : theme.text.neutral)
        .background(cardBackgroundColor)
        .cornerRadius(Tokens.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.xl)
            .inset(by: !isRecovery ? Tokens.LineWidth.thin : 0)
            .stroke(borderColor, lineWidth: !isRecovery ? Tokens.LineWidth.medium : 0)
        )
    }
}

private struct LapEditorScreen: View {
    let editor: LapEditorState
    let distanceUnit: DistanceUnit
    let accentColor: Color
    let onDismiss: (LapEditorState) -> Void
    let onDelete: (LapEditorState) -> Void
    @Environment(\.appTheme) private var theme

    @State private var lapType: LapType
    @State private var distanceText: String
    @State private var didDelete = false
    @State private var isLapTypePickerPresented = false

    init(editor: LapEditorState, distanceUnit: DistanceUnit, accentColor: Color, onDismiss: @escaping (LapEditorState) -> Void, onDelete: @escaping (LapEditorState) -> Void) {
        self.editor = editor
        self.distanceUnit = distanceUnit
        self.accentColor = accentColor
        self.onDismiss = onDismiss
        self.onDelete = onDelete
        _lapType = State(initialValue: editor.lapType)
        _distanceText = State(initialValue: editor.distanceText)
    }

    private var label: String {
        switch distanceUnit {
        case .km: return L10n.distanceMetersShort
        case .miles: return L10n.distanceFeetShort
        }
    }

    private let defaultDistanceText = "400"

    var body: some View {
        ZStack {
            AppScreenBackground(accentColor: accentColor)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.editLap)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.text.neutral)

                    Button {
                        isLapTypePickerPresented = true
                    } label: {
                        HStack(alignment: .center, spacing: Tokens.Spacing.sm) {
                            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                                Text(L10n.lapType)
                                    .font(.system(size: Tokens.FontSize.sm, weight: .medium, design: .rounded))
                                    .foregroundStyle(theme.text.subtle)

                                Text(currentLapTypeTitle)
                                    .font(.system(size: Tokens.FontSize.lg, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.text.neutral)
                            }

                            Spacer(minLength: Tokens.Spacing.sm)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: Tokens.FontSize.md, weight: .bold))
                                .foregroundStyle(theme.text.subtle)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.leading, ActiveSessionLapEditorLayout.lapTypeLeadingPadding)
                        .padding(.trailing, ActiveSessionLapEditorLayout.lapTypeTrailingPadding)
                        .padding(.vertical, Tokens.Spacing.md)
                        .background(theme.background.neutralAction)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if currentState.showsDistanceInput {
                        DistanceInputView(
                            label: label,
                            accentColor: accentColor,
                            text: $distanceText
                        )
                        .frame(maxWidth: .infinity)
                    }

                    Button(L10n.deleteLap, role: .destructive) {
                        didDelete = true
                        onDelete(currentState)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.red)
                    .padding(.top, Tokens.Spacing.lg)
                }
                .padding(.horizontal, Tokens.Spacing.xl)
                .padding(.vertical, Tokens.Spacing.xl)
            }
        }
        .onDisappear {
            if !didDelete {
                onDismiss(currentState)
            }
        }
        .confirmationDialog(currentLapTypeTitle, isPresented: $isLapTypePickerPresented, titleVisibility: .visible) {
            Button(L10n.activity) {
                updateLapType(.active)
            }

            Button(L10n.activeRecovery) {
                updateLapType(.activeRecovery)
            }

            Button(L10n.restLap) {
                updateLapType(.rest)
            }

            Button(L10n.cancel, role: .cancel) {}
        }
    }

    private var currentState: LapEditorState {
        LapEditorState(
            id: editor.id,
            lapType: lapType,
            distanceText: distanceText,
            editableDistanceMeters: editor.editableDistanceMeters,
            sourceAllowsDistanceInput: editor.sourceAllowsDistanceInput
        )
    }

    private var currentLapTypeTitle: String {
        switch lapType {
        case .active:
            return L10n.activity
        case .activeRecovery:
            return L10n.activeRecovery
        case .rest:
            return L10n.restLap
        }
    }

    private func updateLapType(_ type: LapType) {
        lapType = type

        if currentState.showsDistanceInput && distanceText.isEmpty {
            distanceText = defaultDistanceText
        }
    }
}

enum ActiveSessionLapEditorLayout {
    static let lapTypeLeadingPadding: CGFloat = Tokens.Spacing.xl + Tokens.Spacing.xs
    static let lapTypeTrailingPadding: CGFloat = Tokens.Spacing.md
}

private struct WorkoutControlIcon: View {
    let systemName: String
    let baseColor: Color
    var size: CGFloat = 46
    var isSecondary: Bool = false
    var isDashed: Bool = false
    var iconFontSizeOverride: CGFloat? = nil
    @Environment(\.appTheme) private var theme

    private var iconFontSize: CGFloat {
        iconFontSizeOverride ?? (Tokens.FontSize.xl * (size / 46))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(isSecondary ? theme.background.emphasisAction(baseColor) : theme.background.emphasisAction(baseColor))

            if !isSecondary {
                Circle()
                    .stroke(
                        isDashed
                            ? (theme.isDark ? theme.stroke.emphasisAction(baseColor) : Color.white)
                            : theme.stroke.emphasisAction(baseColor),
                        style: StrokeStyle(
                            lineWidth: Tokens.LineWidth.thick,
                            lineCap: isDashed ? .round : .butt,
                            lineJoin: isDashed ? .round : .miter,
                            dash: isDashed ? [0, 6] : []
                        )
                    )
                    .padding(Tokens.LineWidth.regular)
            }
        }
        .overlay {
            Image(systemName: systemName)
                .font(.system(size: iconFontSize, weight: .bold))
                .foregroundStyle(theme.text.emphasis)
        }
        .frame(width: size, height: size)
        .shadow(color: (isSecondary ? Color.gray : baseColor).opacity(Tokens.Opacity.shadow), radius: Tokens.Radius.small, y: 2)
    }
}

private struct SessionCompleteView: View {
    let accentColor: Color
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            AppScreenBackground(accentColor: accentColor)

            Button(action: onDismiss) {
                Image(systemName: "checkmark")
                    .font(.system(size: 96, weight: .medium))
                    .foregroundStyle(theme.text.neutral)
                    .padding(Tokens.Spacing.xxxxl)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Press Styles

enum ActiveSessionTimerAnimationRouting {
    static func nextPendingLapCount(currentLapCount: Int) -> Int {
        currentLapCount + 1
    }

    static func shouldAnimateOnLapCountChange(
        lapCount: Int,
        lastAnimatedLapCount: Int,
        pendingLapAnimationCount: Int?
    ) -> Bool {
        lapCount > lastAnimatedLapCount && lapCount > 0 && pendingLapAnimationCount != lapCount
    }

    static func resolvedPendingLapAnimationCount(
        lapCount: Int,
        pendingLapAnimationCount: Int?
    ) -> Int? {
        guard let pendingLapAnimationCount else { return nil }
        return lapCount >= pendingLapAnimationCount ? nil : pendingLapAnimationCount
    }
}

enum ActiveSessionHeaderRouting {
    static func showsSessionCompletionIndicator(remainingPlannedIntervals: Int?) -> Bool {
        remainingPlannedIntervals == 0
    }
}

enum ActiveSessionLapHistoryRouting {
    static func latestLapID(in laps: [Lap]) -> UUID? {
        laps.last?.id
    }
}

private struct RestPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct LapCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
