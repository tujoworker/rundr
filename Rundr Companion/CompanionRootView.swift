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
                    Section(L10n.liveOnAppleWatch) {
                        CompanionLiveWorkoutCard(state: liveWorkoutState)
                    }
                }

                Section(L10n.syncedSessions) {
                    if sessions.isEmpty {
                        Text(L10n.noSyncedSessionsYet)
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
            .navigationTitle("Rundr")
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

    private var isOpenActivity: Bool {
        state.trackingMode.usesManualIntervals && state.currentTargetDistanceMeters == nil
    }

    private var hasGPSDistance: Bool {
        state.cumulativeGPSDistanceMeters != nil
    }

    private var primaryDistanceLabel: String {
        if isOpenActivity {
            return hasGPSDistance ? L10n.gpsDistanceLabel : L10n.distance
        }

        if state.trackingMode.usesManualIntervals {
            return L10n.manualDistance
        }

        if hasGPSDistance {
            return L10n.gpsDistanceLabel
        }

        return L10n.distance
    }

    private var primaryDistanceMeters: Double {
        if isOpenActivity, let gps = state.cumulativeGPSDistanceMeters {
            return gps
        }
        return state.cumulativeDistanceMeters
    }

    /// Show a separate GPS row when it adds info beyond the primary distance.
    private var showsSecondaryGPSDistance: Bool {
        guard let _ = state.cumulativeGPSDistanceMeters else { return false }
        return !isOpenActivity
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
                    Text(L10n.laps)
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
                        Text(Formatters.distanceString(meters: primaryDistanceMeters, unit: .km))
                            .font(.title3.weight(.semibold))
                    }

                    if showsSecondaryGPSDistance, let gpsDistanceMeters = state.cumulativeGPSDistanceMeters {
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
                Text(L10n.heartRateBPM(Int(heartRate)))
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

            Text(L10n.lapsSummary(session.activeLapCount, Formatters.speedString(metersPerSecond: session.averageSpeedMetersPerSecond)))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(L10n.timeSummary(Formatters.timeString(from: session.activeDurationSeconds), Formatters.distanceString(meters: session.totalDistanceMeters, unit: .km)))
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

            Section(L10n.summary) {
                LabeledContent(L10n.started, value: Formatters.historySessionDateTimeString(from: session.startedAt))
                LabeledContent(L10n.ended, value: Formatters.historySessionDateTimeString(from: session.endedAt))
                LabeledContent(L10n.source, value: session.companionSourceDisplayName)
                LabeledContent(L10n.importStatus, value: L10n.importComplete)
                LabeledContent(L10n.mode, value: session.mode.displayName)
                LabeledContent(L10n.time, value: Formatters.timeString(from: session.activeDurationSeconds))
                LabeledContent(L10n.distance, value: Formatters.distanceString(meters: session.totalDistanceMeters, unit: .km))
                if let gpsDistance = session.totalGPSDistanceMeters {
                    LabeledContent(L10n.gpsDistanceLabel, value: Formatters.distanceString(meters: gpsDistance, unit: .km))
                }
            }

            Section(L10n.laps) {
                ForEach(sortedLaps, id: \.id) { lap in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lap.lapType == .rest ? L10n.rest : L10n.lapIndex(lap.index))
                            .font(.headline)
                        Text(Formatters.lapSummaryString(lap: lap, trackingMode: session.mode, unit: .km))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let heartRate = lap.averageHeartRateBPM {
                            Text(L10n.heartRateBPM(Int(heartRate)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(L10n.session)
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
            return L10n.runStateIdle
        case .ready:
            return L10n.runStateReady
        case .active:
            return L10n.runStateActive
        case .rest:
            return L10n.runStateRest
        case .paused:
            return L10n.runStatePaused
        case .ending:
            return L10n.runStateEnding
        case .ended:
            return L10n.runStateEnded
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