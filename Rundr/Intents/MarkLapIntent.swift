import AppIntents

struct MarkLapIntent: AppIntent {
    static let title: LocalizedStringResource = "Lap"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        ActionButtonCommandStore.queue(.markLap)
        return .result()
    }
}
