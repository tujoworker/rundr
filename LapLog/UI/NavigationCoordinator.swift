import Foundation
import SwiftUI

@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var path: [AppScreenState] = []
    @Published var isShowingActiveSession = false

    var currentScreen: AppScreenState {
        path.last ?? .home
    }

    func goHome() {
        isShowingActiveSession = false
        path.removeAll()
    }

    func goToPreStart() {
        path.append(.preStart)
    }

    func goToActiveSession() {
        isShowingActiveSession = true
    }

    func goToSessionDetail(id: UUID) {
        path.append(.sessionDetail(id))
    }

    func sessionEnded() {
        DispatchQueue.main.async {
            self.isShowingActiveSession = false
            self.path = []
        }
    }
}
