import SwiftUI

struct SessionDetailView: View {
    let session: Session
    let onUseSessionSettings: () -> Void
    let onShowMatchingSessions: () -> Void
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var syncManager: WatchConnectivitySyncManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var isActionMenuPresented = false
    @State private var isReuseConfirmationPresented = false
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
        let primaryDistanceMeters: Double
        if sessionUsesOpenIntervals || session.mode == .gps {
            primaryDistanceMeters = session.totalGPSDistanceMeters ?? session.totalDistanceMeters
        } else {
            primaryDistanceMeters = session.totalDistanceMeters
        }

        var items: [SessionStatItem] = [
            SessionStatItem(label: L10n.laps, value: String(session.activeLapCount)),
            SessionStatItem(label: L10n.duration, value: Formatters.timeString(from: session.activeDurationSeconds))
        ]

        if let targetTime = firstSegment?.targetTimeSeconds {
            items.append(
                SessionStatItem(label: L10n.targetTimeLabel, value: Formatters.compactTimeString(from: targetTime))
            )
        }

        items.append(
            SessionStatItem(
                label: L10n.distance,
                value: primaryDistanceMeters > 0
                    ? Formatters.distanceString(meters: primaryDistanceMeters, unit: settings.distanceUnit)
                    : L10n.dash
            )
        )

        items.append(
            SessionStatItem(
                label: L10n.averagePaceLabel,
                value: primaryDistanceMeters > 0
                    ? Formatters.paceString(
                        distanceMeters: primaryDistanceMeters,
                        durationSeconds: session.activeDurationSeconds,
                        unit: settings.distanceUnit
                    )
                    : L10n.dash
            )
        )

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
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.sm) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                        Text(headerTitle.dayText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.text.neutral)

                        Text(headerTitle.timeText)
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(theme.text.subtle)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        isActionMenuPresented = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.text.neutral)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(settings.primaryAccentColor.opacity(Tokens.Opacity.foregroundBody))
                            )
                            .accessibilityLabel(L10n.more)
                            .padding(Tokens.Spacing.sm)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, Tokens.Spacing.md + Tokens.Spacing.xs)
                .padding(.trailing, Tokens.Spacing.xs)

                SessionStatsView(items: sessionStats)

                Text(L10n.laps)
                    .font(.caption.bold())
                    .foregroundStyle(theme.text.subtle)
                    .padding(.horizontal, Tokens.Spacing.xs)
                    .padding(.top, Tokens.Spacing.xs)

                ForEach(sortedLaps, id: \.id) { lap in
                    LapRowView(
                        lap: lap,
                        trackingMode: session.mode,
                        distanceUnit: settings.distanceUnit,
                        targetSegment: targetSegmentsByLapID[lap.id]
                    )
                }

                Text(L10n.importStatus)
                    .font(.caption.bold())
                    .foregroundStyle(theme.text.subtle)
                    .padding(.horizontal, Tokens.Spacing.xs)
                    .padding(.top, Tokens.Spacing.lg)

                if isPendingPhoneSync {
                    SessionDetailPendingPhoneSyncBanner()
                        .padding(.horizontal, Tokens.Spacing.xs)
                        .padding(.bottom, Tokens.Spacing.xs)
                } else {
                    SessionDetailConfirmedPhoneSyncBanner(tint: settings.primaryAccentColor)
                        .padding(.horizontal, Tokens.Spacing.xs)
                        .padding(.bottom, Tokens.Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            AppScreenBackground(accentColor: settings.primaryAccentColor)
        }
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog(L10n.thisSession, isPresented: $isActionMenuPresented, titleVisibility: .visible) {
            Button(L10n.reusePlan) {
                isReuseConfirmationPresented = true
            }
            Button(L10n.showMatchingSessions) {
                onShowMatchingSessions()
            }
            Button(L10n.deleteSession, role: .destructive) {
                isDeleteConfirmationPresented = true
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .alert(L10n.useActivityConfirmationTitle, isPresented: $isReuseConfirmationPresented) {
            Button(L10n.yes) {
                onUseSessionSettings()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.useActivityConfirmationMessage)
        }
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
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading),
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading)
    ]

    var body: some View {
        if !items.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Spacing.lg) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                        Text(item.label)
                            .font(.system(size: Tokens.FontSize.sm, weight: .regular, design: .rounded))
                            .foregroundStyle(theme.text.subtle)

                        Text(item.value)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.text.neutral)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.md)
            .background(theme.background.history)
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
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading),
        GridItem(.flexible(), spacing: Tokens.Spacing.xl, alignment: .topLeading)
    ]

    private var badgeTitle: String {
        String(lap.index)
    }

    private var headerItems: [String] {
        [Formatters.compactTimeString(from: lap.durationSeconds)]
    }

    private var detailItems: [SessionStatItem] {
        var items: [SessionStatItem] = []

        guard lap.lapType == .active else { return items }

        let isOpenInterval = targetSegment?.usesOpenDistance == true

        let gpsDistanceMeters: Double?
        if trackingMode == .gps {
            gpsDistanceMeters = lap.distanceMeters > 0 ? lap.distanceMeters : nil
        } else {
            gpsDistanceMeters = lap.gpsDistanceMeters
        }

        let primaryDistanceMeters: Double?
        if isOpenInterval || trackingMode == .gps {
            primaryDistanceMeters = gpsDistanceMeters ?? (lap.distanceMeters > 0 ? lap.distanceMeters : nil)
        } else {
            primaryDistanceMeters = lap.distanceMeters > 0 ? lap.distanceMeters : nil
        }

        items.append(
            SessionStatItem(
                label: L10n.distance,
                value: primaryDistanceMeters.flatMap { distance in
                    distance > 0 ? Formatters.distanceString(meters: distance, unit: distanceUnit) : nil
                } ?? L10n.dash
            )
        )

        items.append(
            SessionStatItem(
                label: L10n.pace,
                value: primaryDistanceMeters.flatMap { distance in
                    distance > 0
                        ? Formatters.paceString(distanceMeters: distance, durationSeconds: lap.durationSeconds, unit: distanceUnit)
                        : nil
                } ?? L10n.dash
            )
        )

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
          guard lap.lapType == .active,
              let targetTime = targetSegment?.targetTimeSeconds else { return nil }
        let delta = Int(lap.durationSeconds - targetTime)
        if delta == 0 { return "(\(L10n.dash))" }
        let sign = delta > 0 ? "+" : ""
        return "(\(sign)\(delta)s)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.sm) {
                if lap.lapType.isRecovery {
                    Text(L10n.rest)
                        .font(.caption.bold())
                } else {
                    Text(badgeTitle)
                        .font(.system(size: Tokens.FontSize.sm, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.text.bold)
                        .padding(.horizontal, Tokens.Spacing.sm)
                        .padding(.vertical, Tokens.Spacing.xxxs)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                                .fill(theme.background.bold)
                        )
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions[.firstTextBaseline] + badgeOpticalLift
                        }
                }

                Text(headerItems.joined(separator: " • "))
                    .font(.system(size: Tokens.FontSize.base, weight: .medium))

                if let delta = timeDeltaText {
                    Text(delta)
                        .font(.system(size: Tokens.FontSize.sm, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if !detailItems.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Spacing.lg) {
                    ForEach(detailItems) { item in
                        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                            Text(item.label)
                                .font(.system(size: Tokens.FontSize.sm, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)

                            Text(item.value)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, Tokens.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.md)
        .background(lap.lapType.isRecovery ? theme.background.historyRest : theme.background.history)
        .foregroundColor(lap.lapType.isRecovery ? theme.text.historyRest : theme.text.neutral)
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
