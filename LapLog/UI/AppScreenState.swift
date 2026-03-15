import Foundation

enum AppScreenState: Hashable {
    case home
    case preStart
    case sessionDetail(UUID)
}
