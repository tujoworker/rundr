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
    @State private var isTimerBounceActive = false
    @State private var isTimerGlowActive = false
    @State private var isLapHistoryDragging = false
    @State private var lastAnimatedLapCount = 0
    @State private var lapToDelete: UUID?
    @State private var isDeleteLapDialogPresented = false
    @State private var lapToEdit: UUID?
    @State private var isLapEditDialogPresented = false
    @State private var isManualDistanceEntryPresented = false
    @State private var manualDistanceText: String = ""
    @State private var isRestPulseOn = false

    private var primaryColor: Color {
        settings.primaryAccentColor
    }

    private var isPaused: Bool {
        workoutController.runState == .rest
    }

    private var timerTopLabel: String {
        if isPaused {
            if let elapsed = workoutController.restElapsedSeconds {
                return "Rest \(elapsed)s"
            }
            return "Pause Mode"
        }
        if workoutController.trackingMode == .distanceDistance {
            return Formatters.distanceString(meters: workoutController.currentTargetDistanceMeters, unit: settings.distanceUnit)
        }
        return ""
    }

    private var pauseBorderOverlay: some View {
        Capsule()
            .stroke(Color.black.opacity(0.42), lineWidth: 8)
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
            .font(.system(size: 90, weight: .medium, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.45)
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(Capsule().fill(primaryColor))
            .overlay(pauseBorderOverlay)
            .overlay(lapGlowOverlay)
            .overlay(alignment: .top) {
                Text(timerTopLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .opacity(timerTopLabel.isEmpty ? 0 : 1)
                    .offset(y: -19)
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
    private let menuButtonExtraOffset: CGFloat = -4
    private let pauseButtonExtraOffset: CGFloat = -4
    private let lapHistoryContainerTrailingPadding: CGFloat = 12

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    HStack(alignment: .top) {
                        if isPaused {
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
                                            lapToEdit = lap.id
                                            isLapEditDialogPresented = true
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
        .background(AppScreenBackground(accentColor: primaryColor))
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

                Color.white
                    .opacity(isRestPulseOn ? 0.18 : 0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRestPulseOn)
            }
            .allowsHitTesting(false)
        }
        .onChange(of: workoutController.isRestWarningActive) { _, active in
            isRestPulseOn = active
        }
        .confirmationDialog("", isPresented: $isSessionMenuPresented, titleVisibility: .hidden) {
            if isPaused {
                Button("Cancel Pause") {
                    workoutController.cancelRest()
                }
            }
            Button("End Session", role: .destructive) {
                Task { await endSession() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete Lap", isPresented: $isDeleteLapDialogPresented, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = lapToDelete {
                    workoutController.deleteLap(id: id)
                }
                lapToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                lapToDelete = nil
            }
        } message: {
            Text("Remove this lap from the session?")
        }
        .confirmationDialog("Lap Distance", isPresented: $isLapEditDialogPresented, titleVisibility: .visible) {
            ForEach(workoutController.availableDistances, id: \.self) { dist in
                Button(Formatters.distanceString(meters: dist, unit: settings.distanceUnit)) {
                    if let id = lapToEdit {
                        workoutController.changeLapDistance(id: id, newDistanceMeters: dist)
                    }
                    lapToEdit = nil
                }
            }
            Button("Enter Distance…") {
                manualDistanceText = ""
                isManualDistanceEntryPresented = true
            }
            Button("Delete Lap", role: .destructive) {
                if let id = lapToEdit {
                    workoutController.deleteLap(id: id)
                }
                lapToEdit = nil
            }
            Button("Cancel", role: .cancel) {
                lapToEdit = nil
            }
        }
        .sheet(isPresented: $isManualDistanceEntryPresented) {
            ManualDistanceEntrySheet(
                distanceText: $manualDistanceText,
                distanceUnit: settings.distanceUnit,
                onDone: {
                    if let id = lapToEdit {
                        let value = Double(manualDistanceText) ?? 0
                        if value > 0 {
                            let meters: Double
                            switch settings.distanceUnit {
                            case .km: meters = value
                            case .miles: meters = value / 3.28084
                            }
                            workoutController.changeLapDistance(id: id, newDistanceMeters: meters)
                        }
                    }
                    lapToEdit = nil
                    isManualDistanceEntryPresented = false
                }
            )
        }
        .tint(primaryColor)
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
        flashTapBorder()
        workoutController.markLap()
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
            guard !isPaused else { return }
            workoutController.startRest()
        } label: {
            WorkoutControlIcon(
                systemName: "pause.fill",
                baseColor: primaryColor
            )
        }
        .buttonStyle(.plain)
        .opacity(isPaused ? 0.72 : 1)
    }
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

private struct ManualDistanceEntrySheet: View {
    @Binding var distanceText: String
    let distanceUnit: DistanceUnit
    let onDone: () -> Void

    private var label: String {
        switch distanceUnit {
        case .km: return "Distance (m)"
        case .miles: return "Distance (ft)"
        }
    }

    private var placeholder: String {
        switch distanceUnit {
        case .km: return "e.g. 400"
        case .miles: return "e.g. 1320"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 4)

                TextField(placeholder, text: $distanceText)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )

                Button("Done") {
                    onDone()
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                )
                .foregroundStyle(.white)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }
}

private struct WorkoutControlIcon: View {
    let systemName: String
    let baseColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [baseColor.opacity(0.98), baseColor.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 3)
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
