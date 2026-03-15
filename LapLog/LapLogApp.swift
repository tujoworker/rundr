import SwiftUI
import SwiftData
import AppIntents

@main
struct LapLogApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var persistence = PersistenceManager()
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
                .environmentObject(settings)
                .environmentObject(healthKitManager)
                .environmentObject(workoutController)
                .environmentObject(coordinator)
                .modelContainer(persistence.modelContainer)
                .task {
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
                    guard newPhase == .active else { return }
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
            advanceActionButtonFlow()
        case .markLap:
            switch workoutController.runState {
            case .active, .rest:
                workoutController.markLap(source: .actionButton)
            case .idle, .ready:
                advanceActionButtonFlow()
            default:
                return
            }
        }
    }

    private func advanceActionButtonFlow() {
        if workoutController.runState == .ended {
            workoutController.resetForNextSession()
        }

        switch workoutController.runState {
        case .idle:
            workoutController.getReady()
            coordinator.goToPreStart()
        case .ready:
            if coordinator.currentScreen == .preStart {
                workoutController.configure(
                    trackingMode: settings.trackingMode,
                    distanceLapDistanceMeters: settings.distanceDistanceMeters,
                    healthKitManager: healthKitManager
                )
                Task {
                    await workoutController.start()
                }
                coordinator.goToActiveSession()
            } else {
                coordinator.goToPreStart()
            }
        default:
            return
        }
    }
}
