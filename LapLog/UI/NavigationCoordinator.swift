import Foundation
import SwiftUI

@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var path: [AppScreenState] = []

    var currentScreen: AppScreenState {
        path.last ?? .home
    }

    func goHome() {
        path.removeAll()
    }

    func goToPreStart() {
        path.append(.preStart)
    }

    func goToActiveSession() {
        // Replace entire path with just activeSession in a single mutation
        path = [.activeSession]
    }

    func goToSessionDetail(id: UUID) {
        path.append(.sessionDetail(id))
    }

    func sessionEnded() {
        DispatchQueue.main.async {
            self.path = []
        }
    }
}
