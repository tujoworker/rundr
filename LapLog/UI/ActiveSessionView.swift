import SwiftUI
import WatchKit

struct ActiveSessionView: View {
    @EnvironmentObject var workoutController: WorkoutSessionController
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var settings: SettingsStore

    var onSessionEnded: () -> Void
    @State private var isTapFlashVisible = false
    @State private var isSessionMenuPresented = false
    @State private var sessionMenuButtonLockedUntil = Date.distantPast
    @State private var isTimerBounceActive = false
    @State private var isTimerGlowActive = false
    @State private var isLapHistoryDragging = false
    @State private var lastAnimatedLapCount = 0
    @State private var lapEditorState: LapEditorState?
    @State private var isRestPulseOn = false
    @State private var isPausePulseOn = false

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

    private var showsSessionMenu: Bool {
        isResting || isWorkoutPaused
    }

    private func timerTopLabel(_ base: String) -> String {
        guard !base.isEmpty else { return base }
        guard let remainingIntervals = workoutController.remainingPlannedIntervals else { return base }
        return "\(base) · \(remainingIntervals) left"
    }

    private var timerTopLabel: String {
        if isWorkoutPaused {
            return L10n.workoutPaused
        }
        if isResting {
            if let duration = workoutController.restDurationSeconds {
                return timerTopLabel("Rest \(duration)s")
            }
            return timerTopLabel(L10n.restModeStatus)
        }
        if workoutController.trackingMode == .distanceDistance {
            return timerTopLabel(
                Formatters.distanceString(
                    meters: workoutController.currentTargetDistanceMeters,
                    unit: settings.distanceUnit
                )
            )
        }
        return ""
    }

    private var pauseBorderOverlay: some View {
        Capsule()
            .stroke(primaryColor.opacity(0.4), lineWidth: 8)
            .padding(1.5)
    }

    private var lapGlowOverlay: some View {
        Capsule()
            .stroke(Color.white.opacity(isTimerGlowActive ? 0.6 : 0), lineWidth: 3)
            .blur(radius: isTimerGlowActive ? 3 : 0)
    }

