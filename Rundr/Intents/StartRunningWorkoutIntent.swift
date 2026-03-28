import AppIntents

enum RundrWorkoutStyle: String, AppEnum {
    case running

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout")
    static let caseDisplayRepresentations: [RundrWorkoutStyle: DisplayRepresentation] = [
        .running: "Intervals"
    ]
}

struct StartRunningWorkoutIntent: StartWorkoutIntent {
    static let title: LocalizedStringResource = "Start Intervals"
    static let description = IntentDescription("Start a intervals workout.")
    static let openAppWhenRun = true
    static let suggestedWorkouts: [StartRunningWorkoutIntent] = [
        .init(style: .running)
    ]

    typealias WorkoutStyle = RundrWorkoutStyle

    @Parameter(title: "Workout")
    var workoutStyle: RundrWorkoutStyle

    init() {
        workoutStyle = .running
    }

    init(style: RundrWorkoutStyle) {
        workoutStyle = style
    }

    var displayRepresentation: DisplayRepresentation {
        switch workoutStyle {
        case .running:
            return DisplayRepresentation(title: "Intervals")
        }
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$workoutStyle)")
    }

    func perform() async throws -> some IntentResult {
        ActionButtonCommandStore.queue(.startWorkout)
        if #available(watchOS 10.2, *) {
            return .result(actionButtonIntent: MarkLapIntent(), activityIdentifier: workoutStyle.rawValue)
        } else {
            return .result()
        }
    }
}
