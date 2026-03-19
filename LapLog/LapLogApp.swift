import SwiftUI
import SwiftData
import AppIntents

@main
struct LapLogApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var persistence = PersistenceManager()
    @StateObject private var ongoingWorkoutStore = OngoingWorkoutStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var workoutController = WorkoutSessionController()
    @StateObject private var coordinator = NavigationCoordinator()
    @State private var actionButtonObserver: ActionButtonCommandObserver?

    init() {
        LapLogShortcutsProvider.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(persistence)
                .environmentObject(ongoingWorkoutStore)
                .environmentObject(settings)
                .environmentObject(healthKitManager)
                .environmentObject(workoutController)
                .environmentObject(coordinator)
                .modelContainer(persistence.modelContainer)
                .task {
                    workoutController.attachOngoingWorkoutStore(ongoingWorkoutStore)
                    if actionButtonObserver == nil {
                        let observer = ActionButtonCommandObserver {
                            processPendingActionButtonCommand()
                        }
                        observer.start()
                        actionButtonObserver = observer
                    }
                    processPendingActionButtonCommand()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else {
                        workoutController.persistRecoverySnapshotIfNeeded()
                        return
                    }
                    processPendingActionButtonCommand()
                }
        }
    }

    private func processPendingActionButtonCommand() {
        guard let command = ActionButtonCommandStore.consumePendingCommand() else { return }

        if workoutController.runState == .ended {
            workoutController.resetForNextSession()
            coordinator.goHome()
        }

        switch command {
        case .startWorkout:
            handleStartWorkoutCommand()
        case .markLap:
            handleMarkLapCommand()
        }
    }

    private func handleStartWorkoutCommand() {
        switch coordinator.currentScreen {
        case .home, .intervalLibrary, .sessionDetail, .historySetup:
            break
        case .preStart:
            startWorkoutFromPreStart()
        }
    }

    private func handleMarkLapCommand() {
        if coordinator.isShowingActiveSession {
            switch workoutController.runState {
            case .active, .rest:
                workoutController.markLap(source: .actionButton)
            case .paused:
                workoutController.resumeSession()
            default:
                break
            }
            return
        }

        switch coordinator.currentScreen {
        case .home, .intervalLibrary, .sessionDetail, .historySetup:
            break
        case .preStart:
            startWorkoutFromPreStart()
        }
    }

    private func startWorkoutFromPreStart() {
        switch workoutController.runState {
        case .idle:
            workoutController.getReady()
        case .ready:
            workoutController.configure(
                trackingMode: settings.trackingMode,
                distanceLapDistanceMeters: settings.distanceDistanceMeters,
                distanceSegments: settings.distanceSegments,
                restMode: settings.restMode,
                healthKitManager: healthKitManager
            )
            Task {
                await workoutController.start()
            }
            coordinator.goToActiveSession()
        default:
            break
        }
    }
}