    @ViewBuilder
    private var sessionTimerView: some View {
        Text(Formatters.precisionTimeString(from: workoutController.lapElapsedSeconds))
            .font(.system(size: 100, weight: .medium, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.45)
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(Capsule().fill(primaryColor.opacity(0.2)))
            .overlay(pauseBorderOverlay)
            .overlay(lapGlowOverlay)
            .overlay(alignment: .top) {
                Text(timerTopLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .opacity(timerTopLabel.isEmpty ? 0 : 1)
                    .offset(y: -21)
            }
            .scaleEffect(isTimerBounceActive ? 1.11 : 1)
            .brightness(isTimerGlowActive ? 0.3 : 0)
            .shadow(color: Color.white.opacity(isTimerGlowActive ? 0.5 : 0), radius: 18)
            .shadow(color: primaryColor.opacity(isTimerGlowActive ? 0.72 : 0), radius: 24)
            .padding(.horizontal, 4)
            .contentShape(Capsule())
            .onTapGesture { handleLapTap() }
    }

    private let topControlOffset: CGFloat = -8
    private let topHeaderHeight: CGFloat = 66
    private let contentVerticalOffset: CGFloat = -4
    private let menuButtonExtraOffset: CGFloat = 0
    private let pauseButtonExtraOffset: CGFloat = 0
    private let lapHistoryContainerTrailingPadding: CGFloat = 12
    private let sessionMenuReopenDelay: TimeInterval = 0.35

    var body: some View {
        ZStack {
            AppScreenBackground(accentColor: primaryColor)

            // Keep pause/rest pulses behind content so labels remain readable.
            if isResting {
                Color.white
                    .opacity(isPausePulseOn ? 0.2 : 0)
                    .ignoresSafeArea()
            }

            if isResting {
                Color.white
                    .opacity(isRestPulseOn ? 0.6 : 0)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    HStack(alignment: .top) {
                        if showsSessionMenu {
                            sessionMenuButton
                                .offset(y: topControlOffset + menuButtonExtraOffset)
                        } else {
                            pauseButton
                                .offset(y: topControlOffset + pauseButtonExtraOffset)
                        }

                        Spacer()

                        Color.clear
                            .frame(width: 48, height: 48)
                    }
                    .padding(.top, -10)

                    HStack(spacing: 6) {
                        Text(Formatters.heartRateString(bpm: workoutController.currentHeartRate))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 2)
                    .offset(y: -16)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .frame(height: topHeaderHeight)
                .padding(.bottom, 16)

                sessionTimerView
                    .offset(y: -15)

                Color.clear
                    .frame(height: 6)
                    .contentShape(Rectangle())
                    .onTapGesture { handleLapTap() }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if workoutController.completedLaps.isEmpty {
                                PlaceholderLapCardView()
                                    .offset(x: -8)
                            } else {
                                ForEach(workoutController.completedLaps, id: \.id) { lap in
                                    LapCardView(lap: lap, trackingMode: workoutController.trackingMode, distanceUnit: settings.distanceUnit, isLatest: lap.id == workoutController.completedLaps.last?.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            presentLapEditor(for: lap)
                                        }
                                        .id(lap.id)
                                }
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 8)
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
                .padding(.bottom, 4)
                .offset(y: -10)

                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .offset(y: contentVerticalOffset)
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
                    startRadius: 18,
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
        .onChange(of: isSessionMenuPresented) { wasPresented, isPresented in
            if wasPresented != isPresented {
                sessionMenuButtonLockedUntil = Date().addingTimeInterval(sessionMenuReopenDelay)
            }
        }
        .confirmationDialog("", isPresented: $isSessionMenuPresented, titleVisibility: .hidden) {
            if isResting {
                Button {
                    workoutController.cancelRest()
                } label: {
                    Label(L10n.endRest, systemImage: "play.circle")
                }
            }
            if isWorkoutPaused {
                Button {
                    workoutController.resumeSession()
                } label: {
                    Label(L10n.resume, systemImage: "play.circle")
                }
            } else if isResting {
                Button {
                    workoutController.pauseSession()
                } label: {
                    Label(L10n.pause, systemImage: "pause.circle")
                }
            }
            Button(role: .destructive) {
                workoutController.prepareForSessionEnd()
                Task { await endSession() }
            } label: {
                Label(L10n.endSession, systemImage: "stop.circle")
            }
            Button("Cancel", role: .cancel) {}
        }
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
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
    }

    private func endSession() async {
        let session = await workoutController.endSession()
        if let session {
            persistence.saveSession(session)
            Task.detached {
                do {
                    let uuid = try await self.healthKitManager.saveWorkout(session: session)
                    await MainActor.run {
                        session.healthKitWorkoutUUID = uuid
                        try? self.persistence.modelContext.save()
                    }
                } catch {
                    print("HealthKit export failed: \(error)")
                }
            }
        }
        onSessionEnded()
    }

    private func handleLapTap() {
        if isWorkoutPaused {
            workoutController.resumeSession()
            return
        }
        flashTapBorder()
        workoutController.markLap()
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
        withAnimation(.easeOut(duration: 0.08)) {
            isTapFlashVisible = true
        }

        Task {
            try? await Task.sleep(for: .milliseconds(180))
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.18)) {
                    isTapFlashVisible = false
                }
            }
        }
    }

    private func animateTimerForNewLap() {
        withAnimation(.easeOut(duration: 0.08)) {
            isTimerGlowActive = true
        }

        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
            isTimerBounceActive = true
        }

        Task {
            try? await Task.sleep(for: .milliseconds(140))
            await MainActor.run {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.72)) {
                    isTimerBounceActive = false
                }
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(180))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.6)) {
                    isTimerGlowActive = false
                }
            }
        }
    }

    private var sessionMenuButton: some View {
        Button {
            let now = Date()
            guard now >= sessionMenuButtonLockedUntil else { return }
            sessionMenuButtonLockedUntil = now.addingTimeInterval(sessionMenuReopenDelay)
            isSessionMenuPresented = true
        } label: {
            WorkoutControlIcon(
                systemName: "ellipsis",
                baseColor: primaryColor
            )
        }
        .buttonStyle(.plain)
    }

    private var pauseButton: some View {
        Button {
            guard !showsSessionMenu else { return }
            workoutController.startRest()
        } label: {
            WorkoutControlIcon(
                systemName: "pause.fill",
                baseColor: primaryColor
            )
        }
        .buttonStyle(.plain)
        .opacity(showsSessionMenu ? 0.72 : 1)
    }
}

