import SwiftUI

struct HomeView: View {
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = HomeViewModel()

    var onGetReady: () -> Void
    var onSelectSession: (Session) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onGetReady) {
                Text("Get Ready")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if viewModel.recentSessions.isEmpty {
                Spacer()
                Text("No sessions yet")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(viewModel.recentSessions, id: \.id) { session in
                        Button {
                            onSelectSession(session)
                        } label: {
                            SessionRowView(session: session)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let session = viewModel.recentSessions[index]
                            persistence.deleteSession(session)
                        }
                        viewModel.loadRecent(persistence: persistence)
                    }

                    if viewModel.hasMoreSessions {
                        Button("Load More") {
                            viewModel.loadMore(persistence: persistence)
                        }
                        .font(.footnote)
                        .padding(.top, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
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
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
}
