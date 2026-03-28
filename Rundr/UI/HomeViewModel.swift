import Foundation
import SwiftData

@MainActor
final class HomeViewModel: ObservableObject {

    @Published var recentSessions: [Session] = []
    @Published var displayedSessionCount: Int = 3
    @Published var hasMoreSessions: Bool = false

    private let batchSize = 10

    func loadRecent(persistence: PersistenceManager) {
        let all = persistence.fetchAllSessions()
        let count = min(displayedSessionCount, all.count)
        recentSessions = Array(all.prefix(count))
        hasMoreSessions = all.count > displayedSessionCount
    }

    func loadMore(persistence: PersistenceManager) {
        displayedSessionCount += batchSize
        loadRecent(persistence: persistence)
    }
}
