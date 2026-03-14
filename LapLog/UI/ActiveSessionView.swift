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
        case confirmShown
    }

    @State private var endState: EndState = .none

    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(currentTime)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)

            HStack {
                switch endState {
                case .confirmShown:
                    Button {
                        Task { await endSession() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                            Text("Confirm End")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                case .xShown:
                    Button {
                        workoutController.commitFinalLap()
                        endState = .confirmShown
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                case .none:
                    Button {
                        workoutController.startRest()
                        endState = .xShown
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption2)
                    Text(Formatters.heartRateString(bpm: workoutController.currentHeartRate))
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            // Large timer
            Text(Formatters.precisionTimeString(from: workoutController.lapElapsedSeconds))
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)

            Spacer()

            // Horizontal scrolling lap cards – fixed height to avoid layout shift
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
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
                .onChange(of: workoutController.completedLaps.count) {
                    if let lastLap = workoutController.completedLaps.last {
                        withAnimation {
                            proxy.scrollTo(lastLap.id, anchor: .trailing)
                        }
                    }
                }
            }
            .frame(height: 60)
            .padding(.bottom, 8)

            // Lap button (always visible)
            Button(action: {
                workoutController.markLap()
                endState = .none
            }) {
                Text(endState != .none ? "Resume" : "Lap")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundColor(.black)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
    }

    private func endSession() async {
        let session = await workoutController.endSession()
        if let session {
            persistence.saveSession(session)
            Task {
                do {
                    let uuid = try await healthKitManager.saveWorkout(session: session)
                    await MainActor.run {
                        session.healthKitWorkoutUUID = uuid
                        try? persistence.modelContext.save()
                    }
                } catch {
                    print("HealthKit export failed: \(error)")
                }
            }
        }
        onSessionEnded()
    }
}

struct PlaceholderLapCardView: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("1")
                .font(.system(.body, design: .monospaced).bold())
            VStack(alignment: .leading, spacing: 2) {
                Text("Go!")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                Text(" ")
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .padding(8)
        .foregroundColor(.white)
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
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                HStack(spacing: 6) {
                    Text("\(lap.index)")
                        .font(.system(isLatest ? .body : .caption, design: .monospaced).bold())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formatters.compactTimeString(from: lap.durationSeconds))
                            .font(.system(isLatest ? .body : .caption, design: .monospaced))
                            .fontWeight(isLatest ? .bold : .regular)
                        Text(Formatters.paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: distanceUnit))
                            .font(.system(isLatest ? .caption : .caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(isLatest && !isRest ? 8 : 6)
        .frame(minHeight: isLatest && !isRest ? nil : 40)
        .foregroundColor(lap.lapType == .rest ? .black : .white)
        .background(lap.lapType == .rest ? Color.white.opacity(0.9) : Color.white.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: isLatest && !isRest ? 1.5 : 0)
        )
    }
}
