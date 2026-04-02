import Foundation

/// Centralized user-facing strings for localization.
/// Add Norwegian translations in nb.lproj/Localizable.strings
enum L10n {

    // MARK: - PreStart
    static let pressActionButton = String(localized: "Press the Action Button", comment: "PreStart hint")
    static let settings = String(localized: "Settings", comment: "Settings section")
    static let more = String(localized: "More", comment: "PreStart section for settings and app information")
    static let workouts = String(localized: "Workouts", comment: "Companion tab title")
    static let browser = String(localized: "Browse", comment: "Companion tab title")
    static let adjustSettings = String(localized: "Adjust Interval", comment: "History setup title")
    static let browse = String(localized: "Browse", comment: "Browse saved intervals")
    static let workoutPlan = String(localized: "Workout Plan", comment: "Companion workout editor title")
    static let usedWhenStartingOnAppleWatch = String(localized: "Used when you start on Apple Watch.", comment: "Companion current workout summary")
    static let intervalsTitle = String(localized: "Session Plan", comment: "Session plan section title")
    static let myIntervals = String(localized: "My intervals", comment: "Interval library title")
    static let predefined = String(localized: "Predefined", comment: "Predefined interval section")
    static let title = String(localized: "Title", comment: "Preset title label")
    static let optionalTitlePlaceholder = String(localized: "Title (optional)", comment: "Optional preset title placeholder")
    static let noSavedIntervalsYet = String(localized: "No saved intervals yet", comment: "Empty saved intervals state")
    static let savedIntervalsPlaceholderDetail = String(localized: "Open a predefined interval to save your own version.", comment: "Browse empty state guidance for saved intervals")
    static let mode = String(localized: "Tracking Mode", comment: "Tracking mode setting")
    static let distance = String(localized: "Distance", comment: "Distance setting")
    static let editInterval = String(localized: "Edit Interval", comment: "Companion segment editor title")
    static let distanceMeters = String(localized: "Distance (meters)", comment: "Distance input label")
    static let distanceFeet = String(localized: "Distance (feet)", comment: "Distance input label")
    static let distanceMetersShort = String(localized: "Distance (m)", comment: "Short distance input label")
    static let distanceFeetShort = String(localized: "Distance (ft)", comment: "Short distance input label")
    static let distanceType = String(localized: "Distance Type", comment: "Distance mode selector")
    static let fixedDistance = String(localized: "Fixed", comment: "Fixed interval distance")
    static let openDistance = String(localized: "Open", comment: "Open interval distance")
    static let repeats = String(localized: "Repeats", comment: "Segment repeats label")
    static let lastRest = String(localized: "Last Rest", comment: "Segment last rest label")
    static let addLastRest = String(localized: "Add Last Rest", comment: "Button to add a last rest field")
    static let lastRestNeedsRepeatsTitle = String(localized: "Repeats Required", comment: "Alert title when last rest requires repeats")
    static let lastRestNeedsRepeatsMessage = String(localized: "Add repeats to this interval before adding a last rest.", comment: "Alert message when last rest requires repeats")
    static let gpsAlsoEnabledTitle = String(localized: "GPS Required", comment: "Open interval GPS banner title")
    static let gpsAlsoEnabledSubtitle = String(localized: "Open intervals uses GPS to meassure distance. This activity has switched to Dual Mode.", comment: "Open interval GPS banner subtitle")
    static let requestLocationAccess = String(localized: "Enable GPS Access", comment: "Open interval GPS banner button")
    static let unit = String(localized: "Unit", comment: "Distance unit setting")
    static let color = String(localized: "Color", comment: "Primary color setting")
    static let restMode = String(localized: "Rest", comment: "Rest mode setting")
    static let markAsRest = String(localized: "Mark as Rest", comment: "Active session rest button label")
    static let restModeAuto = String(localized: "Mark as Rest (Auto)", comment: "Active session rest button label when auto-detect is on")
    static let restManual = String(localized: "Manual", comment: "Rest mode: manual")
    static let manual = String(localized: "Manual", comment: "Generic manual label")
    static let restAutoDetect = String(localized: "Auto-detect", comment: "Rest mode: auto detect")
    static let distancePlaceholderKm = String(localized: "e.g. 400", comment: "Distance placeholder")
    static let distancePlaceholderMiles = String(localized: "e.g. 1320", comment: "Distance placeholder")
    static let locationRequired = String(localized: "Location Required", comment: "Alert title")
    static let ok = String(localized: "OK", comment: "Alert button")
    static let gpsModeNeedsLocation = String(localized: "GPS-based modes need location access. The mode was switched back to Distance.", comment: "Alert message")
    static let cancel = String(localized: "Cancel", comment: "Button")
    static let distanceUnit = String(localized: "Distance Unit", comment: "Dialog title")
    static let primaryColor = String(localized: "Primary Color", comment: "Dialog title")
    static let done = String(localized: "Done", comment: "Done button")
    static let deleteInterval = String(localized: "Delete Interval", comment: "Button")
    static let secondsAbbrev = String(localized: "s", comment: "Seconds unit")
    static let minutesAbbrev = String(localized: "m", comment: "Minutes unit")

