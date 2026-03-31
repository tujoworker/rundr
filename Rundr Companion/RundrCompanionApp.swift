import SwiftUI

@main
struct RundrCompanionApp: App {
    @StateObject private var persistence = PersistenceManager()
    @StateObject private var syncManager = WatchConnectivitySyncManager()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ZStack {
                CompanionSceneBackground(accentColor: settings.primaryAccentColor)

                CompanionRootView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
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

private struct CompanionSceneBackground: View {
    let accentColor: Color
    @Environment(\.appTheme) private var theme

    var body: some View {
        theme.background.app(accentColor)
            .ignoresSafeArea()
    }
}
