import Foundation

enum LapSource: String, Codable, CaseIterable {
    case distanceTap
    case actionButton
    case autoDistance
    case autoTime
    case sessionEndSplit
}
