import Foundation

enum ActionButtonCommandRoute {
    case startWorkout
    case markLap
    case resumeSession
    case deferUntilReady
    case noOp
}

enum ActionButtonCommandRouter {
    static func route(
        command: ActionButtonCommand?,
        runState: WorkoutRunState
    ) -> ActionButtonCommandRoute {
        switch command {
        case .startWorkout:
            switch runState {
            case .idle, .ready:
                return .startWorkout
            case .active, .rest:
                return .markLap
            case .paused:
                return .resumeSession
            case .ending, .ended:
                return .noOp
            }
        case .markLap:
            switch runState {
            case .active, .rest:
                return .markLap
            case .paused:
                return .resumeSession
            case .idle, .ready:
                return .deferUntilReady
            case .ending, .ended:
                return .noOp
            }
        case nil:
            return .noOp
        }
    }
}