    // MARK: - Active Session
    static let editLap = String(localized: "Edit Lap", comment: "Edit lap sheet title")
    static let lapTreatedAsRest = String(localized: "This lap will be treated as rest.", comment: "Edit lap rest explanation")
    static let deleteLap = String(localized: "Delete Lap", comment: "Dialog title")
    static func lapIndex(_ index: Int) -> String {
        String(format: String(localized: "Lap %d", comment: "Lap label"), index)
    }
    static let restModeStatus = String(localized: "Resting", comment: "Timer label when resting")
    static func restModeStatusWithDuration(_ duration: String) -> String {
        String(format: String(localized: "Resting for %@", comment: "Timer label when resting with a target duration"), duration)
    }
    static let restModePausedStatus = String(format: String(localized: "%@ (%@)", comment: "Timer label when resting and paused"), restModeStatus, workoutPaused)
    static func restModePausedStatusWithDuration(_ duration: String) -> String {
        String(format: String(localized: "%@ (%@)", comment: "Timer label when resting and paused"), restModeStatusWithDuration(duration), workoutPaused)
    }
    static func restDuration(_ seconds: Int) -> String {
        String(format: String(localized: "Rest %ds", comment: "Timer label with rest countdown"), seconds)
    }
    static let endRest = String(localized: "Undo \"Mark as Rest\"", comment: "Active session rest button label when ending rest")
    static let pause = String(localized: "Pause", comment: "Button")
    static let resume = String(localized: "Resume", comment: "Button")
    static let workoutPaused = String(localized: "Paused", comment: "Timer label when workout is fully paused")
    static let endSession = String(localized: "End", comment: "Button")
    static let endWorkout = String(localized: "End Workout", comment: "End workout confirmation title")
    static let areYouSure = String(localized: "Are you sure?", comment: "Confirmation prompt")
    static let delete = String(localized: "Delete", comment: "Button")
    static let active = String(localized: "Active", comment: "Current lap label")

    // MARK: - Pace / Units
    static let pacePerKm = String(localized: "/km", comment: "Pace unit")
    static let pacePerMi = String(localized: "/mi", comment: "Pace unit")
    static let dash = String(localized: "—", comment: "Placeholder for missing value")
    static let lapCardPlaceholder = String(localized: "--", comment: "Placeholder for empty lap card value")

    // MARK: - Home
    static let getReady = String(localized: "Get Ready", comment: "Button")
    static let noSessionsYet = String(localized: "No sessions yet", comment: "Empty state")
    static let loadMore = String(localized: "Load More", comment: "Button")
    static let continueToGetReady = String(localized: "Continue", comment: "Button")
    static func lapsSummary(_ count: Int, _ pace: String) -> String {
        String(format: String(localized: "Laps: %d • %@", comment: "Session summary"), count, pace)
    }
    static func timeSummary(_ time: String, _ distance: String) -> String {
        String(format: String(localized: "Time: %@ • %@", comment: "Session summary"), time, distance)
    }
    static let fromAppleWatch = String(localized: "From Apple Watch", comment: "Companion source badge")
    static let importedSession = String(localized: "Imported Session", comment: "Companion import status title")
    static let importedSessionSummary = String(localized: "Delivered from Apple Watch and saved on iPhone.", comment: "Companion import status summary")
    static let source = String(localized: "Source", comment: "Session source label")
    static let importStatus = String(localized: "Import Status", comment: "Session import status label")
    static let importComplete = String(localized: "Import Complete", comment: "Session import completion label")
    static let sourceUnknown = String(localized: "Unknown Source", comment: "Fallback session source")
    static func importedFromSource(_ source: String) -> String {
        String(format: String(localized: "Imported from %@", comment: "Companion imported source description"), source)
    }

