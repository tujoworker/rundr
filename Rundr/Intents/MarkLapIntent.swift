import AppIntents

struct MarkLapIntent: AppIntent {
    static let title: LocalizedStringResource = "Lap"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let controller = WorkoutSessionController.current {
            switch ActionButtonCommandRouter.route(command: .markLap, runState: controller.runState) {
            case .markLap:
                controller.markLap(source: .actionButton)
            case .resumeSession:
                controller.resumeSession()
            case .deferUntilReady, .noOp, .startWorkout:
                ActionButtonCommandStore.queue(.markLap)
            }
        } else {
            // Fallback: queue for processing when the app finishes launching
            ActionButtonCommandStore.queue(.markLap)
        }
        return .result()
    }
}
