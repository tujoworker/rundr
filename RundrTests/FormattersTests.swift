import XCTest
@testable import Rundr

final class FormattersTests: XCTestCase {

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) throws -> Date {
        let components = DateComponents(
            calendar: testCalendar,
            timeZone: testCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return try XCTUnwrap(components.date)
    }

    // MARK: - Time Formatting

    func testTimeStringSeconds() {
        XCTAssertEqual(Formatters.timeString(from: 0), "00:00")
        XCTAssertEqual(Formatters.timeString(from: 5), "00:05")
        XCTAssertEqual(Formatters.timeString(from: 59), "00:59")
    }

    func testTimeStringMinutes() {
        XCTAssertEqual(Formatters.timeString(from: 60), "01:00")
        XCTAssertEqual(Formatters.timeString(from: 125), "02:05")
        XCTAssertEqual(Formatters.timeString(from: 3599), "59:59")
    }

    func testTimeStringHours() {
        XCTAssertEqual(Formatters.timeString(from: 3600), "01:00:00")
        XCTAssertEqual(Formatters.timeString(from: 3661), "01:01:01")
        XCTAssertEqual(Formatters.timeString(from: 7384), "02:03:04")
    }

    func testTimeStringNegative() {
        XCTAssertEqual(Formatters.timeString(from: -10), "00:00")
    }

    // MARK: - Compact Time Formatting

    func testCompactTimeStringSeconds() {
        XCTAssertEqual(Formatters.compactTimeString(from: 0), "0:00")
        XCTAssertEqual(Formatters.compactTimeString(from: 2), "0:02")
        XCTAssertEqual(Formatters.compactTimeString(from: 59), "0:59")
    }

    func testCompactTimeStringMinutes() {
        XCTAssertEqual(Formatters.compactTimeString(from: 60), "1:00")
        XCTAssertEqual(Formatters.compactTimeString(from: 90), "1:30")
        XCTAssertEqual(Formatters.compactTimeString(from: 605), "10:05")
    }

    func testCompactTimeStringHours() {
        XCTAssertEqual(Formatters.compactTimeString(from: 3600), "1:00:00")
        XCTAssertEqual(Formatters.compactTimeString(from: 3661), "1:01:01")
    }

    func testCompactTimeStringNegative() {
        XCTAssertEqual(Formatters.compactTimeString(from: -5), "0:00")
    }

    // MARK: - Distance Formatting

    func testDistanceStringMeters() {
        XCTAssertEqual(Formatters.distanceString(meters: 0), "0 m")
        XCTAssertEqual(Formatters.distanceString(meters: 400), "400 m")
        XCTAssertEqual(Formatters.distanceString(meters: 999), "999 m")
    }

    func testDistanceStringKilometers() {
        XCTAssertEqual(Formatters.distanceString(meters: 1000), "1.00 km")
        XCTAssertEqual(Formatters.distanceString(meters: 1500), "1.50 km")
        XCTAssertEqual(Formatters.distanceString(meters: 42195), "42.20 km")
    }

    // MARK: - Speed Formatting

    func testSpeedString() {
        XCTAssertEqual(Formatters.speedString(metersPerSecond: 0), "0.00 m/s")
        XCTAssertEqual(Formatters.speedString(metersPerSecond: 4.35), "4.35 m/s")
        XCTAssertEqual(Formatters.speedString(metersPerSecond: 10.123), "10.12 m/s")
    }

    // MARK: - Heart Rate Formatting

    func testHeartRateStringNil() {
        XCTAssertEqual(Formatters.heartRateString(bpm: nil), "—")
    }

    func testHeartRateStringValue() {
        XCTAssertEqual(Formatters.heartRateString(bpm: 163.0), "163")
        XCTAssertEqual(Formatters.heartRateString(bpm: 72.8), "72")
    }

    // MARK: - Lap Summary Formatting

    func testLapSummaryStringForRestLapShowsOnlyTime() {
        let lap = Lap(
            index: 0,
            startedAt: Date(),
            endedAt: Date().addingTimeInterval(30),
            durationSeconds: 30,
            distanceMeters: 0,
            averageSpeedMetersPerSecond: 0,
            lapType: .rest,
            source: .distanceTap
        )

        XCTAssertEqual(
            Formatters.lapSummaryString(lap: lap, trackingMode: .distanceDistance, unit: .km),
            "0:30"
        )
    }

    func testLapSummaryStringForGPSIncludesTimeDistanceAndPace() {
        let lap = Lap(
            index: 1,
            startedAt: Date(),
            endedAt: Date().addingTimeInterval(240),
            durationSeconds: 240,
            distanceMeters: 1000,
            gpsDistanceMeters: 1000,
            averageSpeedMetersPerSecond: 4.16,
            lapType: .active,
            source: .distanceTap
        )

        XCTAssertEqual(
            Formatters.lapSummaryString(lap: lap, trackingMode: .gps, unit: .km),
            "4:00 • 1.00 km • 4:00\u{2009}/km"
        )
    }

    func testLapSummaryStringForDualIncludesGPSDistanceSummary() {
        let lap = Lap(
            index: 1,
            startedAt: Date(),
            endedAt: Date().addingTimeInterval(200),
            durationSeconds: 200,
            distanceMeters: 400,
            gpsDistanceMeters: 418,
            averageSpeedMetersPerSecond: 2,
            lapType: .active,
            source: .distanceTap
        )

        XCTAssertEqual(
            Formatters.lapSummaryString(lap: lap, trackingMode: .dual, unit: .km),
            "3:20 • 8:20\u{2009}/km • GPS: 418 m"
        )
    }

    // MARK: - History Date Formatting

    func testHistorySessionDateTimeStringUsesTodayLabel() throws {
        let referenceDate = try makeDate(year: 2026, month: 3, day: 19, hour: 12)
        let sessionDate = try makeDate(year: 2026, month: 3, day: 19, hour: 10, minute: 15)

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        let expectedDay = formatter.string(from: sessionDate)
        let expected = "\(expectedDay), \(sessionDate.formatted(date: .omitted, time: .shortened))"

        XCTAssertEqual(
            Formatters.historySessionDateTimeString(from: sessionDate, referenceDate: referenceDate, calendar: testCalendar),
            expected
        )
    }

    func testHistorySessionDateTimePartsSplitDayAndTime() throws {
        let referenceDate = try makeDate(year: 2026, month: 3, day: 19, hour: 12)
        let sessionDate = try makeDate(year: 2026, month: 3, day: 19, hour: 10, minute: 15)

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true

        XCTAssertEqual(
            Formatters.historySessionDateTimeParts(from: sessionDate, referenceDate: referenceDate, calendar: testCalendar),
            HistoryDateTimeParts(
                dayText: formatter.string(from: sessionDate),
                timeText: sessionDate.formatted(date: .omitted, time: .shortened)
            )
        )
    }

    func testHistorySessionDateTimeStringUsesYesterdayLabel() throws {
        let referenceDate = try makeDate(year: 2026, month: 3, day: 19, hour: 12)
        let sessionDate = try makeDate(year: 2026, month: 3, day: 18, hour: 10, minute: 15)

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        let expected = "\(formatter.string(from: sessionDate)), \(sessionDate.formatted(date: .omitted, time: .shortened))"

        XCTAssertEqual(
            Formatters.historySessionDateTimeString(from: sessionDate, referenceDate: referenceDate, calendar: testCalendar),
            expected
        )
    }

    func testHistorySessionDateTimeStringUsesWeekdayInsideCurrentWeek() throws {
        let referenceDate = try makeDate(year: 2026, month: 3, day: 19, hour: 12)
        let sessionDate = try makeDate(year: 2026, month: 3, day: 17, hour: 10, minute: 15)
        let expected = "\(sessionDate.formatted(.dateTime.weekday(.wide))), \(sessionDate.formatted(date: .omitted, time: .shortened))"

        XCTAssertEqual(
            Formatters.historySessionDateTimeString(from: sessionDate, referenceDate: referenceDate, calendar: testCalendar),
            expected
        )
    }

    func testHistorySessionDateTimeStringUsesMonthDayEarlierThisYear() throws {
        let referenceDate = try makeDate(year: 2026, month: 3, day: 19, hour: 12)
        let sessionDate = try makeDate(year: 2026, month: 2, day: 10, hour: 10, minute: 15)
        let expected = "\(sessionDate.formatted(.dateTime.month(.abbreviated).day())), \(sessionDate.formatted(date: .omitted, time: .shortened))"

        XCTAssertEqual(
            Formatters.historySessionDateTimeString(from: sessionDate, referenceDate: referenceDate, calendar: testCalendar),
            expected
        )
    }

    func testHistorySessionDateTimeStringUsesYearForOlderSessions() throws {
        let referenceDate = try makeDate(year: 2026, month: 3, day: 19, hour: 12)
        let sessionDate = try makeDate(year: 2025, month: 12, day: 31, hour: 10, minute: 15)
        let expected = "\(sessionDate.formatted(.dateTime.month(.abbreviated).day().year())), \(sessionDate.formatted(date: .omitted, time: .shortened))"

        XCTAssertEqual(
            Formatters.historySessionDateTimeString(from: sessionDate, referenceDate: referenceDate, calendar: testCalendar),
            expected
        )
    }

    func testHistorySessionDateRangeStringUsesEndTimeOnlyForSameDay() throws {
        let referenceDate = try makeDate(year: 2026, month: 3, day: 19, hour: 12)
        let start = try makeDate(year: 2026, month: 3, day: 19, hour: 10, minute: 0)
        let end = try makeDate(year: 2026, month: 3, day: 19, hour: 11, minute: 5)

        let startDayText = Formatters.historySessionDateTimeParts(
            from: start,
            referenceDate: referenceDate,
            calendar: testCalendar
        ).dayText
        let intervalText = "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        let expected = "\(startDayText), \(intervalText)"

        XCTAssertEqual(
            Formatters.historySessionDateRangeString(start: start, end: end, referenceDate: referenceDate, calendar: testCalendar),
            expected
        )
    }

    func testHistorySessionDateRangePartsUseSharedDayForSameDayRange() throws {
        let referenceDate = try makeDate(year: 2026, month: 3, day: 19, hour: 12)
        let start = try makeDate(year: 2026, month: 3, day: 19, hour: 10, minute: 0)
        let end = try makeDate(year: 2026, month: 3, day: 19, hour: 11, minute: 5)

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        let intervalText = "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"

        XCTAssertEqual(
            Formatters.historySessionDateRangeParts(start: start, end: end, referenceDate: referenceDate, calendar: testCalendar),
            HistoryDateRangeParts(
                dayText: formatter.string(from: start),
                timeText: intervalText
            )
        )
    }

    func testHistorySessionDateRangeStringUsesFullEndContextAcrossDays() throws {
        let referenceDate = try makeDate(year: 2026, month: 3, day: 19, hour: 12)
        let start = try makeDate(year: 2026, month: 3, day: 18, hour: 23, minute: 30)
        let end = try makeDate(year: 2026, month: 3, day: 19, hour: 0, minute: 15)

        let startParts = Formatters.historySessionDateTimeParts(from: start, referenceDate: referenceDate, calendar: testCalendar)
        let endParts = Formatters.historySessionDateTimeParts(from: end, referenceDate: referenceDate, calendar: testCalendar)
        let intervalText = "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        let expected = "\(startParts.dayText) - \(endParts.dayText), \(intervalText)"

        XCTAssertEqual(
            Formatters.historySessionDateRangeString(start: start, end: end, referenceDate: referenceDate, calendar: testCalendar),
            expected
        )
    }
}
