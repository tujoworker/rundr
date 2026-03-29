import SwiftUI

struct HomeView: View {
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = HomeViewModel()

    var onGetReady: () -> Void
    var onSelectSession: (Session) -> Void

    var body: some View {
        List {
            Section {
                Button(action: onGetReady) {
                    Text(L10n.getReady)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .accentRoundedButtonChrome(
                    accentColor: settings.primaryAccentColor,
                    cornerRadius: 999,
                    lineWidth: 3
                )
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 18, trailing: 12))
                .listRowBackground(Color.clear)

                if viewModel.recentSessions.isEmpty {
                    Text(L10n.noSessionsYet)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Spacing.xxxxl)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.recentSessions, id: \.id) { session in
                        Button {
                            onSelectSession(session)
                        } label: {
                            SessionRowView(session: session)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                persistence.deleteSession(session)
                                viewModel.loadRecent(persistence: persistence)
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                        .listRowBackground(Color.clear)
                    }

                    if viewModel.hasMoreSessions {
                        Button {
                            viewModel.loadMore(persistence: persistence)
                        } label: {
                            Text(L10n.loadMore)
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .accentRoundedButtonChrome(accentColor: settings.primaryAccentColor, cornerRadius: 999)
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .tint(settings.primaryAccentColor)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .onAppear {
            viewModel.loadRecent(persistence: persistence)
        }
        .onChange(of: coordinator.path) {
            viewModel.loadRecent(persistence: persistence)
        }
        .onChange(of: coordinator.isShowingActiveSession) { _, showing in
            if !showing {
                viewModel.loadRecent(persistence: persistence)
            }
        }
    }
}

struct SessionRowView: View {
    let session: Session
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
        GridItem(.flexible(), spacing: 12, alignment: .topLeading)
    ]

    private var sessionTitle: String {
        Formatters.historySessionDateTimeString(from: session.startedAt)
    }

    private var sessionUsesOpenIntervals: Bool {
        session.snapshotWorkoutPlan.distanceSegments.contains(where: \.usesOpenDistance)
    }

    private var sessionStats: [SessionCardStatItem] {
        let summaryDistance = sessionUsesOpenIntervals
            ? (session.totalGPSDistanceMeters ?? session.totalDistanceMeters)
            : session.totalDistanceMeters
        let items: [SessionCardStatItem] = [
            SessionCardStatItem(label: L10n.laps, value: String(session.activeLapCount)),
            SessionCardStatItem(
                label: L10n.pace,
                value: Formatters.paceString(
                    distanceMeters: summaryDistance,
                    durationSeconds: session.activeDurationSeconds,
                    unit: settings.distanceUnit
                )
            ),
            SessionCardStatItem(label: L10n.duration, value: Formatters.timeString(from: session.activeDurationSeconds)),
            SessionCardStatItem(
                label: session.mode.usesManualIntervals && !sessionUsesOpenIntervals ? L10n.distance : L10n.gpsDistanceLabel,
                value: summaryDistance > 0
                    ? Formatters.distanceString(meters: summaryDistance, unit: settings.distanceUnit)
                    : L10n.dash
            )
        ]

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text(sessionTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            .padding(.bottom, Tokens.Spacing.xs)

            LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Spacing.lg) {
                ForEach(sessionStats) { item in
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.md)
        .background(theme.surfaceCard)
        .cornerRadius(Tokens.Radius.medium)
    }
}

private struct SessionCardStatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}
