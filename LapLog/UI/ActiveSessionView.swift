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

    private var primaryColor: Color {
        settings.primaryAccentColor
    }

    private var isPaused: Bool {
        workoutController.runState == .rest
    }

    private var deleteLapDialogTitle: String {
        guard let lap = lapToDelete.flatMap({ id in workoutController.completedLaps.first { $0.id == id } }) else {
            return "Delete Lap"
        }
        return "Lap \(lap.index)"
    }

    private var timerTopLabel: String {
        if isPaused {
            return "Pause Mode"
        }
        if workoutController.trackingMode == .distanceDistance {
            return Formatters.distanceString(meters: settings.distanceDistanceMeters, unit: settings.distanceUnit)
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
            .font(.system(size: timerFontSize, weight: .medium, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.45)
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, timerInnerHorizontalPadding)
            .padding(.vertical, timerVerticalPadding)
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
            .padding(.horizontal, timerHorizontalMargin)
            .contentShape(Capsule())
            .onTapGesture { handleLapTap() }
    }

    private let topHeaderHeight: CGFloat = 56

    /// Smaller watches: less right padding, same as timer.
    private var lapHistoryContainerTrailingPadding: CGFloat {
        let w = WKInterfaceDevice.current().screenBounds.width
        if w < 177 { return 4 }
        if w < 200 { return 6 }
        if w < 220 { return 8 }
        return 12
    }

    private var lapCardsContentTrailingPadding: CGFloat {
        let w = WKInterfaceDevice.current().screenBounds.width
        if w < 177 { return 4 }
        if w < 220 { return 6 }
        return 8
    }

    /// Smaller watches: timer moves up more to fit. 49mm: 4px extra up. All +2px up.
    private var timerVerticalOffset: CGFloat {
        let bounds = WKInterfaceDevice.current().screenBounds
        let w = bounds.width
        let h = bounds.height
        var base: CGFloat
        if h < 230 { base = -11 }
        else if h < 251 { base = -8 }
        else { base = -5 }
        if w >= 200 && w <= 215 && h >= 248 && h <= 255 { base -= 4 }  // 49mm
        return base
    }

    /// Smaller watches: negative margin so timer extends to screen edges.
    private var timerHorizontalMargin: CGFloat {
        let w = WKInterfaceDevice.current().screenBounds.width
        if w < 177 { return -2 }
        if w < 200 { return 0 }
        if w < 220 { return 0 }
        return 0
    }

    /// Smallest screens: heart rate 2px more up.
    private var heartRateVerticalOffset: CGFloat {
        WKInterfaceDevice.current().screenBounds.width < 177 ? -10 : -8
    }

    /// 42mm: header moves down 2px. 44mm: 14px up. 46mm: 12px up. 49mm: 22px up.
    /// 187×223 variant: apply 8 (same as 42mm).
    private var headerVerticalOffset: CGFloat {
        let bounds = WKInterfaceDevice.current().screenBounds
        let w = bounds.width
        let h = bounds.height
        if h >= 249 { return -16 }  // 49mm
        if w >= 205 && w <= 212 && h >= 245 && h <= 252 { return -12 }  // 46mm
        if w >= 182 && w <= 192 && h >= 220 && h <= 230 { return -17 }  // 44mm (184×224, 187×223)
        if (w >= 158 && w <= 168 && h >= 194 && h <= 202) || (w >= 318 && w <= 328 && h >= 390 && h <= 405) { return -4 }  // 40mm (162×197)
        if (w >= 152 && w <= 161) || (w >= 308 && w <= 318) { return 8 }  // 42mm
        return 8
    }

    /// Smaller watches: top buttons (pause) way more to the left.
    private var headerHorizontalPadding: CGFloat {
        let w = WKInterfaceDevice.current().screenBounds.width
        if w < 177 { return 0 }
        if w < 195 { return 2 }
        if w < 210 { return 6 }
        return 14
    }

    /// 46mm, 49mm: lap cards move down 4px.
    private var lapCardsVerticalOffset: CGFloat {
        let h = WKInterfaceDevice.current().screenBounds.height
        return h >= 245 ? 4 : 0
    }

    /// Top buttons move right on smaller/larger watches for better alignment.
    private var headerLeadingExtra: CGFloat {
        let w = WKInterfaceDevice.current().screenBounds.width
        let h = WKInterfaceDevice.current().screenBounds.height
        if w >= 202 && w <= 212 && h >= 245 && h <= 255 { return 12 }  // 46mm, 49mm
        if (w >= 152 && w <= 161) || (w >= 184 && w <= 190 && h >= 220 && h <= 226) { return 6 }  // 42mm, 44mm
        return 0
    }


    /// Timer font: larger overall, even larger on 46mm.
    private var timerFontSize: CGFloat {
        let bounds = WKInterfaceDevice.current().screenBounds
        let w = bounds.width
        let h = bounds.height
        if w >= 205 && w <= 212 && h >= 245 && h <= 252 { return 92 }  // 46mm
        if w >= 200 && w <= 215 && h >= 248 && h <= 255 { return 90 }  // 49mm
        if h >= 220 && h <= 230 { return 86 }   // 44mm
        if h < 230 { return 82 }   // 42mm, 40mm
        return 84
    }

    /// Smaller capsule: less inner padding.
    private var timerInnerHorizontalPadding: CGFloat {
        let w = WKInterfaceDevice.current().screenBounds.width
        if w < 200 { return 4 }
        if w < 215 { return 6 }
        if w < 230 { return 8 }
        return 10
    }

    /// Smaller capsule: less vertical padding (reduced to keep height same with larger font).
    private var timerVerticalPadding: CGFloat {
        let h = WKInterfaceDevice.current().screenBounds.height
        if h < 230 { return 6 }
        if h < 251 { return 10 }
        return 12
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    Group {
                        if isPaused {
                            sessionMenuButton
                        } else {
                            pauseButton
                        }
                    }
                    .offset(x: headerLeadingExtra)

                    Spacer()

                    HStack(spacing: 4) {
                        Text(Formatters.heartRateString(bpm: workoutController.currentHeartRate))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .offset(y: heartRateVerticalOffset)

                    Spacer()

                    Color.clear
                        .frame(width: 48, height: 48)
                }
                .padding(.horizontal, headerHorizontalPadding)
                .frame(height: topHeaderHeight)
                .offset(y: -12 + headerVerticalOffset)
                .padding(.bottom, 12)

                sessionTimerView
                    .offset(y: timerVerticalOffset)

                Color.clear
                    .frame(height: 6)
                    .contentShape(Rectangle())
                    .onTapGesture { handleLapTap() }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if workoutController.completedLaps.isEmpty {
                                PlaceholderLapCardView(
                                    trackingMode: workoutController.trackingMode,
                                    distanceUnit: settings.distanceUnit,
                                    lapElapsedSeconds: workoutController.lapElapsedSeconds,
                                    currentLapDistanceMeters: workoutController.currentLapDistanceMeters,
                                    targetDistanceMeters: workoutController.trackingMode == .distanceDistance ? settings.distanceDistanceMeters : nil
                                )
                                    .offset(x: -8)
                            } else {
                                ForEach(workoutController.completedLaps, id: \.id) { lap in
                                    LapCardView(lap: lap, trackingMode: workoutController.trackingMode, distanceUnit: settings.distanceUnit, isLatest: lap.id == workoutController.completedLaps.last?.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            lapToDelete = lap.id
                                            isDeleteLapDialogPresented = true
                                        }
                                        .id(lap.id)
                                }
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, lapCardsContentTrailingPadding)
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
                .offset(y: -10 + lapCardsVerticalOffset)

                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
            }
            .allowsHitTesting(false)
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
        .confirmationDialog(deleteLapDialogTitle, isPresented: $isDeleteLapDialogPresented, titleVisibility: .visible) {
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
            if let lap = lapToDelete.flatMap({ id in workoutController.completedLaps.first { $0.id == id } }) {
                Text(Formatters.lapSummaryString(lap: lap, trackingMode: workoutController.trackingMode, unit: settings.distanceUnit))
            }
        }
        .tint(primaryColor)
        .onAppear {
            lastAnimatedLapCount = workoutController.completedLaps.count
            #if DEBUG
            let b = WKInterfaceDevice.current().screenBounds
            print("[LapLog] Screen: \(b.width)×\(b.height) headerLeadingExtra=\(headerLeadingExtra) headerVerticalOffset=\(headerVerticalOffset)")
            #endif
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
    let trackingMode: TrackingMode
    let distanceUnit: DistanceUnit
    let lapElapsedSeconds: Double
    let currentLapDistanceMeters: Double
    var targetDistanceMeters: Double? = nil

    private var secondLine: String {
        if trackingMode == .distanceDistance {
            return "— \(distanceUnit == .km ? "/km" : "/mi")"
        }
        // GPS: distance • pace
        let distStr = Formatters.distanceString(meters: currentLapDistanceMeters, unit: distanceUnit)
        let paceStr = Formatters.paceString(distanceMeters: currentLapDistanceMeters, durationSeconds: lapElapsedSeconds, unit: distanceUnit)
        if currentLapDistanceMeters > 0 && lapElapsedSeconds > 0 {
            return "\(distStr) • \(paceStr)"
        }
        if currentLapDistanceMeters > 0 {
            return distStr
        }
        return ""
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("1")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Active")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if !secondLine.isEmpty {
                    Text(secondLine)
                        .font(.system(size: 18, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.88))
                } else {
                    Text(" ")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
        .padding(.top, lapCardTopPadding)
        .padding(.leading, lapCardLeadingPadding)
        .padding(.bottom, lapCardBottomPadding)
        .padding(.trailing, lapCardTrailingPadding)
        .fixedSize(horizontal: true, vertical: false)
        .background(standardLapCardBackground)
        .cornerRadius(14)
    }
}

struct LapCardView: View {
    let lap: Lap
    let trackingMode: TrackingMode
    var distanceUnit: DistanceUnit = .km
    var isLatest: Bool = false

    private var showsDistance: Bool {
        lap.lapType != .rest && trackingMode == .gps
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
                            .foregroundStyle(.white.opacity(0.88))
                        } else {
                            Text(Formatters.paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: distanceUnit))
                                .font(.system(size: 18, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.88))
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
