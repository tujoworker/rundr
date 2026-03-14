import SwiftUI

struct RootView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var workoutController: WorkoutSessionController

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(
                onGetReady: {
                    workoutController.getReady()
                    coordinator.goToPreStart()
                },
                onSelectSession: { session in
                    coordinator.goToSessionDetail(id: session.id)
                }
            )
            .navigationDestination(for: AppScreenState.self) { state in
                switch state {
                case .preStart:
                    PreStartView(onStart: {
                        workoutController.configure(
                            trackingMode: settings.trackingMode,
                            distanceLapDistanceMeters: settings.distanceDistanceMeters,
                            healthKitManager: healthKitManager
                        )
                        Task {
                            await workoutController.start()
                        }
                        coordinator.goToActiveSession()
                    })
                case .activeSession:
                    ActiveSessionView(onSessionEnded: {
                        coordinator.sessionEnded()
                    })
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
                case .sessionDetail(let sessionID):
                    if let session = persistence.fetchSession(id: sessionID) {
                        SessionDetailView(session: session)
                    } else {
                        Text("Session not found")
                    }
                case .home:
                    EmptyView()
                }
            }
        }
    }
}
