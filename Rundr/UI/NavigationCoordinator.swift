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

    func goToPreStart(replacingPath: Bool = false) {
        if replacingPath {
            path = [.preStart]
            return
        }
        guard currentScreen != .preStart else { return }
        path.append(.preStart)
    }

    func goToIntervalLibrary() {
        guard currentScreen != .intervalLibrary else { return }
        path.append(.intervalLibrary)
    }

    func goToActiveSession() {
        isShowingActiveSession = true
    }

    func goToSessionDetail(id: UUID) {
        path.append(.sessionDetail(id))
    }

    func goToHistorySetup(id: UUID) {
        path.append(.historySetup(id))
    }

    func goToMatchingSessions(id: UUID) {
        path.append(.matchingSessions(id))
    }

    func sessionEnded() {
        DispatchQueue.main.async {
            self.isShowingActiveSession = false
            self.path = []
        }
    }
}
