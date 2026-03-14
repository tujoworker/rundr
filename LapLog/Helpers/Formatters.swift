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

    /// Returns a human-readable distance string.
    /// Under 1000m shows meters; 1000m+ shows km with 2 decimals.
    static func distanceString(meters: Double) -> String {
        if meters >= 1000 {
            let km = meters / 1000.0
            return String(format: "%.2f km", km)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    // MARK: - Speed

    static func speedString(metersPerSecond: Double) -> String {
        return String(format: "%.2f m/s", metersPerSecond)
    }

    // MARK: - Heart Rate

    static func heartRateString(bpm: Double?) -> String {
        guard let bpm = bpm else { return "—" }
        return "\(Int(bpm)) bpm"
    }
}
