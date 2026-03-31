import AppIntents

struct RundrShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRunningWorkoutIntent(style: .running),
            phrases: [
                "Start \(\.$workoutStyle) in \(.applicationName)",
                "Start a workout in \(.applicationName)",
                "Start intervals in \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: MarkLapIntent(),
            phrases: [
                "Mark lap in \(.applicationName)",
                "Log lap in \(.applicationName)"
            ],
            shortTitle: "Lap",
            systemImageName: "flag.checkered"
        )
    }
}
