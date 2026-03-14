import Foundation

enum WorkoutRunState: String, Equatable {
    case idle
    case ready
    case active
    case rest
    case ending
    case ended
}
