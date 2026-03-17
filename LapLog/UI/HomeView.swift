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
                        Button("Load More") {
                            viewModel.loadMore(persistence: persistence)
                        }
                        .font(.footnote)
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
