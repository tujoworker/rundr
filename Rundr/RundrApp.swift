import SwiftUI
import SwiftData
import AppIntents

@main
struct RundrApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var persistence = PersistenceManager()
    @StateObject private var syncManager = WatchConnectivitySyncManager()
    @StateObject private var ongoingWorkoutStore = OngoingWorkoutStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var workoutController = WorkoutSessionController()
    @StateObject private var coordinator = NavigationCoordinator()
    @State private var actionButtonObserver: ActionButtonCommandObserver?

    init() {
        RundrShortcutsProvider.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .withAppTheme()
                .environmentObject(persistence)
                .environmentObject(syncManager)
                .environmentObject(ongoingWorkoutStore)
                .environmentObject(settings)
                .environmentObject(healthKitManager)
                .environmentObject(workoutController)
                .environmentObject(coordinator)
                .modelContainer(persistence.modelContainer)
                .task {
                    syncManager.attachPersistence(persistence)
                    syncManager.activate()
                    workoutController.attachOngoingWorkoutStore(ongoingWorkoutStore)
                    workoutController.attachSyncManager(syncManager)
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

        switch ActionButtonCommandRouter.route(
            command: command,
            runState: workoutController.runState,
            currentScreen: coordinator.currentScreen,
            isShowingActiveSession: coordinator.isShowingActiveSession
        ) {
        case .startWorkoutFromPreStart:
            startWorkoutFromPreStart()
        case .markLap:
            handleMarkLapCommand()
        case .resumeSession:
            workoutController.resumeSession()
        case .noOp:
            break
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
            workoutController.lapAlertsEnabled = settings.lapAlerts
            workoutController.restAlertsEnabled = settings.restAlerts
            Task {
                await workoutController.start()
            }
            coordinator.goToActiveSession()
        default:
            break
        }
    }
}
