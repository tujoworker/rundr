import Foundation

enum Formatters {

    // MARK: - Time

    /// Formats seconds into HH:MM:SS or MM:SS depending on duration.
    static func timeString(from seconds: Double) -> String {
        let totalSeconds = Int(max(seconds, 0))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    /// Precision format: 00:00.00 – minutes, seconds, and hundredths.
    static func precisionTimeString(from seconds: Double) -> String {
        let clamped = max(seconds, 0)
        let totalSeconds = Int(clamped)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        let hundredths = Int((clamped - Double(totalSeconds)) * 100) % 100
        return String(format: "%02d:%02d.%02d", minutes, secs, hundredths)
    }

    /// Compact format: 0:02, 1:30, 12:05 – no leading zero on minutes unless >= 10.
    static func compactTimeString(from seconds: Double) -> String {
        let totalSeconds = Int(max(seconds, 0))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    // MARK: - Distance

    /// Returns a human-readable distance string respecting the chosen unit.
    static func distanceString(meters: Double, unit: DistanceUnit = .km) -> String {
        switch unit {
        case .km:
            if meters >= 1000 {
                return String(format: "%.2f km", meters / 1000.0)
            } else {
                return String(format: "%.0f m", meters)
            }
        case .miles:
            let miles = meters / 1609.344
            if miles >= 1 {
                return String(format: "%.2f mi", miles)
            } else {
                let feet = meters * 3.28084
                return String(format: "%.0f ft", feet)
            }
        }
    }

    // MARK: - Speed

    static func speedString(metersPerSecond: Double) -> String {
        return String(format: "%.2f m/s", metersPerSecond)
    }

    // MARK: - Pace

    /// Pace as min:sec per unit from distance in meters and duration in seconds.
    static func paceString(distanceMeters: Double, durationSeconds: Double, unit: DistanceUnit = .km) -> String {
        guard distanceMeters > 0 && durationSeconds > 0 else { return "—" }
        let divisor: Double = unit == .km ? 1000.0 : 1609.344
        let secondsPerUnit = (durationSeconds / distanceMeters) * divisor
        let minutes = Int(secondsPerUnit) / 60
        let secs = Int(secondsPerUnit) % 60
        let label = unit == .km ? "/km" : "/mi"
        return String(format: "%d:%02d %@", minutes, secs, label)
    }

    // MARK: - Heart Rate

    static func heartRateString(bpm: Double?) -> String {
        guard let bpm = bpm else { return "—" }
        return "\(Int(bpm))"
    }
}
