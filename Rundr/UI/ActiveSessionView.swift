import SwiftUI
import WatchKit

struct ActiveSessionView: View {
    @EnvironmentObject var workoutController: WorkoutSessionController
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var syncManager: WatchConnectivitySyncManager

    var onSessionEnded: () -> Void
    @State private var isTapFlashVisible = false
    @State private var isTimerBounceActive = false
    @State private var isTimerGlowActive = false
    @State private var isLapHistoryDragging = false
    @State private var lastAnimatedLapCount = 0
    @State private var lapEditorState: LapEditorState?
    @State private var isRestPulseOn = false
    @State private var isPausePulseOn = false
    @State private var isTimeGoalPulseOn = false
    @State private var flashTask: Task<Void, Never>?
    @State private var bounceTask: Task<Void, Never>?
    @State private var glowTask: Task<Void, Never>?
    @State private var restTransitionTask: Task<Void, Never>?
    @State private var isShowingSessionComplete = false
    @State private var isEndingSession = false
    @State private var hasDismissedCompletedSession = false
    @State private var completedSessionDismissTask: Task<Void, Never>?
    @State private var selectedPage: Int = 1
    @State private var isShowingEndConfirmation = false

    private let defaultLapDistanceText = "400"

    private var primaryColor: Color {
        settings.primaryAccentColor
    }

    private var isResting: Bool {
        workoutController.runState == .rest
    }

    private var isWorkoutPaused: Bool {
        workoutController.runState == .paused
    }

    private var restButtonShowsEndRest: Bool {
        isResting || workoutController.willResumeIntoRest
    }

    private var currentLapNumber: Int {
        workoutController.completedLaps.filter { $0.lapType == .active }.count + 1
    }

