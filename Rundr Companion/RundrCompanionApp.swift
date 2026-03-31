import SwiftUI

@main
struct RundrCompanionApp: App {
    @StateObject private var persistence = PersistenceManager()
    @StateObject private var syncManager = WatchConnectivitySyncManager()
    @StateObject private var settings = SettingsStore()

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    var body: some Scene {
        WindowGroup {
            CompanionRootView()
            .withAppTheme()
            .environmentObject(persistence)
            .environmentObject(syncManager)
            .environmentObject(settings)
            .modelContainer(persistence.modelContainer)
            .task {
                syncManager.attachPersistence(persistence)
                syncManager.attachSettings(settings)
                syncManager.activate()
            }
            .onChange(of: settings.currentWorkoutPlan) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.distanceUnit) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.primaryColor) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.appearanceMode) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.lapAlerts) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.restAlerts) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.intervalPresets) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
        }
    }
}
