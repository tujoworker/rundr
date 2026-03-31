import Foundation

enum ActionButtonCommandRoute {
    case startWorkoutFromPreStart
    case markLap
    case resumeSession
    case deferUntilReady
    case noOp
}

enum ActionButtonCommandRouter {
    static func route(
        command: ActionButtonCommand?,
        runState: WorkoutRunState,
        currentScreen: AppScreenState,
        isShowingActiveSession: Bool
    ) -> ActionButtonCommandRoute {
        switch command {
        case .startWorkout:
            switch runState {
            case .idle, .ready:
                guard currentScreen == .preStart else { return .noOp }
                return .startWorkoutFromPreStart
            case .active, .rest, .paused, .ending, .ended:
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
