import SwiftUI

struct AppScreenBackground: View {
    let accentColor: Color

    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                accentColor.opacity(0.18)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct RootView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var workoutController: WorkoutSessionController

    var body: some View {
        ZStack {
            AppScreenBackground(accentColor: settings.primaryAccentColor)

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
            .background(Color.clear)
        }
        .fullScreenCover(isPresented: $coordinator.isShowingActiveSession) {
            ActiveSessionView(onSessionEnded: {
                coordinator.sessionEnded()
            })
        }
    }
}
