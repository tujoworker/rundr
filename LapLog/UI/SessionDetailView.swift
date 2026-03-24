import SwiftUI

struct SessionDetailView: View {
    let session: Session
    let onUseSessionSettings: () -> Void
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var syncManager: WatchConnectivitySyncManager
    @Environment(\.dismiss) private var dismiss

    @State private var showConfirmedPhoneSyncMessage = false

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.startedAt < $1.startedAt }
    }

    private var headerTitle: String {
        Formatters.historySessionDateRangeString(start: session.startedAt, end: session.endedAt)
    }

    private var isPendingPhoneSync: Bool {
        syncManager.hasPendingCompletedSessionTransfer(for: session.id)
    }

    private var sessionStats: [SessionStatItem] {
        let modeValue = session.mode == .distanceDistance ? L10n.manualLabel : session.mode.displayName
        var items: [SessionStatItem] = [
            SessionStatItem(label: L10n.mode, value: modeValue),
            SessionStatItem(label: L10n.time, value: Formatters.timeString(from: session.durationSeconds)),
            SessionStatItem(label: L10n.laps, value: String(session.totalLaps))
        ]

        if session.mode.usesManualIntervals {
            items.append(
                SessionStatItem(
                    label: L10n.distance,
                    value: session.totalDistanceMeters > 0
                        ? Formatters.distanceString(meters: session.totalDistanceMeters, unit: settings.distanceUnit)
                        : L10n.dash
                )
            )
        } else if session.mode == .gps {
            items.append(
                SessionStatItem(
                    label: L10n.gpsDistanceLabel,
                    value: session.totalDistanceMeters > 0
                        ? Formatters.distanceString(meters: session.totalDistanceMeters, unit: settings.distanceUnit)
                        : L10n.dash
                )
            )
        }

        if session.mode == .dual {
            items.append(
                SessionStatItem(
                    label: L10n.gpsDistanceLabel,
                    value: session.totalGPSDistanceMeters.flatMap { gpsDistanceMeters in
                        gpsDistanceMeters > 0
                            ? Formatters.distanceString(meters: gpsDistanceMeters, unit: settings.distanceUnit)
                            : nil
                    } ?? L10n.dash
                )
            )
        }

        return items
    }

    private var targetSegmentsByLapID: [UUID: DistanceSegment] {
        SessionLapTargetResolver.targetSegments(
            for: sortedLaps,
            workoutPlan: session.snapshotWorkoutPlan,
            trackingMode: session.mode
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(headerTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !isPendingPhoneSync {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showConfirmedPhoneSyncMessage.toggle()
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(
                                    Circle()
                                        .fill(Color.green.opacity(0.88))
                                )
                                .accessibilityLabel(L10n.phoneSyncConfirmedTitle)
                                .padding(6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)

                if isPendingPhoneSync {
                    SessionDetailPendingPhoneSyncBanner()
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                } else if showConfirmedPhoneSyncMessage {
                    SessionDetailConfirmedPhoneSyncBanner()
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                SessionStatsView(items: sessionStats)

                ForEach(sortedLaps, id: \.id) { lap in
                    LapRowView(
                        lap: lap,
                        trackingMode: session.mode,
                        distanceUnit: settings.distanceUnit,
                        targetSegment: targetSegmentsByLapID[lap.id]
                    )
                }

                Button(action: onUseSessionSettings) {
                    Text(L10n.useSessionSettings)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
                .padding(.horizontal, 4)

                Button(String(localized: "Delete Session", comment: "Button to delete a saved session"), role: .destructive) {
                    persistence.deleteSession(session)
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 4)
        }
        .background(Color.clear)
    }
}

private struct SessionDetailPendingPhoneSyncBanner: View {
    private let tint = Color.orange

    var body: some View {
        SessionDetailPhoneSyncMessageBanner(
            title: L10n.phoneSyncPendingTitle,
            subtitle: L10n.phoneSyncPendingSubtitle,
            tint: tint
        )
    }
}

private struct SessionDetailConfirmedPhoneSyncBanner: View {
    private let tint = Color.green

    var body: some View {
        SessionDetailPhoneSyncMessageBanner(
            title: L10n.phoneSyncConfirmedTitle,
            subtitle: L10n.phoneSyncConfirmedSubtitle,
            tint: tint
        )
    }
}

private struct SessionDetailPhoneSyncMessageBanner: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)

            Text(subtitle)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(tint.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.32), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

private struct SessionStatsView: View {
    let items: [SessionStatItem]

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
        GridItem(.flexible(), spacing: 12, alignment: .topLeading)
    ]

    var body: some View {
        if !items.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))

                        Text(item.value)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.white.opacity(0.12))
            .cornerRadius(8)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
    }
}

