import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PersistenceManager: ObservableObject {

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() {
        do {
            let schema = Schema([Session.self, Lap.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: config)
            self.modelContainer = container
            self.modelContext = container.mainContext
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// For testing – in-memory store
    init(inMemory: Bool) {
        do {
            let schema = Schema([Session.self, Lap.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            let container = try ModelContainer(for: schema, configurations: config)
            self.modelContainer = container
            self.modelContext = container.mainContext
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func saveSession(_ session: Session) {
        modelContext.insert(session)
        try? modelContext.save()
    }

    func deleteSession(_ session: Session) {
        modelContext.delete(session)
        try? modelContext.save()
    }

    func fetchRecentSessions(limit: Int = 3) -> [Session] {
        var descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\Session.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchAllSessions() -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\Session.startedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchSession(id: UUID) -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
