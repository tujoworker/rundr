import Foundation

/// Centralized user-facing strings for localization.
/// Add Norwegian translations in nb.lproj/Localizable.strings
enum L10n {

    // MARK: - PreStart
    static let pressActionButton = String(localized: "Press the Action Button", comment: "PreStart hint")
    static let settings = String(localized: "Settings", comment: "Settings section")
    static let adjustSettings = String(localized: "Adjust Interval", comment: "History setup title")
    static let mode = String(localized: "Mode", comment: "Tracking mode setting")
    static let distance = String(localized: "Distance", comment: "Distance setting")
    static let distanceMeters = String(localized: "Distance (meters)", comment: "Distance input label")
    static let distanceFeet = String(localized: "Distance (feet)", comment: "Distance input label")
    static let unit = String(localized: "Unit", comment: "Distance unit setting")
    static let color = String(localized: "Color", comment: "Primary color setting")
    static let restMode = String(localized: "Rest Mode", comment: "Rest mode setting")
    static let restManual = String(localized: "Manual", comment: "Rest mode: manual")
    static let restAutoDetect = String(localized: "Auto", comment: "Rest mode: auto detect")
    static let distancePlaceholderKm = String(localized: "e.g. 400", comment: "Distance placeholder")
    static let distancePlaceholderMiles = String(localized: "e.g. 1320", comment: "Distance placeholder")
    static let locationRequired = String(localized: "Location Required", comment: "Alert title")
    static let ok = String(localized: "OK", comment: "Alert button")
    static let gpsModeNeedsLocation = String(localized: "GPS mode needs location access. The mode was switched back to Distance.", comment: "Alert message")
    static let cancel = String(localized: "Cancel", comment: "Button")
    static let distanceUnit = String(localized: "Distance Unit", comment: "Dialog title")
    static let primaryColor = String(localized: "Primary Color", comment: "Dialog title")
    static let secondsAbbrev = String(localized: "s", comment: "Seconds unit")
    static let minutesAbbrev = String(localized: "m", comment: "Minutes unit")

    // MARK: - Active Session
    static let deleteLap = String(localized: "Delete Lap", comment: "Dialog title")
    static func lapIndex(_ index: Int) -> String {
        String(format: String(localized: "Lap %d", comment: "Lap label"), index)
    }
    static let restModeStatus = String(localized: "Rest Mode", comment: "Timer label when resting")
    static let endRest = String(localized: "End Rest", comment: "Button")
    static let pause = String(localized: "Pause", comment: "Button")
    static let resume = String(localized: "Resume", comment: "Button")
    static let workoutPaused = String(localized: "Paused", comment: "Timer label when workout is fully paused")
    static let endSession = String(localized: "End", comment: "Button")
    static let delete = String(localized: "Delete", comment: "Button")
    static let active = String(localized: "Active", comment: "Current lap label")

    // MARK: - Pace / Units
    static let pacePerKm = String(localized: "/km", comment: "Pace unit")
    static let pacePerMi = String(localized: "/mi", comment: "Pace unit")
    static let dash = String(localized: "—", comment: "Placeholder for missing value")

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

    // MARK: - Root / Health
    static let sessionNotFound = String(localized: "Session not found", comment: "Error")
    static let lapLogNeeds = String(localized: "LapLog needs:", comment: "Health prompt")
    static let healthAccess = String(localized: "Health Access", comment: "Button")
    static let notNow = String(localized: "Not now", comment: "Button")
    static let healthDataNotAvailable = String(localized: "Health data not available on this device.", comment: "Error")

    // MARK: - Session Detail
    static let session = String(localized: "Session", comment: "Navigation title")
    static let rest = String(localized: "Rest", comment: "Rest lap label")
    static let useSessionSettings = String(localized: "Reuse This Interval", comment: "Button")
    static func loadedFromSession(_ value: String) -> String {
        String(format: String(localized: "Loaded from %@", comment: "History setup subtitle"), value)
    }

    // MARK: - Tracking Mode
    static let gps = String(localized: "GPS", comment: "Tracking mode")
    static let distanceMode = String(localized: "Distance", comment: "Tracking mode")

    // MARK: - Distance Unit
    static let kilometers = String(localized: "Kilometers", comment: "Unit")
    static let miles = String(localized: "Miles", comment: "Unit")

    // MARK: - Primary Color
    static let blue = String(localized: "Blue", comment: "Color")
    static let green = String(localized: "Green", comment: "Color")
    static let yellow = String(localized: "Yellow", comment: "Color")
    static let orange = String(localized: "Orange", comment: "Color")
    static let pink = String(localized: "Pink", comment: "Color")
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
    static let pace = String(localized: "Pace", comment: "Pace target label")
    static let time = String(localized: "Time", comment: "Time target label")
    static let off = String(localized: "Off", comment: "Target off")
    static func targetDisplay(_ distance: String, _ time: String) -> String {
        String(format: String(localized: "%@ in %@", comment: "Target display: distance in time"), distance, time)
    }

    // MARK: - Distance/Unit suffixes for Formatters
    static let kmSuffix = String(localized: "km", comment: "Kilometer unit")
    static let mSuffix = String(localized: "m", comment: "Meter unit")
    static let miSuffix = String(localized: "mi", comment: "Mile unit")
    static let ftSuffix = String(localized: "ft", comment: "Feet unit")
}
