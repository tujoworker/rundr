import Foundation

enum AppScreenState: Hashable {
    case home
    case preStart
    case activeSession
    case sessionDetail(UUID)
}
