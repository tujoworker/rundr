import SwiftUI
import SwiftData

struct CompanionRootView: View {
    @EnvironmentObject private var syncManager: WatchConnectivitySyncManager
    @Query(sort: [SortDescriptor(\Session.startedAt, order: .reverse)]) private var sessions: [Session]

    var body: some View {
        NavigationStack {
            List {
                if let liveWorkoutState = syncManager.liveWorkoutState {
                    Section("Live on Apple Watch") {
                        CompanionLiveWorkoutCard(state: liveWorkoutState)
                    }
                }

                Section("Synced Sessions") {
                    if sessions.isEmpty {
                        Text("No synced sessions yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sessions, id: \.id) { session in
                            NavigationLink {
                                CompanionSessionDetailView(session: session)
                            } label: {
                                CompanionSessionRow(session: session)
                            }
                        }
                    }
                }
            }
            .navigationTitle("LapLog")
        }
    }
}

private struct CompanionLiveWorkoutCard: View {
    let state: LiveWorkoutStateRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Formatters.historySessionDateTimeString(from: state.startedAt))
                .font(.headline)

            HStack {
                Label(Formatters.timeString(from: state.elapsedSeconds), systemImage: "timer")
                Spacer()
                Text(state.runStateLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Laps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(state.completedLapCount)")
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.distanceString(meters: state.cumulativeDistanceMeters, unit: .km))
                        .font(.title3.weight(.semibold))
                }
            }

            if let heartRate = state.currentHeartRate {
                Text("Heart Rate \(Int(heartRate)) bpm")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CompanionSessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Formatters.historySessionDateTimeString(from: session.startedAt))
                .font(.headline)

            Text("Laps: \(session.totalLaps) • Avg: \(Formatters.speedString(metersPerSecond: session.averageSpeedMetersPerSecond))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Time: \(Formatters.timeString(from: session.durationSeconds)) • Dist: \(Formatters.distanceString(meters: session.totalDistanceMeters, unit: .km))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct CompanionSessionDetailView: View {
    let session: Session

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Started", value: Formatters.historySessionDateTimeString(from: session.startedAt))
                LabeledContent("Ended", value: Formatters.historySessionDateTimeString(from: session.endedAt))
                LabeledContent("Mode", value: session.mode.displayName)
                LabeledContent("Time", value: Formatters.timeString(from: session.durationSeconds))
                LabeledContent("Distance", value: Formatters.distanceString(meters: session.totalDistanceMeters, unit: .km))
                if let gpsDistance = session.totalGPSDistanceMeters {
                    LabeledContent("GPS Distance", value: Formatters.distanceString(meters: gpsDistance, unit: .km))
                }
            }

            Section("Laps") {
                ForEach(sortedLaps, id: \.id) { lap in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lap.lapType == .rest ? "Rest" : "Lap \(lap.index)")
                            .font(.headline)
                        Text(Formatters.lapSummaryString(lap: lap, trackingMode: session.mode, unit: .km))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let heartRate = lap.averageHeartRateBPM {
                            Text("Heart Rate \(Int(heartRate)) bpm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Session")
    }
}

private extension LiveWorkoutStateRecord {
    var runStateLabel: String {
        switch runState {
        case .idle:
            return "Idle"
        case .ready:
            return "Ready"
        case .active:
            return "Active"
        case .rest:
            return "Rest"
        case .paused:
            return "Paused"
        case .ending:
            return "Ending"
        case .ended:
            return "Ended"
        }
    }
}