    // MARK: - Root / Health
    static let sessionNotFound = String(localized: "Session not found", comment: "Error")
    static let rundrNeeds = String(localized: "Rundr needs:", comment: "Health prompt")
    static let healthAccess = String(localized: "Health Access", comment: "Button")
    static let notNow = String(localized: "Not now", comment: "Button")
    static let healthDataNotAvailable = String(localized: "Health data not available on this device.", comment: "Error")
    static let healthAccessDenied = String(localized: "Health access was not granted.", comment: "Error shown when Health permissions remain denied")
    static let healthAccessMissingEntitlement = String(localized: "This build is missing Apple Health permission setup.", comment: "Error shown when the app build is missing the HealthKit entitlement")
    static let recoverWorkoutTitle = String(localized: "Resume?", comment: "Recovery prompt title")
    static let recoverWorkoutMessage = String(localized: "Rundr found an unfinished activity. If you continue, it opens paused so you can choose when to resume.", comment: "Recovery prompt message")
    static let resumeWorkout = String(localized: "Continue Workout", comment: "Recovery prompt button")
    static let discardWorkout = String(localized: "Discard Workout", comment: "Recovery prompt button")
    static let status = String(localized: "Status", comment: "Recovery prompt field")
    static let started = String(localized: "Started", comment: "Recovery prompt field")

    // MARK: - Session Detail
    static let session = String(localized: "Session", comment: "Navigation title")
    static let details = String(localized: "Details", comment: "Section heading")
    static let stats = String(localized: "Stats", comment: "Session stats section title")
    static let rest = String(localized: "Rest", comment: "Rest lap label")
    static let laps = String(localized: "Laps", comment: "Laps label")
    static let duration = String(localized: "Duration", comment: "Session duration label")
    static let ended = String(localized: "Ended", comment: "Session ended label")
    static let summary = String(localized: "Summary", comment: "Summary section title")
    static let manualDistance = String(localized: "Manual Distance", comment: "Manual distance label")
    static let gpsDistanceLabel = String(localized: "GPS Distance", comment: "GPS distance label")
    static let manualLabel = String(localized: "Manual", comment: "Manual lap metric label")
    static let gpsLabel = String(localized: "GPS", comment: "GPS lap metric label")
    static let gpsPaceLabel = String(localized: "GPS Pace", comment: "GPS pace label")
    static let averagePaceLabel = String(localized: "Average Pace", comment: "Average pace label")
    static let heartRate = String(localized: "Heart Rate", comment: "Average heart rate label")
    static let targetTimeLabel = String(localized: "Target Time", comment: "Lap target time label")
    static let targetPaceLabel = String(localized: "Target Pace", comment: "Lap target pace label")
    static let useSessionSettings = String(localized: "Use Activity", comment: "Button")
    static let redoActivity = String(localized: "Redo Activity", comment: "Button")
    static let deleteSession = String(localized: "Delete Session", comment: "Button")
    static let deleteSessionConfirmMessage = String(localized: "This session will be permanently deleted.", comment: "Delete session confirmation message")
    static let phoneSyncPendingTitle = String(localized: "Still sending to iPhone", comment: "Watch history: session not yet on phone")
    static let phoneSyncPendingSubtitle = String(localized: "This workout is saved on your Watch. It will appear in Rundr on your phone when your watch and phone connect.", comment: "Watch history: explain pending phone sync")
    static let phoneSyncConfirmedTitle = String(localized: "On your iPhone", comment: "Watch history: session already on phone")
    static let phoneSyncConfirmedSubtitle = String(localized: "Rundr on your iPhone already has this workout.", comment: "Watch history: phone already has session")
    static func loadedFromSession(_ value: String) -> String {
        String(format: String(localized: "Loaded from %@", comment: "History setup subtitle"), value)
    }
    static func presetCountSummary(_ count: Int) -> String {
        String(format: String(localized: "%d saved", comment: "Saved interval count summary"), count)
    }
    static func segmentCount(_ count: Int) -> String {
        String(format: String(localized: "%d segments", comment: "Workout plan segment count"), count)
    }

    // MARK: - Tracking Mode
    static let gps = String(localized: "GPS", comment: "Tracking mode")
    static let dual = String(localized: "Dual", comment: "Tracking mode")
    static let distanceMode = String(localized: "Manual", comment: "Tracking mode")
    static func gpsDistance(_ distance: String) -> String {
        String(format: String(localized: "GPS: %@", comment: "GPS distance summary"), distance)
    }

