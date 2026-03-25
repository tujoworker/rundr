import Foundation

struct HistoryDateTimeParts: Equatable {
    let dayText: String
    let timeText: String
}

struct HistoryDateRangeParts: Equatable {
    let dayText: String
    let timeText: String
}

enum Formatters {

    private static let relativeDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private static let historyTimeIntervalFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Date

    static func historySessionDateTimeString(
        from date: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let parts = historySessionDateTimeParts(from: date, referenceDate: referenceDate, calendar: calendar)
        return "\(parts.dayText), \(parts.timeText)"
    }

    static func historySessionDateTimeParts(
        from date: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> HistoryDateTimeParts {
        let now = referenceDate
        let dayText: String
        let referenceStart = calendar.startOfDay(for: now)
        let dateStart = calendar.startOfDay(for: date)
        let dayOffset = calendar.dateComponents([.day], from: dateStart, to: referenceStart).day

        if dayOffset == 0 || dayOffset == 1 {
            dayText = relativeDayFormatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            dayText = date.formatted(.dateTime.weekday(.wide))
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            dayText = date.formatted(.dateTime.month(.abbreviated).day())
        } else {
            dayText = date.formatted(.dateTime.month(.abbreviated).day().year())
        }

        let timeText = date.formatted(date: .omitted, time: .shortened)
        return HistoryDateTimeParts(dayText: dayText, timeText: timeText)
    }

    static func historySessionDateRangeString(
        start: Date,
        end: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let parts = historySessionDateRangeParts(start: start, end: end, referenceDate: referenceDate, calendar: calendar)
        return "\(parts.dayText), \(parts.timeText)"
    }

    static func historySessionDateRangeParts(
        start: Date,
        end: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> HistoryDateRangeParts {
        let startParts = historySessionDateTimeParts(from: start, referenceDate: referenceDate, calendar: calendar)
        let durationText = historySessionDurationString(start: start, end: end)
        let timeRangeText = historyTimeIntervalFormatter.string(from: start, to: end)
        let timeText = durationText.isEmpty ? timeRangeText : "\(timeRangeText) (\(durationText))"

        if calendar.isDate(start, inSameDayAs: end) {
            return HistoryDateRangeParts(dayText: startParts.dayText, timeText: timeText)
        } else {
            let endParts = historySessionDateTimeParts(from: end, referenceDate: referenceDate, calendar: calendar)
            return HistoryDateRangeParts(
                dayText: "\(startParts.dayText) - \(endParts.dayText)",
                timeText: timeText
            )
        }
    }

    private static func historySessionDurationString(start: Date, end: Date) -> String {
        let duration = max(end.timeIntervalSince(start), 0)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll

        if duration >= 3600 {
            formatter.allowedUnits = [.hour, .minute]
        } else if duration >= 60 {
            formatter.allowedUnits = [.minute, .second]
        } else {
            formatter.allowedUnits = [.second]
        }

        return formatter.string(from: duration) ?? ""
    }

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

    /// Precision format: 0:00.00 under 10 min, 10:00.00 at 10+ min.
    static func precisionTimeString(from seconds: Double) -> String {
        let clamped = max(seconds, 0)
        let totalSeconds = Int(clamped)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        let hundredths = Int((clamped - Double(totalSeconds)) * 100) % 100
        if minutes < 10 {
            return String(format: "%d:%02d.%02d", minutes, secs, hundredths)
        }
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
        let hasDecimals = meters != floor(meters)
        switch unit {
        case .km:
            if meters >= 1000 {
                return String(format: "%.2f %@", meters / 1000.0, L10n.kmSuffix)
            } else {
                return hasDecimals ? String(format: "%g %@", meters, L10n.mSuffix) : String(format: "%.0f %@", meters, L10n.mSuffix)
            }
        case .miles:
            let miles = meters / 1609.344
            if miles >= 1 {
                return String(format: "%.2f %@", miles, L10n.miSuffix)
            } else {
                let feet = meters * 3.28084
                return feet != floor(feet) ? String(format: "%g %@", feet, L10n.ftSuffix) : String(format: "%.0f %@", feet, L10n.ftSuffix)
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
        guard distanceMeters > 0 && durationSeconds > 0 else { return L10n.dash }
        let divisor: Double = unit == .km ? 1000.0 : 1609.344
        let secondsPerUnit = (durationSeconds / distanceMeters) * divisor
        let minutes = Int(secondsPerUnit) / 60
        let secs = Int(secondsPerUnit) % 60
        let label = unit == .km ? L10n.pacePerKm : L10n.pacePerMi
        return String(format: "%d:%02d\u{2009}%@", minutes, secs, label)
    }

    /// Compact pace format: "4:30" from seconds-per-km, converting to seconds-per-mile when needed.
    static func compactPaceString(secondsPerKm: Double, unit: DistanceUnit) -> String {
        let secondsPerUnit = unit == .km ? secondsPerKm : secondsPerKm * 1.60934
        let minutes = Int(secondsPerUnit) / 60
        let secs = Int(secondsPerUnit) % 60
        let label = unit == .km ? L10n.pacePerKm : L10n.pacePerMi
        return String(format: "%d:%02d\u{2009}%@", minutes, secs, label)
    }

    /// Target display string: "450 m in 1:20".
    static func targetString(segment: DistanceSegment, unit: DistanceUnit) -> String? {
        guard let targetTime = segment.effectiveTargetTimeSeconds else { return nil }
        let time = compactTimeString(from: targetTime)
        if segment.usesOpenDistance {
            return L10n.openTargetDisplay(time)
        }
        let dist = distanceString(meters: segment.distanceMeters, unit: unit)
        return L10n.targetDisplay(dist, time)
    }

    /// One-line summary for a lap: time, distance (if GPS), pace. No lap index.
    static func lapSummaryString(lap: Lap, trackingMode: TrackingMode, unit: DistanceUnit) -> String {
        let time = compactTimeString(from: lap.durationSeconds)
        if lap.lapType == .rest {
            return time
        }
        let pace = paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: unit)
        if trackingMode == .gps {
            let dist = distanceString(meters: lap.distanceMeters, unit: unit)
            return "\(time) • \(dist) • \(pace)"
        }
        if trackingMode == .dual, let gpsDistanceMeters = lap.gpsDistanceMeters, gpsDistanceMeters > 0 {
            let gpsDistance = L10n.gpsDistance(distanceString(meters: gpsDistanceMeters, unit: unit))
            return "\(time) • \(pace) • \(gpsDistance)"
        }
        return "\(time) • \(pace)"
    }

    // MARK: - Heart Rate

    static func heartRateString(bpm: Double?) -> String {
        guard let bpm = bpm else { return L10n.dash }
        return "\(Int(bpm))"
    }
}
