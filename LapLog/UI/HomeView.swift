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
                    Text("Get Ready")
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
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
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
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                        .listRowBackground(Color.clear)
                    }

                    if viewModel.hasMoreSessions {
                        Button {
                            viewModel.loadMore(persistence: persistence)
                        } label: {
                            Text("Load More")
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
        .listStyle(.carousel)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .onAppear {
            viewModel.loadRecent(persistence: persistence)
        }
        .onChange(of: coordinator.path) {
            viewModel.loadRecent(persistence: persistence)
        }
    }
}

struct SessionRowView: View {
    let session: Session
    @EnvironmentObject var settings: SettingsStore

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
            SessionCardStatItem(label: L10n.laps, value: String(session.totalLaps)),
            SessionCardStatItem(
                label: L10n.pace,
                value: Formatters.paceString(
                    distanceMeters: summaryDistance,
                    durationSeconds: session.durationSeconds,
                    unit: settings.distanceUnit
                )
            ),
            SessionCardStatItem(label: L10n.time, value: Formatters.timeString(from: session.durationSeconds)),
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
        VStack(alignment: .leading, spacing: 4) {
            Text(sessionTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
            .padding(.bottom, 4)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(sessionStats) { item in
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.15))
        .cornerRadius(8)
    }
}

private struct SessionCardStatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}
