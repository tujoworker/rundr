import SwiftUI
import WatchKit

struct ActiveSessionView: View {
    @EnvironmentObject var workoutController: WorkoutSessionController
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var healthKitManager: HealthKitManager

    var onSessionEnded: () -> Void

    @State private var restPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: Rest/End on left, HR on right
            HStack {
                if restPressed {
                    Button {
                        Task { await endSession() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        workoutController.startRest()
                        restPressed = true
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
            Text(Formatters.timeString(from: workoutController.lapElapsedSeconds))
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.vertical, 6)

            Spacer()

            // Lap button (always visible)
            Button(action: {
                workoutController.markLap()
                restPressed = false
            }) {
                Text("Lap")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // Horizontal scrolling lap cards (below Lap button)
            if !workoutController.completedLaps.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(workoutController.completedLaps, id: \.id) { lap in
                                LapCardView(lap: lap)
                                    .id(lap.id)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 60)
                    .onChange(of: workoutController.completedLaps.count) {
                        if let lastLap = workoutController.completedLaps.last {
                            withAnimation {
                                proxy.scrollTo(lastLap.id, anchor: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private func endSession() async {
        if let session = await workoutController.endSession() {
            persistence.saveSession(session)
            // Attempt HealthKit export
            Task {
                do {
                    let uuid = try await healthKitManager.saveWorkout(session: session)
                    session.healthKitWorkoutUUID = uuid
                    try? persistence.modelContext.save()
                } catch {
                    print("HealthKit export failed: \(error)")
                }
            }
        }
        onSessionEnded()
    }
}

struct LapCardView: View {
    let lap: Lap

    var body: some View {
        VStack(spacing: 2) {
            Text("Lap \(lap.index)")
                .font(.system(.caption2, design: .monospaced).bold())
            Text(Formatters.timeString(from: lap.durationSeconds))
                .font(.system(.caption2, design: .monospaced))
            if lap.lapType != .rest {
                Text(Formatters.distanceString(meters: lap.distanceMeters))
                    .font(.system(.caption2, design: .monospaced))
            }
        }
        .padding(6)
        .background(lap.lapType == .rest ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
        .cornerRadius(8)
    }
}
