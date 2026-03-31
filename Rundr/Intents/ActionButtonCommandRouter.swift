import Foundation

enum ActionButtonCommandRoute {
    case startWorkoutFromPreStart
    case markLap
    case resumeSession
    case noOp
}

enum ActionButtonCommandRouter {
    static func route(
        command: ActionButtonCommand,
        runState: WorkoutRunState,
        currentScreen: AppScreenState,
        isShowingActiveSession: Bool
    ) -> ActionButtonCommandRoute {
        if isShowingActiveSession {
            switch runState {
            case .active, .rest:
                return .markLap
            case .paused:
                return .resumeSession
            case .idle, .ready, .ending, .ended:
                return .noOp
            }
        }

        switch command {
        case .startWorkout, .markLap:
            guard currentScreen == .preStart else { return .noOp }
            switch runState {
            case .idle:
                return .startWorkoutFromPreStart
            case .ready:
                return .startWorkoutFromPreStart
            case .active, .rest, .paused, .ending, .ended:
                return .noOp
            }
        }
    }
}