private struct LapEditorState: Identifiable {
    let id: UUID
    var lapType: LapType
    var distanceText: String
}

private let latestCardHeight: CGFloat = 54
private let lapCardTopPadding: CGFloat = 8
private let lapCardLeadingPadding: CGFloat = 8
private let lapCardBottomPadding: CGFloat = 8
private let lapCardTrailingPadding: CGFloat = 14
private let standardLapCardBackground = Color.white.opacity(0.15)

struct PlaceholderLapCardView: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("1")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
            Text("—:——")
                .font(.system(size: 19, design: .rounded))
                .monospacedDigit()
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.top, lapCardTopPadding)
        .padding(.leading, lapCardLeadingPadding)
        .padding(.bottom, lapCardBottomPadding)
        .padding(.trailing, lapCardTrailingPadding)
        .frame(height: latestCardHeight)
        .background(standardLapCardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .inset(by: 1.5)
                .stroke(Color.white.opacity(0.78), lineWidth: 3)
        )
    }
}

struct LapCardView: View {
    let lap: Lap
    let trackingMode: TrackingMode
    var distanceUnit: DistanceUnit = .km
    var isLatest: Bool = false

    private var showsDistance: Bool {
        lap.lapType != .rest && lap.distanceMeters > 0
    }

    private var isRest: Bool { lap.lapType == .rest }

    private var cardBackgroundColor: Color {
        if isRest {
            return Color.white.opacity(0.9)
        }

        return standardLapCardBackground
    }

    var body: some View {
        Group {
            if isRest {
                Text(Formatters.compactTimeString(from: lap.durationSeconds))
                    .font(.system(size: 19, design: .rounded))
                    .monospacedDigit()
            } else {
                HStack(spacing: 6) {
                    Text("\(lap.index)")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formatters.compactTimeString(from: lap.durationSeconds))
                            .font(.system(size: 19, design: .rounded))
                            .monospacedDigit()
                            .fontWeight(isLatest ? .bold : .regular)
                        if showsDistance {
                            HStack(spacing: 4) {
                                Text(Formatters.distanceString(meters: lap.distanceMeters, unit: distanceUnit))
                                    .font(.system(size: 18, design: .rounded))
                                    .monospacedDigit()

                                Text("•")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))

                                Text(Formatters.paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: distanceUnit))
                                    .font(.system(size: 18, design: .rounded))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(.secondary)
                        } else {
                            Text(Formatters.paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: distanceUnit))
                                .font(.system(size: 18, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.top, lapCardTopPadding)
        .padding(.leading, lapCardLeadingPadding)
        .padding(.bottom, lapCardBottomPadding)
        .padding(.trailing, lapCardTrailingPadding)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundColor(isRest ? .black : .white)
        .background(cardBackgroundColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .inset(by: isLatest && !isRest ? 1.5 : 0)
                .stroke(Color.white.opacity(0.78), lineWidth: isLatest && !isRest ? 3 : 0)
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
        case .km: return "Distance (m)"
        case .miles: return "Distance (ft)"
        }
    }

    private let defaultDistanceText = "400"

    var body: some View {
        ZStack {
            AppScreenBackground(accentColor: accentColor)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Edit Lap")
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
                        Text("This lap will be treated as rest.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 12)
                    }

                    Button(L10n.deleteLap, role: .destructive) {
                        didDelete = true
                        onDelete(currentState)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.red)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
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
        Button {
            lapType = type
            if type == .active && distanceText.isEmpty {
                distanceText = defaultDistanceText
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(lapType == type ? accentColor.opacity(0.2) : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            lapType == type ? accentColor.opacity(0.4) : Color.white.opacity(0.12),
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutControlIcon: View {
    let systemName: String
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
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 46, height: 46)
        .shadow(color: baseColor.opacity(0.28), radius: 6, y: 2)
    }
}
