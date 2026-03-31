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
                .onChange(of: workoutController.runState) { _, _ in
                    processPendingActionButtonCommand()
                }
        }
    }

    private func processPendingActionButtonCommand() {
        guard let pendingCommand = ActionButtonCommandStore.pendingCommand() else { return }

        if workoutController.runState == .ended {
            workoutController.resetForNextSession()
            coordinator.goHome()
            ActionButtonCommandStore.clearPendingCommand()
            return
        }

        switch ActionButtonCommandRouter.route(
            command: pendingCommand,
            runState: workoutController.runState,
            currentScreen: coordinator.currentScreen,
            isShowingActiveSession: coordinator.isShowingActiveSession
        ) {
        case .startWorkoutFromPreStart:
            ActionButtonCommandStore.clearPendingCommand()
            startWorkoutFromPreStart()
        case .markLap:
            ActionButtonCommandStore.clearPendingCommand()
            handleMarkLapCommand()
        case .resumeSession:
            ActionButtonCommandStore.clearPendingCommand()
            workoutController.resumeSession()
        case .deferUntilReady:
            break
        case .noOp:
            ActionButtonCommandStore.clearPendingCommand()
            break
        }
    }

    private func handleMarkLapCommand() {
        switch workoutController.runState {
        case .active, .rest:
            workoutController.markLap(source: .actionButton)
        case .paused:
            workoutController.resumeSession()
        case .idle, .ready:
            if coordinator.currentScreen == .preStart {
                startWorkoutFromPreStart()
            }
        case .ending, .ended:
            break
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
