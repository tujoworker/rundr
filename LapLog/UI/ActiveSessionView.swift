import SwiftUI
import WatchKit

struct ActiveSessionView: View {
    @EnvironmentObject var workoutController: WorkoutSessionController
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var settings: SettingsStore

    var onSessionEnded: () -> Void

    private enum EndState {
        case none
        case xShown
    }

    @State private var endState: EndState = .none
    @State private var isTapFlashVisible = false
    @State private var isSessionMenuPresented = false
    @State private var isTimerBounceActive = false
    @State private var lastAnimatedLapCount = 0

    private var primaryColor: Color {
        settings.primaryAccentColor
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                leftControlButton

                Spacer(minLength: 10)

                Text(Date(), style: .time)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleLapTap()
                }

                Spacer(minLength: 10)

                pauseButton
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 24)

            Text(Formatters.precisionTimeString(from: workoutController.lapElapsedSeconds))
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isTimerBounceActive ? primaryColor : Color.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(primaryColor, lineWidth: 5)
                )
                .scaleEffect(isTimerBounceActive ? 1.05 : 1)
                .shadow(color: primaryColor.opacity(isTimerBounceActive ? 0.45 : 0), radius: 10)
                .padding(.horizontal, 14)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture {
                    handleLapTap()
                }

            Color.clear
                .frame(maxWidth: .infinity, minHeight: 8, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleLapTap()
                }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        if workoutController.completedLaps.isEmpty {
                            PlaceholderLapCardView()
                        }
                        ForEach(workoutController.completedLaps, id: \.id) { lap in
                            LapCardView(lap: lap, trackingMode: workoutController.trackingMode, distanceUnit: settings.distanceUnit, isLatest: lap.id == workoutController.completedLaps.last?.id)
                                .id(lap.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(minWidth: WKInterfaceDevice.current().screenBounds.width)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        handleLapTap()
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
            .padding(.bottom, 10)

            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleLapTap()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            Color.white
                .opacity(isTapFlashVisible ? 0.22 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .confirmationDialog("Session", isPresented: $isSessionMenuPresented) {
            Button("End Session", role: .destructive) {
                Task { await endSession() }
            }
            Button("Cancel", role: .cancel) {}
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
        endState = .none
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
        withAnimation(.spring(response: 0.18, dampingFraction: 0.58)) {
            isTimerBounceActive = true
        }

        Task {
            try? await Task.sleep(for: .milliseconds(220))
            await MainActor.run {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    isTimerBounceActive = false
                }
            }
        }
    }

    @ViewBuilder
    private var leftControlButton: some View {
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

    @ViewBuilder
    private var pauseButton: some View {
        switch endState {
        case .xShown:
            Button {
                workoutController.cancelRest()
                endState = .none
            } label: {
                WorkoutControlIcon(
                    systemName: "xmark",
                    baseColor: primaryColor
                )
            }
            .buttonStyle(.plain)
        case .none:
            Button {
                workoutController.startRest()
                endState = .xShown
            } label: {
                WorkoutControlIcon(
                    systemName: "pause.fill",
                    baseColor: primaryColor
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private let latestCardHeight: CGFloat = 54

struct PlaceholderLapCardView: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("1")
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(.gray)
            Text("—:——")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.gray)
        }
        .padding(8)
        .frame(height: latestCardHeight)
        .background(Color.white.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 1.5)
        )
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

    var body: some View {
        Group {
            if isRest {
                Text(Formatters.compactTimeString(from: lap.durationSeconds))
                    .font(.system(.caption, design: .monospaced))
            } else {
                HStack(spacing: 6) {
                    Text("\(lap.index)")
                        .font(.system(.caption, design: .monospaced).bold())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formatters.compactTimeString(from: lap.durationSeconds))
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(isLatest ? .bold : .regular)
                        Text(Formatters.paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: distanceUnit))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(6)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundColor(isRest ? .black : .white)
        .background(isRest ? Color.white.opacity(0.9) : Color.white.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: isLatest && !isRest ? 1.5 : 0)
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
