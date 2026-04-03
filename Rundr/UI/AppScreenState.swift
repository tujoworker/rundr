import Foundation

enum AppScreenState: Hashable {
    case home
    case preStart
    case intervalLibrary
    case sessionDetail(UUID)
    case historySetup(UUID)
    case matchingSessions(UUID)
}
