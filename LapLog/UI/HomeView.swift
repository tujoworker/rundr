import SwiftUI

struct HomeView: View {
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = HomeViewModel()

    var onGetReady: () -> Void
    var onSelectSession: (Session) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button(action: onGetReady) {
                    Text("Get Ready")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.primaryAccentColor)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 18)

                if viewModel.recentSessions.isEmpty {
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.recentSessions, id: \.id) { session in
                            Button {
                                onSelectSession(session)
                            } label: {
                                SessionRowView(session: session)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    persistence.deleteSession(session)
                                    viewModel.loadRecent(persistence: persistence)
                                }
                            }
                        }

                        if viewModel.hasMoreSessions {
                            Button("Load More") {
                                viewModel.loadMore(persistence: persistence)
                            }
                            .font(.footnote)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.bottom, 8)
        }
        .tint(settings.primaryAccentColor)
        .onAppear {
            viewModel.loadRecent(persistence: persistence)
        }
        .onChange(of: coordinator.path) {
            viewModel.loadRecent(persistence: persistence)
        }
        .background(Color.clear)
    }
}

struct SessionRowView: View {
    let session: Session
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.startedAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Laps: \(session.totalLaps) • \(Formatters.paceString(distanceMeters: session.totalDistanceMeters, durationSeconds: session.durationSeconds, unit: settings.distanceUnit))")
                .font(.caption)
            Text("Time: \(Formatters.timeString(from: session.durationSeconds)) • \(Formatters.distanceString(meters: session.totalDistanceMeters, unit: settings.distanceUnit))")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.15))
        .cornerRadius(8)
    }
}
