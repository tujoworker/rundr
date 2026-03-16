import XCTest
@testable import LapLog

final class FormattersTests: XCTestCase {

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
}