    private var lapCounterTotal: Int? {
        guard let total = workoutController.totalPlannedIntervals, total > 0 else { return nil }
        return total
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
            } ?? L10n.openDistance
            if let targetTime = workoutController.currentTargetTimeSeconds {
                let timeStr = Formatters.compactTimeString(from: targetTime)
                if workoutController.currentTargetDistanceMeters != nil {
                    return timerTopLabel(L10n.targetDisplay(distanceStr, timeStr))
                }
                return timerTopLabel(L10n.openTargetDisplay(timeStr))
            }
            return timerTopLabel(distanceStr)
        }
        return timerTopLabel()
    }

    private var timerStatusBadgeText: String? {
        ActiveSessionTimerBadgeContent.statusText(
            runState: workoutController.runState,
            willResumeIntoRest: workoutController.willResumeIntoRest
        )
    }

    @Environment(\.appTheme) private var theme

    private var timerBorderOverlay: some View {
        Capsule()
            .strokeBorder(theme.stroke.emphasisAction(primaryColor), style: StrokeStyle(lineWidth: Tokens.LineWidth.thick, dash: restButtonShowsEndRest ? [6, 4] : []))
    }

    private var lapGlowOverlay: some View {
        Capsule()
            .stroke(Color.white.opacity(isTimerGlowActive ? 0.6 : 0), lineWidth: Tokens.LineWidth.thick)
            .blur(radius: isTimerGlowActive ? 3 : 0)
    }

    private var displayedLapCounter: Int {
        isResting ? max(currentLapNumber - 1, 1) : currentLapNumber
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
                                .foregroundStyle(theme.text.bold)
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
                            .foregroundStyle(theme.text.bold)
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
                }
            }
            .overlay(alignment: .top) {
                if let timerStatusBadgeText {
                    Text(timerStatusBadgeText)
                        .font(StatusBadgeStyle.font)
                        .foregroundStyle(primaryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, StatusBadgeStyle.horizontalPadding)
                        .padding(.vertical, StatusBadgeStyle.verticalPadding)
                        .background(StatusBadgeStyle.background(theme))
                        .offset(y: -Tokens.Spacing.badgeLift)
                }
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
        Button {
            handleLapTap()
        } label: {
            Text(Formatters.precisionTimeString(from: workoutController.lapElapsedSeconds))
                .font(.system(size: timerFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .foregroundStyle(theme.text.neutral)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.vertical, Tokens.Spacing.sm)
                .frame(maxHeight: 120)
                .background(Capsule().fill(theme.background.emphasisAction(primaryColor)))
                .overlay(timerBorderOverlay)
                .overlay(lapGlowOverlay)
                .overlay(alignment: .top) {
                    timerTopOverlay
                        .offset(y: -31)
                }
                .scaleEffect(isTimerBounceActive ? 1.11 : 1)
                .brightness(isTimerGlowActive ? 0.3 : 0)
                .shadow(color: Color.white.opacity(isTimerGlowActive ? 0.5 : 0), radius: 18)
                .shadow(color: primaryColor.opacity(isTimerGlowActive ? 0.72 : 0), radius: 24)
                .padding(.horizontal, Tokens.Spacing.xs)
                .contentShape(Capsule())
        }
        .buttonStyle(TimerPressStyle())
    }

    private let topHeaderHeight: CGFloat = 66
    private let contentVerticalOffset: CGFloat = -4
    private let lapHistoryContainerTrailingPadding: CGFloat = 12
    private let timerCardsSpacing: CGFloat = 6

    @ViewBuilder
    private var heartRateOverlay: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: "heart.fill")
                .font(.system(size: Tokens.FontSize.xs, weight: .semibold))
                .foregroundStyle(theme.text.neutral)

            Text(Formatters.heartRateString(bpm: workoutController.currentHeartRate))
                .font(.system(size: Tokens.FontSize.sm, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text.neutral)
                .monospacedDigit()
        }
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
                            systemName: restButtonShowsEndRest ? "figure.run" : "figure.cooldown",
                            baseColor: primaryColor,
                            size: 78,
                            isDashed: restButtonShowsEndRest,
                            iconFontSizeOverride: 34
                        )
                        Text(restButtonShowsEndRest ? L10n.endRest : (settings.restMode == .autoDetect ? L10n.restModeAuto : L10n.restMode))
                            .font(.system(size: Tokens.FontSize.sm, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.text.subtle)
                    }
                }
                .buttonStyle(RestPressStyle())

                HStack(spacing: Tokens.Spacing.xxxxl) {
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

                    Button {
                        if isWorkoutPaused {
                            workoutController.resumeSession()
                        } else {
                            workoutController.pauseSession()
                        }
                        selectedPage = 1
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Tokens.Spacing.xl)
        }
    }

    @ViewBuilder
    private var trackingPage: some View {
        ZStack {
            // Keep pause/rest pulses behind content so labels remain readable.
            // Always present in the view tree (opacity-only hiding) to avoid
            // changing the ZStack child count during layout, which can trigger
            // an infinite PUICCarouselCollectionViewLayout invalidation loop.
            Color.white
                .opacity(isResting && isPausePulseOn ? 0.1 : 0)
                .ignoresSafeArea()

            Color.white
                .opacity(isResting && isRestPulseOn ? 0.3 : 0)
                .ignoresSafeArea()

            Color.white
                .opacity(workoutController.isTimeGoalWarningActive && isTimeGoalPulseOn ? 0.15 : 0)
                .ignoresSafeArea()

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
                            if let lastLap = workoutController.completedLaps.last {
                                withAnimation {
                                    proxy.scrollTo(lastLap.id, anchor: .trailing)
                                }
                            }

                            let lapCount = workoutController.completedLaps.count
                            if lapCount > lastAnimatedLapCount && lapCount > 0 {
                                animateTimerForNewLap()
                            }
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
    }

    var body: some View {
        ZStack {
            AppScreenBackground(accentColor: primaryColor)

            TabView(selection: $selectedPage) {
                controlsPage.tag(0)
                trackingPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .animation(.easeInOut(duration: 0.3), value: selectedPage)
        }
        .overlay(alignment: .topLeading) {
            let screenWidth = WKInterfaceDevice.current().screenBounds.width
            heartRateOverlay
                .padding(.leading, screenWidth * 0.07 + 4)
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
                .ignoresSafeArea()

                Color.white
                    .opacity(isTapFlashVisible ? 0.22 : 0)
                    .ignoresSafeArea()
            }
            .allowsHitTesting(false)
        }
        .onChange(of: isResting) { _, paused in
            if paused {
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    isPausePulseOn = true
                }
            } else {
                withAnimation(nil) { isPausePulseOn = false }
            }
        }
        .onChange(of: workoutController.isRestWarningActive) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                    isRestPulseOn = true
                }
            } else {
                withAnimation(nil) { isRestPulseOn = false }
            }
        }
        .onChange(of: workoutController.isTimeGoalWarningActive) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    isTimeGoalPulseOn = true
                }
            } else {
                withAnimation(nil) { isTimeGoalPulseOn = false }
            }
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
        }
        .onDisappear {
            completedSessionDismissTask?.cancel()
            restTransitionTask?.cancel()
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
        let session = await workoutController.endSession()
        if let session {
            persistence.saveSession(session)
            syncManager.queueCompletedSession(session)
            settings.storeSessionIntervalPresetIfUnique(session.snapshotWorkoutPlan)
            settings.recordPresetUsage(for: session.snapshotWorkoutPlan)
            Task.detached {
                do {
                    let uuid = try await self.healthKitManager.saveWorkout(session: session)
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

    private func handleLapTap() {
        if isWorkoutPaused {
            workoutController.resumeSession()
            flashTapBorder()
            animateTimerForNewLap()
            return
        }
        flashTapBorder()
        workoutController.markLap()
    }

    private func handleRestButtonTap() {
        if isWorkoutPaused {
            workoutController.toggleRestWhilePaused()
        } else if isResting {
            workoutController.cancelRest()
        } else {
            workoutController.startRest()
        }

        animateRestButtonForPageTransition()
    }

    private func presentLapEditor(for lap: Lap) {
        let initialDistanceText = distanceText(from: lap.distanceMeters)
        lapEditorState = LapEditorState(
            id: lap.id,
            lapType: lap.lapType,
            distanceText: lap.lapType == .active ? defaultDistanceTextIfNeeded(initialDistanceText) : initialDistanceText
        )
    }

    private func defaultDistanceTextIfNeeded(_ text: String) -> String {
        text.isEmpty ? defaultLapDistanceText : text
    }

    private func saveLapEditor(_ editor: LapEditorState) {
        workoutController.updateLap(
            id: editor.id,
            newType: editor.lapType,
            newDistanceMeters: meters(from: defaultDistanceTextIfNeeded(editor.distanceText))
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

    private func flashTapBorder() {
        flashTask?.cancel()

        withAnimation(.easeOut(duration: 0.08)) {
            isTapFlashVisible = true
        }

        flashTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.18)) {
                    isTapFlashVisible = false
                }
            }
        }
    }

    private func animateTimerForNewLap() {
        bounceTask?.cancel()
        glowTask?.cancel()

        withAnimation(.easeOut(duration: 0.08)) {
            isTimerGlowActive = true
        }

        withAnimation(.easeOut(duration: 0.1)) {
            isTimerBounceActive = true
        }

        bounceTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.6)) {
                    isTimerBounceActive = false
                }
            }
        }

        glowTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.9)) {
                    isTimerGlowActive = false
                }
            }
        }
    }

    private func animateRestButtonForPageTransition() {
        restTransitionTask?.cancel()
        restTransitionTask = Task {
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                selectedPage = 1
            }
        }
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
    static func statusText(runState: WorkoutRunState, willResumeIntoRest: Bool) -> String? {
        switch runState {
        case .paused:
            return willResumeIntoRest ? L10n.restModePausedStatus : L10n.workoutPaused
        case .rest:
            return L10n.restModeStatus
        case .idle, .ready, .active, .ending, .ended:
            return nil
        }
    }
}

