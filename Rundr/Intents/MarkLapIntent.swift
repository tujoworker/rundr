import AppIntents

struct MarkLapIntent: AppIntent {
    static let title: LocalizedStringResource = "Lap"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let controller = WorkoutSessionController.current {
            controller.markLap(source: .actionButton)
        } else {
            // Fallback: queue for processing when the app finishes launching
            ActionButtonCommandStore.queue(.markLap)
        }
        return .result()
    }
}
