import SwiftUI

struct SessionDetailView: View {
    let session: Session
    let onUseSessionSettings: () -> Void
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var syncManager: WatchConnectivitySyncManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var showConfirmedPhoneSyncMessage = false
    @State private var isDeleteConfirmationPresented = false

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.startedAt < $1.startedAt }
    }

    private var headerTitle: HistoryDateRangeParts {
        Formatters.historySessionDateRangeParts(start: session.startedAt, end: session.endedAt)
    }

    private var isPendingPhoneSync: Bool {
        syncManager.hasPendingCompletedSessionTransfer(for: session.id)
    }

    private var sessionUsesOpenIntervals: Bool {
        session.snapshotWorkoutPlan.distanceSegments.contains(where: \.usesOpenDistance)
    }

    private var sessionStats: [SessionStatItem] {
        let firstSegment = session.snapshotWorkoutPlan.distanceSegments.first
        let thirdItem: SessionStatItem
        if let targetTime = firstSegment?.targetTimeSeconds {
            thirdItem = SessionStatItem(label: L10n.targetTimeLabel, value: Formatters.compactTimeString(from: targetTime))
        } else {
            let modeValue = session.mode == .distanceDistance ? L10n.manualLabel : session.mode.displayName
            thirdItem = SessionStatItem(label: L10n.mode, value: modeValue)
        }
        var items: [SessionStatItem] = [
            SessionStatItem(label: L10n.laps, value: String(session.activeLapCount)),
            SessionStatItem(label: L10n.duration, value: Formatters.timeString(from: session.activeDurationSeconds)),
            thirdItem
        ]

        if session.mode.usesManualIntervals && !sessionUsesOpenIntervals {
            items.append(
                SessionStatItem(
                    label: L10n.distance,
                    value: session.totalDistanceMeters > 0
                        ? Formatters.distanceString(meters: session.totalDistanceMeters, unit: settings.distanceUnit)
                        : L10n.dash
                )
            )
        } else if session.mode == .gps || (session.mode == .dual && sessionUsesOpenIntervals) {
            let distanceValue = session.totalGPSDistanceMeters ?? session.totalDistanceMeters
            items.append(
                SessionStatItem(
                    label: L10n.gpsDistanceLabel,
                    value: distanceValue > 0
                        ? Formatters.distanceString(meters: distanceValue, unit: settings.distanceUnit)
                        : L10n.dash
                )
            )
        }

        if session.mode == .dual && !sessionUsesOpenIntervals {
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
                    VStack(alignment: .leading, spacing: 1) {
                        Text(headerTitle.dayText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)

                        Text(headerTitle.timeText)
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(theme.textSecondary)
                    }
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
                                .foregroundStyle(theme.textPrimary)
                                .frame(width: 18, height: 18)
                                .background(
                                    Circle()
                                        .fill(settings.primaryAccentColor.opacity(0.8))
                                )
                                .accessibilityLabel(L10n.phoneSyncConfirmedTitle)
                                .padding(Tokens.Spacing.sm)
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
                    SessionDetailConfirmedPhoneSyncBanner(tint: settings.primaryAccentColor)
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
                    Text(L10n.redoActivity)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(settings.primaryAccentColor)
                .padding(.top, 10)
                .padding(.horizontal, 4)

                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Text(L10n.deleteSession)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 10)
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 4)
        }
        .background(Color.clear)
        .toolbar(.visible, for: .navigationBar)
        .alert(L10n.deleteSession, isPresented: $isDeleteConfirmationPresented) {
            Button(L10n.delete, role: .destructive) {
                persistence.deleteSession(session)
                dismiss()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteSessionConfirmMessage)
        }
    }
}

private struct SessionDetailPendingPhoneSyncBanner: View {
    private let tint = Color.white

    var body: some View {
        SessionDetailPhoneSyncMessageBanner(
            title: L10n.phoneSyncPendingTitle,
            subtitle: L10n.phoneSyncPendingSubtitle,
            tint: tint
        )
    }
}

private struct SessionDetailConfirmedPhoneSyncBanner: View {
    let tint: Color

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
        TintedInfoBanner(
            title: title,
            subtitle: subtitle,
            tint: tint
        )
    }
}

private struct SessionStatsView: View {
    let items: [SessionStatItem]
    @Environment(\.appTheme) private var theme

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
        GridItem(.flexible(), spacing: 12, alignment: .topLeading)
    ]

    var body: some View {
        if !items.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Spacing.lg) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                        Text(item.label)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(theme.textTertiary)

                        Text(item.value)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.md)
            .background(theme.surfaceInput)
            .cornerRadius(Tokens.Radius.medium)
            .padding(.horizontal, Tokens.Spacing.xs)
            .padding(.bottom, Tokens.Spacing.sm)
        }
    }
}

struct LapRowView: View {
    let lap: Lap
    let trackingMode: TrackingMode
    var distanceUnit: DistanceUnit = .km
    var targetSegment: DistanceSegment? = nil
    @Environment(\.appTheme) private var theme

    private let badgeOpticalLift: CGFloat = 2

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

        let isOpenInterval = targetSegment?.usesOpenDistance == true

        if trackingMode.usesManualIntervals && !isOpenInterval {
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

        let paceDistanceMeters: Double?
        if isOpenInterval {
            paceDistanceMeters = gpsDistanceMeters ?? (lap.distanceMeters > 0 ? lap.distanceMeters : nil)
        } else {
            paceDistanceMeters = lap.distanceMeters > 0 ? lap.distanceMeters : nil
        }

        if trackingMode.usesManualIntervals || isOpenInterval {
            items.append(
                SessionStatItem(
                    label: L10n.pace,
                    value: paceDistanceMeters.flatMap { distance in
                        distance > 0
                            ? Formatters.paceString(distanceMeters: distance, durationSeconds: lap.durationSeconds, unit: distanceUnit)
                            : nil
                    } ?? L10n.dash
                )
            )
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

            if !isOpenInterval {
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

    private var timeDeltaText: String? {
        guard lap.lapType != .rest,
              let targetTime = targetSegment?.targetTimeSeconds else { return nil }
        let delta = Int(lap.durationSeconds - targetTime)
        if delta == 0 { return "(\(L10n.dash))" }
        let sign = delta > 0 ? "+" : ""
        return "(\(sign)\(delta)s)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if lap.lapType == .rest {
                    Text(L10n.rest)
                        .font(.caption.bold())
                } else {
                    Text(badgeTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.badgeForeground)
                        .padding(.horizontal, Tokens.Spacing.sm)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                                .fill(theme.badgeBackground)
                        )
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions[.firstTextBaseline] + badgeOpticalLift
                        }
                }

                Text(headerItems.joined(separator: " • "))
                    .font(.system(size: 15, weight: .medium))

                if let delta = timeDeltaText {
                    Text(delta)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
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
        .padding(Tokens.Spacing.md)
        .background(lap.lapType == .rest ? theme.surfaceRestCard : theme.surfaceCard)
        .foregroundColor(lap.lapType == .rest ? theme.textOnRestSurface : theme.textPrimary)
        .cornerRadius(Tokens.Radius.medium)
        .padding(.horizontal, Tokens.Spacing.xs)
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