private struct LapEditorState: Identifiable {
    let id: UUID
    var lapType: LapType
    var distanceText: String
}

private let latestCardHeight: CGFloat = 58
private let lapCardTopPadding: CGFloat = 10
private let lapCardLeadingPadding: CGFloat = 8
private let lapCardBottomPadding: CGFloat = 10
private let lapCardTrailingPadding: CGFloat = 14
struct PlaceholderLapCardView: View {
    var accentColor: Color = .blue
    @Environment(\.appTheme) private var theme

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
            Text("—:——")
                .font(.system(size: 25, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(theme.text.neutral)
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
                .stroke(theme.stroke.neutral, lineWidth: Tokens.LineWidth.medium)
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

    private var isRest: Bool { lap.lapType == .rest }

    private var cardBackgroundColor: Color {
        if isRest {
            return theme.background.bold
        }

        return theme.background.emphasisCard(accentColor)
    }

    var body: some View {
        Group {
            if isRest {
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
        .padding(.trailing, isRest ? lapCardLeadingPadding : lapCardTrailingPadding)
        .frame(height: latestCardHeight)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundColor(isRest ? theme.text.bold : theme.text.neutral)
        .background(cardBackgroundColor)
        .cornerRadius(Tokens.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.xl)
                .inset(by: !isRest ? Tokens.LineWidth.thin : 0)
                .stroke(theme.stroke.neutral, lineWidth: !isRest ? Tokens.LineWidth.medium : 0)
        )
    }
}

private struct LapEditorScreen: View {
    let editor: LapEditorState
    let distanceUnit: DistanceUnit
    let accentColor: Color
    let onDismiss: (LapEditorState) -> Void
    let onDelete: (LapEditorState) -> Void

    @State private var lapType: LapType
    @State private var distanceText: String
    @State private var didDelete = false

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
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        lapTypeButton(title: L10n.activity, type: .active)
                        lapTypeButton(title: L10n.restLap, type: .rest)
                    }

                    if lapType == .active {
                        DistanceInputView(
                            label: label,
                            accentColor: accentColor,
                            text: $distanceText
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(L10n.lapTreatedAsRest)
                            .font(.system(size: Tokens.FontSize.lg, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(Tokens.Opacity.foregroundBody))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Tokens.Spacing.xs)
                            .padding(.vertical, Tokens.Spacing.xl)
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
    }

    private var currentState: LapEditorState {
        LapEditorState(id: editor.id, lapType: lapType, distanceText: distanceText)
    }

    @ViewBuilder
    private func lapTypeButton(title: String, type: LapType) -> some View {
        SelectionToggleButton(title: title, isSelected: lapType == type) {
            lapType = type
            if type == .active && distanceText.isEmpty {
                distanceText = defaultDistanceText
            }
        }
    }
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
                    .stroke(theme.stroke.emphasisAction(baseColor), style: StrokeStyle(lineWidth: Tokens.LineWidth.thick, dash: isDashed ? [6, 4] : []))
                    .padding(Tokens.LineWidth.regular)
            }
        }
        .overlay {
            Image(systemName: systemName)
                .font(.system(size: iconFontSize, weight: .bold))
                .foregroundStyle(theme.text.neutral)
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

private struct TimerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
