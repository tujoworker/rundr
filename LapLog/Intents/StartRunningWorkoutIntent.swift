import AppIntents

enum LapLogWorkoutStyle: String, AppEnum {
    case running

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout")
    static let caseDisplayRepresentations: [LapLogWorkoutStyle: DisplayRepresentation] = [
        .running: "Intervals"
    ]
}

struct StartRunningWorkoutIntent: StartWorkoutIntent {
    static let title: LocalizedStringResource = "Start LapLog Intervals"
    static let description = IntentDescription("Start a LapLog intervals workout.")
    static let openAppWhenRun = true
    static let suggestedWorkouts: [StartRunningWorkoutIntent] = [
        .init(style: .running)
    ]

    typealias WorkoutStyle = LapLogWorkoutStyle

    @Parameter(title: "Workout")
    var workoutStyle: LapLogWorkoutStyle

    init() {
        workoutStyle = .running
    }

    init(style: LapLogWorkoutStyle) {
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
