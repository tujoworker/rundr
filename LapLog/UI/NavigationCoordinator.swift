import Foundation
import SwiftUI

@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var path: [AppScreenState] = []
    @Published var showActiveSession = false

    func goHome() {
        path.removeAll()
    }

    func goToPreStart() {
        path.append(.preStart)
    }

    func goToActiveSession() {
        // Replace preStart with activeSession
        if let idx = path.lastIndex(of: .preStart) {
            path.remove(at: idx)
        }
        showActiveSession = true
    }

    func goToSessionDetail(id: UUID) {
        path.append(.sessionDetail(id))
    }

    func sessionEnded() {
        showActiveSession = false
        path.removeAll()
    }
}
