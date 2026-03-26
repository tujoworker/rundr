import SwiftUI
import SwiftData

struct CompanionRootView: View {
    @EnvironmentObject private var syncManager: WatchConnectivitySyncManager
    @Query(sort: [SortDescriptor(\Session.startedAt, order: .reverse)]) private var sessions: [Session]

    private var visibleLiveWorkoutState: LiveWorkoutStateRecord? {
        guard let state = syncManager.liveWorkoutState,
              !state.isTerminalState,
              sessions.contains(where: { $0.id == state.sessionID }) == false else {
            return nil
        }

        return state
    }

    var body: some View {
        NavigationStack {
            List {
                if let liveWorkoutState = visibleLiveWorkoutState {
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
    @State private var now = Date()
    private let stalenessTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    /// Live state is stale if it hasn't been updated in 10 seconds
    /// and the workout isn't in a naturally static state.
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

    private var statusColor: Color {
        isStale ? .orange : .secondary
    }

    private var hasGPSDistance: Bool {
        state.cumulativeGPSDistanceMeters != nil
    }

    private var primaryDistanceLabel: String {
        if state.trackingMode.usesManualIntervals {
            return L10n.manualDistance
        }

        if hasGPSDistance {
            return L10n.gpsDistanceLabel
        }

        return "Distance"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Formatters.historySessionDateTimeString(from: state.startedAt))
                .font(.headline)

            HStack {
                Label(Formatters.timeString(from: state.elapsedSeconds), systemImage: "timer")
                Spacer()
                Text(statusLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Laps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(state.completedLapCount)")
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(primaryDistanceLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Formatters.distanceString(meters: state.cumulativeDistanceMeters, unit: .km))
                            .font(.title3.weight(.semibold))
                    }

                    if let gpsDistanceMeters = state.cumulativeGPSDistanceMeters {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(L10n.gpsDistanceLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Formatters.distanceString(meters: gpsDistanceMeters, unit: .km))
                                .font(.title3.weight(.semibold))
                        }
                    }
                }
            }

            if let heartRate = state.currentHeartRate {
                Text("Heart Rate \(Int(heartRate)) bpm")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .onReceive(stalenessTimer) { now = $0 }
        .onAppear { now = Date() }
    }
}

private struct CompanionSessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(Formatters.historySessionDateTimeString(from: session.startedAt))
                    .font(.headline)

                Spacer(minLength: 8)

                if session.isImportedFromWatch {
                    CompanionImportBadge(title: L10n.fromAppleWatch)
                }
            }

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
            Section {
                CompanionImportStatusCard(session: session)
            }

            Section("Summary") {
                LabeledContent("Started", value: Formatters.historySessionDateTimeString(from: session.startedAt))
                LabeledContent("Ended", value: Formatters.historySessionDateTimeString(from: session.endedAt))
                LabeledContent(L10n.source, value: session.companionSourceDisplayName)
                LabeledContent(L10n.importStatus, value: L10n.importComplete)
                LabeledContent(L10n.mode, value: session.mode.displayName)
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

private struct CompanionImportBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.12))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.blue.opacity(0.28), lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
    }
}

private struct CompanionImportStatusCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(L10n.importedSession)
                    .font(.headline)

                if session.isImportedFromWatch {
                    CompanionImportBadge(title: L10n.fromAppleWatch)
                }
            }

            Text(L10n.importedFromSource(session.companionSourceDisplayName))
                .font(.subheadline.weight(.semibold))

            Text(L10n.importedSessionSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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