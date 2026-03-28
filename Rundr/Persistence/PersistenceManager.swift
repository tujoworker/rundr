import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PersistenceManager: ObservableObject {

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() {
        do {
            let container = try Self.makeContainer(isStoredInMemoryOnly: false)
            self.modelContainer = container
            self.modelContext = container.mainContext
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// For testing – in-memory store
    init(inMemory: Bool) {
        do {
            let container = try Self.makeContainer(isStoredInMemoryOnly: inMemory)
            self.modelContainer = container
            self.modelContext = container.mainContext
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func saveSession(_ session: Session) {
        if let existingSession = fetchSession(id: session.id), existingSession !== session {
            upsertSessionRecord(SessionSyncRecord(session: session))
            return
        }

        modelContext.insert(session)
        try? modelContext.save()
    }

    @discardableResult
    func upsertSessionRecord(_ record: SessionSyncRecord) -> Session {
        if let existingSession = fetchSession(id: record.id) {
            guard record.shouldReplace(existingSession: existingSession) else {
                return existingSession
            }

            record.apply(to: existingSession, in: modelContext)
            try? modelContext.save()
            return existingSession
        }

        let session = record.makeModel()
        modelContext.insert(session)
        try? modelContext.save()
        return session
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

    private static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let schema = Schema([Session.self, Lap.self])

        if !isStoredInMemoryOnly {
            do {
                let cloudKitConfig = ModelConfiguration(
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .automatic
                )
                return try ModelContainer(for: schema, configurations: cloudKitConfig)
            } catch {
                let localConfig = ModelConfiguration(isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: localConfig)
            }
        }

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}