struct LapRowView: View {
    let lap: Lap
    let trackingMode: TrackingMode
    var distanceUnit: DistanceUnit = .km
    var targetSegment: DistanceSegment? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
        GridItem(.flexible(), spacing: 12, alignment: .topLeading)
    ]

    private var badgeTitle: String {
        String(lap.index)
    }

    private var headerItems: [String] {
        [Formatters.compactTimeString(from: lap.durationSeconds)]
    }

    private var detailItems: [SessionStatItem] {
        var items: [SessionStatItem] = []

        guard lap.lapType != .rest else { return items }

        if trackingMode.usesManualIntervals {
            items.append(
                SessionStatItem(
                    label: L10n.distance,
                    value: lap.distanceMeters > 0
                        ? Formatters.distanceString(meters: lap.distanceMeters, unit: distanceUnit)
                        : L10n.dash
                )
            )

            items.append(
                SessionStatItem(
                    label: L10n.pace,
                    value: lap.distanceMeters > 0
                        ? Formatters.paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: distanceUnit)
                        : L10n.dash
                )
            )
        }

        let gpsDistanceMeters: Double?
        if trackingMode == .gps {
            gpsDistanceMeters = lap.distanceMeters > 0 ? lap.distanceMeters : nil
        } else {
            gpsDistanceMeters = lap.gpsDistanceMeters
        }

        if trackingMode.usesGPSDistance {
            items.append(
                SessionStatItem(
                    label: L10n.gpsDistanceLabel,
                    value: gpsDistanceMeters.flatMap { distance in
                        distance > 0 ? Formatters.distanceString(meters: distance, unit: distanceUnit) : nil
                    } ?? L10n.dash
                )
            )

            items.append(
                SessionStatItem(
                    label: L10n.gpsPaceLabel,
                    value: gpsDistanceMeters.flatMap { distance in
                        distance > 0
                            ? Formatters.paceString(distanceMeters: distance, durationSeconds: lap.durationSeconds, unit: distanceUnit)
                            : nil
                    } ?? L10n.dash
                )
            )
        }

        if let targetTime = targetSegment?.targetTimeSeconds {
            items.append(
                SessionStatItem(
                    label: L10n.targetTimeLabel,
                    value: Formatters.compactTimeString(from: targetTime)
                )
            )
        }

        if let targetPace = targetSegment?.targetPaceSecondsPerKm {
            items.append(
                SessionStatItem(
                    label: L10n.targetPaceLabel,
                    value: Formatters.compactPaceString(secondsPerKm: targetPace, unit: distanceUnit)
                )
            )
        }

        if let averageHeartRateBPM = lap.averageHeartRateBPM {
            items.append(
                SessionStatItem(
                    label: L10n.heartRate,
                    value: "\(Int(averageHeartRateBPM)) bpm"
                )
            )
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if lap.lapType == .rest {
                    Text(L10n.rest)
                        .font(.caption.bold())
                } else {
                    Text(badgeTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.07, green: 0.09, blue: 0.15))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.white)
                        )
                }

                Text(headerItems.joined(separator: " • "))
                    .font(.caption)
            }

            if !detailItems.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(detailItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.label)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)

                            Text(item.value)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(lap.lapType == .rest ? Color.white.opacity(0.9) : Color.white.opacity(0.15))
        .foregroundColor(lap.lapType == .rest ? .black : .white)
        .cornerRadius(8)
        .padding(.horizontal, 4)
    }
}

struct SessionStatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

enum SessionLapTargetResolver {
    static func targetSegments(
        for laps: [Lap],
        workoutPlan: WorkoutPlanSnapshot,
        trackingMode: TrackingMode
    ) -> [UUID: DistanceSegment] {
        guard trackingMode.usesManualIntervals, !workoutPlan.distanceSegments.isEmpty else {
            return [:]
        }

        var targetsByLapID: [UUID: DistanceSegment] = [:]
        var segmentIndex = 0
        var repeatsDone = 0

        for lap in laps where lap.lapType == .active {
            let safeIndex = min(segmentIndex, workoutPlan.distanceSegments.count - 1)
            let segment = workoutPlan.distanceSegments[safeIndex]
            targetsByLapID[lap.id] = segment

            repeatsDone += 1
            if let repeatCount = segment.repeatCount,
               repeatsDone >= repeatCount,
               segmentIndex + 1 < workoutPlan.distanceSegments.count {
                segmentIndex += 1
                repeatsDone = 0
            }
        }

        return targetsByLapID
    }
}