    // MARK: - Distance Unit
    static let kilometers = String(localized: "Kilometers", comment: "Unit")
    static let miles = String(localized: "Miles", comment: "Unit")

    // MARK: - Primary Color
    static let blue = String(localized: "Blue", comment: "Color")
    static let green = String(localized: "Green", comment: "Color")
    static let yellow = String(localized: "Yellow", comment: "Color")
    static let red = String(localized: "Red", comment: "Color")
    static let pink = String(localized: "Pink", comment: "Color")
    static let violet = String(localized: "Violet", comment: "Color")
    static let white = String(localized: "White", comment: "Color")
    static let dark = String(localized: "Dark", comment: "Color")

    // MARK: - Lap Type
    static let activity = String(localized: "Activity", comment: "Lap type")
    static let restLap = String(localized: "Rest", comment: "Lap type")

    // MARK: - Intents
    static let startIntervals = String(localized: "Start Intervals", comment: "Intent")
    static let startIntervalsWorkout = String(localized: "Start a intervals workout.", comment: "Intent description")
    static let workout = String(localized: "Workout", comment: "Intent parameter")
    static let intervals = String(localized: "Intervals", comment: "Workout style")
    static let lap = String(localized: "Lap", comment: "Intent")

    // MARK: - Target
    static let target = String(localized: "Target", comment: "Target section heading")
    static let pace = String(localized: "Pace", comment: "Pace target label")
    static let time = String(localized: "Time", comment: "Time target label")
    static let off = String(localized: "Off", comment: "Target off")
    static let on = String(localized: "On", comment: "Setting enabled")
    static let alerts = String(localized: "Alerts", comment: "Alerts setting")
    static let lapAlerts = String(localized: "Lap", comment: "Lap alerts setting")
    static let restAlerts = String(localized: "Rest", comment: "Rest alerts setting")
    static let unlimited = String(localized: "Unlimited", comment: "Unlimited repeat count label")
    static func targetDisplay(_ distance: String, _ time: String) -> String {
        String(format: String(localized: "%@ in %@", comment: "Target display: distance in time"), distance, time)
    }
    static func openTargetDisplay(_ time: String) -> String {
        String(format: String(localized: "%@ • %@", comment: "Target display: open interval and time"), openDistance, time)
    }

    // MARK: - Preset Usage
    static func usedCount(_ count: Int) -> String {
        String(format: String(localized: "%dx", comment: "Preset usage count badge"), count)
    }

    // MARK: - Distance/Unit suffixes for Formatters
    static let kmSuffix = String(localized: "km", comment: "Kilometer unit")
    static let mSuffix = String(localized: "m", comment: "Meter unit")
    static let miSuffix = String(localized: "mi", comment: "Mile unit")
    static let ftSuffix = String(localized: "ft", comment: "Feet unit")

    // MARK: - Companion
    static let appearance = String(localized: "Appearance", comment: "Appearance setting")
    static let appearanceSystem = String(localized: "System", comment: "Appearance mode: follow system")
    static let appearanceLight = String(localized: "Light", comment: "Appearance mode: light")
    static let appearanceDark = String(localized: "Dark Mode", comment: "Appearance mode: dark")
    static let waitingForWatch = String(localized: "Waiting for Watch…", comment: "Companion live state when watch connection is stale")
    static let liveOnAppleWatch = String(localized: "Live on Apple Watch", comment: "Companion section title for live workout")
    static let syncedSessions = String(localized: "Sessions", comment: "Companion section title for synced sessions")
    static let noSyncedSessionsYet = String(localized: "Start an intervals session on Apple Watch.", comment: "Companion empty state for synced sessions")
    static func heartRateBPM(_ bpm: Int) -> String {
        String(format: String(localized: "Heart Rate %d bpm", comment: "Heart rate with value"), bpm)
    }
    static let runStateIdle = String(localized: "Idle", comment: "Live workout state")
    static let runStateReady = String(localized: "Ready", comment: "Live workout state")
    static let runStateActive = String(localized: "Active", comment: "Live workout state label")
    static let runStateRest = String(localized: "Rest", comment: "Live workout state label")
    static let runStatePaused = String(localized: "Paused", comment: "Live workout state label")
    static let runStateEnding = String(localized: "Ending", comment: "Live workout state")
    static let runStateEnded = String(localized: "Ended", comment: "Live workout state")
}
