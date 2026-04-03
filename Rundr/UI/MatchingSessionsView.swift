import SwiftUI

struct MatchingSessionsView: View {
    let sourceSession: Session

    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Environment(\.appTheme) private var theme

    @State private var matchingSessions: [Session] = []

    private var sectionTitle: String {
        settings.title(for: sourceSession.snapshotWorkoutPlan)
    }

    var body: some View {
        List {
            Section {
                if matchingSessions.isEmpty {
                    Text(L10n.noOtherMatchingSessionsYet)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Spacing.xxxxl)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(matchingSessions, id: \.id) { session in
                        NavigationLink(value: AppScreenState.sessionDetail(session.id)) {
                            SessionRowView(session: session)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(Tokens.ListRowInsets.card)
                        .listRowBackground(Color.clear)
                    }
                }
            } header: {
                Text(sectionTitle)
                    .foregroundStyle(theme.text.neutral)
            }
        }
        .tint(settings.primaryAccentColor)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(L10n.matchingSessions)
        .toolbar(.visible, for: .navigationBar)
        .onAppear(perform: loadMatchingSessions)
        .onChange(of: coordinator.path) {
            loadMatchingSessions()
        }
    }

    private func loadMatchingSessions() {
        matchingSessions = persistence.fetchMatchingSessions(for: sourceSession)
    }
}
