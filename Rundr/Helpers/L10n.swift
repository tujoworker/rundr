import Foundation

/// Centralized user-facing strings for localization.
/// Add Norwegian translations in nb.lproj/Localizable.strings
enum L10n {

    // MARK: - PreStart
    static let pressActionButton = String(localized: "Press the Action Button", comment: "PreStart hint")
    static let settings = String(localized: "Settings", comment: "Settings section")
    static let preferences = String(localized: "Preferences", comment: "Section, tab, and screen title for app settings and related information")
    static let syncAppearanceMode = String(localized: "Sync", comment: "Companion preference toggle title for syncing appearance mode")
    static let syncAppearanceModeDetail = String(localized: "When off, iPhone and Apple Watch keep separate appearance settings.", comment: "Companion preference toggle description for syncing appearance mode")
    static let workouts = String(localized: "Workouts", comment: "Companion tab title")
    static let browser = String(localized: "Browse", comment: "Companion tab title")
    static let adjustSettings = String(localized: "Adjust Interval", comment: "History setup title")
    static let browse = String(localized: "Browse", comment: "Browse saved intervals")
    static let workoutPlan = String(localized: "Workout Plan", comment: "Companion workout editor title")
    static let usedWhenStartingOnAppleWatch = String(localized: "Used when you start on Apple Watch.", comment: "Companion current workout summary")
    static let intervalsTitle = String(localized: "Session Plan", comment: "Session plan section title")
    static let myIntervals = String(localized: "My intervals", comment: "Interval library title")
    static let newInterval = String(localized: "New Interval", comment: "Title for creating a new interval preset")
    static let addInterval = String(localized: "Add Interval", comment: "Accessibility label for adding a new interval preset")
    static let predefined = String(localized: "Predefined", comment: "Predefined interval section")
    static let title = String(localized: "Title", comment: "Preset title label")
    static let optionalTitlePlaceholder = String(localized: "Title (optional)", comment: "Optional preset title placeholder")
    static let optionalDescriptionPlaceholder = String(localized: "Description (optional)", comment: "Optional preset description placeholder")
    static let predefinedFortyFiveFifteensTitle = String(localized: "45/15", comment: "Predefined interval title")
    static let predefinedFourByFourTitle = String(localized: "4x4 Intervals", comment: "Predefined interval title")
    static let predefinedThresholdSixesTitle = String(localized: "Threshold 6-Min Reps", comment: "Predefined interval title")
    static let predefinedThousandRepeatsTitle = String(localized: "6 x 1000 m", comment: "Predefined interval title")
    static let predefinedThirtyFifteensTitle = String(localized: "30/15", comment: "Predefined interval title")
    static let predefinedOverUnderTitle = String(localized: "Over/Under", comment: "Predefined interval title")
    static let predefinedPyramidTitle = String(localized: "Pyramid", comment: "Predefined interval title")
    static let predefinedFourHundredRepeatsTitle = String(localized: "10 x 400 m with rest", comment: "Predefined interval title")
    static let predefinedFourHundredRepeatsNoRestTitle = String(localized: "10 x 400 m without rest", comment: "Predefined interval title")
    static let predefinedStructuredFartlekTitle = String(localized: "Structured Fartlek", comment: "Predefined interval title")
    static let predefinedLongTwelvesTitle = String(localized: "Long Intervals", comment: "Predefined interval title")
    static let predefinedFortyFiveFifteensDescription = String(localized: "20-30 x (45s / 15s), continuous or 2 sets. Maximum threshold time with micro-recovery. Core Norwegian method.", comment: "Predefined interval description")
    static let predefinedFourByFourDescription = String(localized: "4 x 4 min / 3 min active recovery (1-2 sets). Gold standard for VO2max. Very time-efficient.", comment: "Predefined interval description")
    static let predefinedThresholdSixesDescription = String(localized: "5 x 6 min / 1 min active recovery. Stable, controlled threshold work. High volume without overload.", comment: "Predefined interval description")
    static let predefinedThousandRepeatsDescription = String(localized: "6 x 1000 m / 90s active recovery (or 2x3). Race pace strength plus aerobic power. Easy to track progress.", comment: "Predefined interval description")
    static let predefinedThirtyFifteensDescription = String(localized: "2-3 sets of 10 x (30s / 15s). High VO2max stimulus without full exhaustion.", comment: "Predefined interval description")
    static let predefinedOverUnderDescription = String(localized: "4 x 8 min alternating 1 min over / 1 min under. Trains lactate handling and pace changes.", comment: "Predefined interval description")
    static let predefinedPyramidDescription = String(localized: "1-2-3-4-3-2-1 min with equal rest, repeat. Covers multiple intensities in one session.", comment: "Predefined interval description")
    static let predefinedFourHundredRepeatsDescription = String(localized: "10 x 400 m / 60-90s active recovery, split sets optional. Speed plus running economy. Classic and effective.", comment: "Predefined interval description")
    static let predefinedFourHundredRepeatsNoRestDescription = String(localized: "10 x 400 m continuous, no rest between reps. Trains pace control and relaxed form under accumulating fatigue.", comment: "Predefined interval description")
    static let predefinedStructuredFartlekDescription = String(localized: "45 min run with fixed surges, for example 1-2 min every 5-10 min. Controlled variation. Great for outdoor terrain.", comment: "Predefined interval description")
    static let predefinedLongTwelvesDescription = String(localized: "3 x 10-15 min / 2-3 min active recovery. Marathon-specific strength and sustained threshold work.", comment: "Predefined interval description")
    static let noSavedIntervalsYet = String(localized: "No saved intervals yet", comment: "Empty saved intervals state")
    static let savedIntervalsPlaceholderDetail = String(localized: "Open a predefined interval to save your own version.", comment: "Browse empty state guidance for saved intervals")
    static let noSessionPlanIntervalsTitle = String(localized: "No intervals yet", comment: "Empty current session plan title")
    static let noSessionPlanIntervalsDetail = String(localized: "Tap + to add your first interval.", comment: "Empty current session plan detail")
    static let mode = String(localized: "Tracking Mode", comment: "Tracking mode setting")
    static let distance = String(localized: "Distance", comment: "Distance setting")
    static let editInterval = String(localized: "Edit Interval", comment: "Companion segment editor title")
    static let distanceMeters = String(localized: "Distance (meters)", comment: "Distance input label")
    static let distanceFeet = String(localized: "Distance (feet)", comment: "Distance input label")
    static let distanceMetersShort = String(localized: "Distance (m)", comment: "Short distance input label")
    static let distanceFeetShort = String(localized: "Distance (ft)", comment: "Short distance input label")
    static let intervalType = String(localized: "Interval Type", comment: "Interval mode selector")
    static let distanceInterval = String(localized: "Distance", comment: "Distance-based interval type")
    static let timeInterval = String(localized: "Time", comment: "Time-based interval type")
    static let segmentName = title
    static let optionalSegmentNamePlaceholder = String(localized: "(optional)", comment: "Optional segment title placeholder")
    static let activeRecovery = String(localized: "Active Recovery", comment: "Default segment name for easier running")
    static let run = String(localized: "Run", comment: "Default segment name for work interval")
    static let sprint = String(localized: "Sprint", comment: "Default segment name for faster running")
    static let surge = String(localized: "Surge", comment: "Default segment name for fartlek surge")
    static let threshold = String(localized: "Threshold", comment: "Default segment name for threshold interval")
    static let distanceType = intervalType
    static let fixedDistance = distanceInterval
    static let openDistance = timeInterval
    static let repeats = String(localized: "Repeats", comment: "Segment repeats label")
    static let lastRest = String(localized: "Last Rest", comment: "Segment last rest label")
    static let addLastRest = String(localized: "Add Last Rest", comment: "Button to add a last rest field")
    static let reorder = String(localized: "Reorder", comment: "Button to enter interval reordering mode")
    static let lastRestNeedsRepeatsTitle = String(localized: "Repeats Required", comment: "Alert title when last rest requires repeats")
    static let lastRestNeedsRepeatsMessage = String(localized: "Add repeats to this interval before adding a last rest.", comment: "Alert message when last rest requires repeats")
    static let gpsAlsoEnabledTitle = String(localized: "GPS Required", comment: "Open interval GPS banner title")
    static let gpsAlsoEnabledSubtitle = String(localized: "Time intervals use GPS to measure distance.", comment: "Time interval GPS banner subtitle")
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
    static let gpsModeNeedsLocation = String(localized: "Time intervals need location access. The interval was switched back to Distance.", comment: "Alert message")
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
    static let activeRecoveryModeStatus = String(localized: "Active Recovery", comment: "Timer label when active recovery is in progress")
    static func activeRecoveryModeStatusWithDuration(_ duration: String) -> String {
        String(format: String(localized: "Active Recovery for %@", comment: "Timer label when active recovery has a target duration"), duration)
    }
    static let restModePausedStatus = String(format: String(localized: "%@ (%@)", comment: "Timer label when resting and paused"), restModeStatus, workoutPaused)
    static func restModePausedStatusWithDuration(_ duration: String) -> String {
        String(format: String(localized: "%@ (%@)", comment: "Timer label when resting and paused"), restModeStatusWithDuration(duration), workoutPaused)
    }
    static let activeRecoveryModePausedStatus = String(format: String(localized: "%@ (%@)", comment: "Timer label when active recovery is paused"), activeRecoveryModeStatus, workoutPaused)
    static func activeRecoveryModePausedStatusWithDuration(_ duration: String) -> String {
        String(format: String(localized: "%@ (%@)", comment: "Timer label when active recovery with a target duration is paused"), activeRecoveryModeStatusWithDuration(duration), workoutPaused)
    }
    static func restDuration(_ seconds: Int) -> String {
        String(format: String(localized: "Rest %ds", comment: "Timer label with rest countdown"), seconds)
    }
    static let endRest = String(localized: "Undo \"Mark as Rest\"", comment: "Active session rest button label when ending rest")
    static let endActiveRecovery = String(localized: "End Active Recovery", comment: "Active session button label when ending active recovery")
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
    static let useSessionSettings = String(localized: "Use Session Plan", comment: "Button")
    static let useActivityConfirmationTitle = String(localized: "Use this plan?", comment: "Confirmation title before applying a session plan")
    static let useActivityConfirmationMessage = String(localized: "This replaces your current Session Plan.", comment: "Confirmation message before applying a session plan")
    static let reusePlan = String(localized: "Reuse Plan", comment: "Watch session detail action")
    static let showMatchingSessions = String(localized: "Show Matching", comment: "History session detail action")
    static let useItNow = String(localized: "Use it now", comment: "Companion Adjust Interval action")
    static let sharePlan = String(localized: "Share Plan", comment: "Companion plan sharing action")
    static let shareSession = String(localized: "Share Session", comment: "Companion session sharing action")
    static let importFile = String(localized: "Import File", comment: "Companion import action")
    static let planImportedTitle = String(localized: "Plan Imported", comment: "Companion import success title for plans")
    static let planImportedMessage = String(localized: "The plan was added to My intervals.", comment: "Companion import success message for plans")
    static let sessionImportedTitle = String(localized: "Session Imported", comment: "Companion import success title for sessions")
    static let sessionImportedMessage = String(localized: "The session was added to your history.", comment: "Companion import success message for sessions")
    static let transferFailedTitle = String(localized: "Couldn't Open File", comment: "Companion import failure title")
    static let transferFailedMessage = String(localized: "This file could not be imported.", comment: "Companion import failure message")
    static let shareFailedTitle = String(localized: "Couldn't Share", comment: "Companion share failure title")
    static let shareFailedMessage = String(localized: "This item could not be prepared for sharing.", comment: "Companion share failure message")
    static let redoActivity = String(localized: "Reuse Session Plan", comment: "Button")
    static let matchingSessions = String(localized: "Matching Sessions", comment: "History screen title")
    static let noOtherMatchingSessionsYet = String(localized: "No other matching sessions yet", comment: "History matching sessions empty state")
    static let thisSession = String(localized: "This Session", comment: "Session detail action menu title")
    static let more = String(localized: "More", comment: "Menu button")
    static let yes = String(localized: "Yes", comment: "Confirmation button")
    static let deletePlan = String(localized: "Delete Plan", comment: "Button")
    static let deletePlanConfirmMessage = String(localized: "This plan will be permanently deleted.", comment: "Delete plan confirmation message")
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
    static func repeatSummary(_ count: Int, _ value: String) -> String {
        String(format: String(localized: "%d × %@", comment: "Workout segment repeats summary"), count, value)
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
    static let gold = String(localized: "Gold", comment: "Color")
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
    static func segmentSummary(_ name: String, _ value: String) -> String {
        String(format: String(localized: "%@ • %@", comment: "Named interval summary"), name, value)
    }
    static func openTargetDisplay(_ time: String) -> String {
        segmentSummary(timeInterval, time)
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
    static let noSyncedSessionsYet = String(localized: "Start an interval session on Apple Watch.", comment: "Companion empty state for synced sessions")
    static let other = String(localized: "Other", comment: "Companion preferences section title")
    static let help = String(localized: "Help", comment: "Companion preferences section and screen title")
    static let aboutRundr = String(localized: "About Rundr", comment: "Companion preferences destination title")
    static let intro = String(localized: "Intro", comment: "Companion info screen title")
    static let about = String(localized: "About", comment: "Companion info screen title")
    static let privacyPolicy = String(localized: "Privacy Policy", comment: "Companion legal screen title")
    static let termsOfUse = String(localized: "Terms of Use", comment: "Companion legal screen title")
    static let aboutRundrSummary = String(localized: "A quick intro to how Rundr fits around your Apple Watch runs.", comment: "Companion info hub footer")
    static let introStartOnWatchTitle = String(localized: "Start where it matters", comment: "Companion intro page title")
    static let introStartOnWatchBody = String(localized: "Build your Session Plan on iPhone, or load one from a predefined list, then head to Apple Watch when you are ready to run.", comment: "Companion intro page body")
    static let introPlanTitle = String(localized: "Plan with precision", comment: "Companion intro page title")
    static let introPlanBody = String(localized: "Use your Session Plan for precise manual distance, or keep it together with GPS in Dual.", comment: "Companion intro page body")
    static let introLapsTitle = String(localized: "Mark every lap", comment: "Companion intro page title")
    static let introLapsBody = String(localized: "Each lap should be marked with a button press on Apple Watch, or with the Action Button when your watch supports it. That keeps your workout structure clean and stores the laps in Apple Health.", comment: "Companion intro page body")
    static let introRestTitle = String(localized: "Rest belongs to the lap flow", comment: "Companion intro page title")
    static let introRestBody = String(localized: "Rest is tied to a lap, so your workout history stays readable. Rundr can also detect rest automatically, which helps when you want the watch to follow the rhythm of the session with less manual work.", comment: "Companion intro page body")
    static let introSyncAndRepeatTitle = String(localized: "Bring good sessions back", comment: "Companion intro page title")
    static let introSyncAndRepeatBody = String(localized: "When the run is done, your session is waiting on iPhone for review. Reuse the ones that worked, adjust the ones that did not, and keep moving without rebuilding everything from scratch.", comment: "Companion intro page body")
    static let aboutRundrHeadline = String(localized: "Rundr is built for interval days.", comment: "Companion about headline")
    static let aboutRundrBodyOne = String(localized: "It is a running app designed around Apple Watch first, with iPhone handling the setup and the follow-up. The goal is simple: make structured runs feel easier to start, easier to follow, and easier to return to.", comment: "Companion about body")
    static let aboutFlexibleSessionsTitle = String(localized: "Flexible when your workout is not one-size-fits-all", comment: "Companion about card title")
    static let aboutFlexibleSessionsBody = String(localized: "You can build distance intervals, time intervals, pacing goals, rest blocks, and repeat structures that match the way you actually train. If a session works well, save it and bring it back later.", comment: "Companion about card body")
    static let aboutKeepMomentumTitle = String(localized: "Made to keep momentum", comment: "Companion about card title")
    static let aboutKeepMomentumBody = String(localized: "Rundr keeps planning, running, and reviewing connected. Set things up on iPhone, run from Apple Watch, then come back to your synced history when you want to repeat a favorite session or tune the next one.", comment: "Companion about card body")
    static let helpOverviewTitle = String(localized: "Overview", comment: "Companion help table of contents title")
    static let example = String(localized: "Example", comment: "Help card callout label")
    static let tip = String(localized: "Tip", comment: "Help card callout label")
    static let helpSessionPlanTitle = String(localized: "Session Plan", comment: "Companion help card title")
    static let helpSessionPlanBody = String(localized: "Rundr keeps one current Session Plan. Loading a plan from predefined session plans or from a past session in History replaces the one you have now.", comment: "Companion help card body")
    static let helpSessionPlanExample = String(localized: "Load last week's 6 × 400 m from History, then adjust one rest before your next run.", comment: "Companion help card example")
    static let helpSharingTitle = String(localized: "Sharing", comment: "Companion help card title")
    static let helpSharingBody = String(localized: "Rundr exports plans and past sessions as files from the iPhone share sheet. Use Share Plan in Adjust Interval to send a plan, or Share Session in a past session detail view to send a session.", comment: "Companion help card body")
    static let helpSharingSendHeading = String(localized: "Send", comment: "Companion help section heading")
    static let helpSharingSendBody = String(localized: "On iPhone, Apple's share sheet shows the available ways to send the file. Apple documents that AirDrop can send documents to nearby Apple devices, and that AirDrop requires Wi-Fi and Bluetooth to be turned on.", comment: "Companion help section body")
    static let helpSharingReceiveHeading = String(localized: "Receive", comment: "Companion help section heading")
    static let helpSharingReceiveBody = String(localized: "Apple documents that you accept AirDrop transfers from the AirDrop notification, and that some received files may be saved in the Files app. In Rundr, you can import a received Rundr file from More > Import File.", comment: "Companion help section body")
    static let helpSharingReceiveExample = String(localized: "If the file is saved in Files instead of opening in Rundr, open Rundr and use More > Import File.", comment: "Companion help card example")
    static let helpSharingTip = String(localized: "For AirDrop, Apple says the devices must be within 30 feet (10 meters), both devices need Wi-Fi and Bluetooth turned on, and the receiver must allow Contacts Only or Everyone for 10 Minutes.", comment: "Companion help card tip")
    static let helpRestTitle = String(localized: "Mark as Rest", comment: "Companion help card title")
    static let helpRestBody = String(localized: "Mark as Rest turns the current lap into rest. That rest stays attached to the lap you just finished, so it remains part of the workout.", comment: "Companion help card body")
    static let helpRestTimedHeading = String(localized: "With Timed Rest", comment: "Companion help section heading")
    static let helpRestTimedBody = String(localized: "Rundr starts rest after the lap and warns in the last 5 seconds if Rest Alerts is enabled in Settings. When passed, the next lap does not start by itself. The target rest is a guide, and you still decide when the next lap begins.", comment: "Companion help section body")
    static let helpRestActiveRecoveryHeading = String(localized: "With Active Recovery", comment: "Companion help section heading")
    static let helpRestActiveRecoveryBody = String(localized: "Active recovery works like recovery time instead of a full work lap. Rundr tracks the recovery in the workout, but keeps active totals and average pace focused on the hard intervals.", comment: "Companion help section body")
    static let helpRestTip = String(localized: "Use Manual when you want to choose exactly when Mark as Rest starts and ends. Use Auto-detect when you want Rundr to enter rest after you stop and end it again when you move.", comment: "Companion help card tip")
    static let helpAutoRestTitle = String(localized: "How Auto-detect Works", comment: "Companion help card title")
    static let helpAutoRestBody = String(localized: "Auto Rest marks the current lap as rest after you stop moving. That rest stays attached to the same lap. Rundr does not create a new lap by itself. The next lap starts when you press lap.", comment: "Companion help card body")
    static let helpAutoRestExample = String(localized: "Finish a 400 m rep, stop at the rail, and the current lap becomes rest. When you are ready for the next rep, press lap to start the next lap.", comment: "Companion help card example")
    static let helpActiveRecoveryTitle = String(localized: "Active Recovery", comment: "Companion help card title")
    static let helpActiveRecoveryBody = String(localized: "Use Active Recovery when you want the recovery between hard intervals to stay part of the planned interval instead of becoming a separate rest block.", comment: "Companion help card body")
    static let helpActiveRecoveryTrackingHeading = String(localized: "How Rundr Tracks It", comment: "Companion help section heading")
    static let helpActiveRecoveryTrackingBody = String(localized: "Rundr tracks active recovery as recovery time inside the interval. It is still recorded in the workout, while active totals and average pace stay focused on the harder work portions.", comment: "Companion help section body")
    static let helpActiveRecoveryUseHeading = String(localized: "When to Use It", comment: "Companion help section heading")
    static let helpActiveRecoveryUseBody = String(localized: "Choose Active Recovery for jog or float recoveries where you want a timed easy segment between repeats. Choose Rest when you want a stopped or separate rest block instead.", comment: "Companion help section body")
    static let helpActiveRecoveryExample = String(localized: "Example: 6 x 400 m with 60 s active recovery lets each recovery stay attached to the repeat instead of creating a separate rest lap.", comment: "Companion help card example")
    static let helpIntervalTypeTitle = String(localized: "Interval Type", comment: "Companion help card title")
    static let helpIntervalTypeDistanceHeading = String(localized: "Distance", comment: "Companion help section heading")
    static let helpIntervalTypeDistanceBody = String(localized: "Use Distance when the lap has a known distance, like 400 m or 1 km.", comment: "Companion help section body")
    static let helpIntervalTypeTimeHeading = String(localized: "Time", comment: "Companion help section heading")
    static let helpIntervalTypeTimeBody = String(localized: "Use Time when you want to define how long the lap should last, rather than how far it should be.", comment: "Companion help section body")
    static let helpIntervalTypeTimeExample = String(localized: "Choose Time for 45 s with 15 s rest, or name it Active Recovery for an easier segment.", comment: "Companion help card example")
    static let helpDistanceTypeTitle = helpIntervalTypeTitle
    static let helpDistanceTypeFixedHeading = helpIntervalTypeDistanceHeading
    static let helpDistanceTypeFixedBody = helpIntervalTypeDistanceBody
    static let helpDistanceTypeOpenHeading = helpIntervalTypeTimeHeading
    static let helpDistanceTypeOpenBody = helpIntervalTypeTimeBody
    static let helpDistanceTypeOpenExample = helpIntervalTypeTimeExample
    static let helpTrackingModeTitle = String(localized: "Tracking Mode", comment: "Companion help card title")
    static let helpTrackingModeManualHeading = String(localized: "Manual", comment: "Companion help section heading")
    static let helpTrackingModeManualBody = String(localized: "Manual uses your Session Plan and manual lap presses without GPS distance. Use it for distance intervals when you want full control and precise measurement and statistics.", comment: "Companion help section body")
    static let helpTrackingModeDualHeading = String(localized: "Dual", comment: "Companion help section heading")
    static let helpTrackingModeDualBody = String(localized: "Dual keeps the Session Plan and also records GPS distance. Use it when you want time-based laps. Time intervals need GPS, so Rundr uses Dual there.", comment: "Companion help section body")
    static let helpAppleHealthTitle = String(localized: "Apple Health", comment: "Companion help card title")
    static let helpAppleHealthBody = String(localized: "Apple Health lets Rundr save workouts, laps, heart rate, energy, and GPS routes when available, and read the workout data it needs back. Turn it on when you want your runs to stay in Apple's fitness history.", comment: "Companion help card body")
    static let helpAppleHealthExample = String(localized: "Enable Health access if you want one session to appear in Rundr, Health, and Fitness instead of living only inside the app.", comment: "Companion help card example")
    static let helpAppleActivityTitle = String(localized: "Apple Activity", comment: "Companion help card title")
    static let helpAppleActivityBody = String(localized: "Your laps and workout details can also appear in Apple's Activity and Fitness views because Rundr saves the session as a workout with interval activities. That is useful for sharing, checking the route, or reviewing the workout outside Rundr.", comment: "Companion help card body")
    static let helpAppleActivityTip = String(localized: "After syncing, you can open the workout in Apple's Activity or Fitness view, share it from there, or import it into other fitness apps that support it.", comment: "Companion help card tip")
    static let privacyWhatRundrStoresTitle = String(localized: "What Rundr Stores", comment: "Privacy Policy section title")
    static let privacyWhatRundrStoresBody = String(localized: "Rundr can store your session plans, workout history, app settings, and ongoing workout state on your devices. If you allow Apple Health access, Rundr can read and write workout data such as workouts, laps, heart rate, active energy, running distance, body mass used for calorie estimates, and GPS route data when available.", comment: "Privacy Policy section body")
    static let privacyHowRundrUsesDataTitle = String(localized: "How Rundr Uses Data", comment: "Privacy Policy section title")
    static let privacyHowRundrUsesDataBody = String(localized: "Rundr uses this data to run structured workouts, show your history, restore unfinished sessions, calculate workout metrics, sync between Apple Watch and iPhone, and save workouts back to Apple Health when you choose to enable that integration.", comment: "Privacy Policy section body")
    static let privacyStorageAndSyncTitle = String(localized: "Storage and Sync", comment: "Privacy Policy section title")
    static let privacyStorageAndSyncBody = String(localized: "Rundr does not require an account. Based on the current app design, your workout data is stored locally on your devices and transferred between Apple Watch and iPhone using Apple's system frameworks. Rundr does not use third-party advertising or analytics SDKs.", comment: "Privacy Policy section body")
    static let privacyPermissionsTitle = String(localized: "Permissions and Choices", comment: "Privacy Policy section title")
    static let privacyPermissionsBody = String(localized: "You can decide whether to grant Health and location access. If you deny permissions, features such as GPS distance, route recording, heart-rate display, calorie estimates, and Apple Health saving may be limited or unavailable. You can change permissions later in Apple's Settings app.", comment: "Privacy Policy section body")
    static let termsScopeTitle = String(localized: "Using Rundr", comment: "Terms of Use section title")
    static let termsScopeBody = String(localized: "Rundr is a fitness and workout planning app for structured running sessions on Apple Watch and iPhone. It is provided for personal use and does not promise specific training results, uninterrupted availability, or error-free data.", comment: "Terms of Use section body")
    static let termsMedicalTitle = String(localized: "Not Medical Advice", comment: "Terms of Use section title")
    static let termsMedicalBody = String(localized: "Rundr is not medical advice and is not intended to diagnose, treat, monitor, or prevent illness or injury. Health and workout data can be incomplete, delayed, or inaccurate. Speak with a qualified medical professional before relying on the app for health or training decisions.", comment: "Terms of Use section body")
    static let termsSafetyTitle = String(localized: "Train Safely", comment: "Terms of Use section title")
    static let termsSafetyBody = String(localized: "You are responsible for using Rundr safely, staying aware of traffic, surfaces, weather, surroundings, and your own condition, and following local laws and rules wherever you train. Stop using the app immediately if you feel pain, dizziness, distress, or that continued exercise may be unsafe.", comment: "Terms of Use section body")
    static let termsResponsibilityTitle = String(localized: "Your Responsibility", comment: "Terms of Use section title")
    static let termsResponsibilityBody = String(localized: "You use Rundr at your own risk. To the fullest extent permitted by law, you are responsible for your training choices and for any accident, injury, damage, loss, or other harmful event that happens while using the app.", comment: "Terms of Use section body")
    static let termsAvailabilityTitle = String(localized: "Availability and Updates", comment: "Terms of Use section title")
    static let termsAvailabilityBody = String(localized: "Some features depend on Apple Watch, Apple Health, location services, and other Apple systems being available. Features may change over time. If these terms are updated in a future release, continued use of Rundr means you accept the updated terms.", comment: "Terms of Use section body")
    static func introPageLabel(_ current: Int, _ total: Int) -> String {
        String(format: String(localized: "Page %d of %d", comment: "Companion intro page position label"), current, total)
    }
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
