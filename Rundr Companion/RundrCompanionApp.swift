import SwiftUI

@main
struct RundrCompanionApp: App {
    @StateObject private var persistence = PersistenceManager()
    @StateObject private var syncManager = WatchConnectivitySyncManager()

    var body: some Scene {
        WindowGroup {
            CompanionRootView()
                .environmentObject(persistence)
                .environmentObject(syncManager)
                .modelContainer(persistence.modelContainer)
                .task {
                    syncManager.attachPersistence(persistence)
                    syncManager.activate()
                }
        }
    }
}