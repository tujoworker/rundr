import XCTest
@testable import Rundr

final class CompanionMetricGridRoutingTests: XCTestCase {

    func testColumnCountReturnsOneForNarrowWidth() {
        XCTAssertEqual(CompanionMetricGridRouting.columnCount(for: 1), 1)
    }

    func testColumnCountExpandsAtExpectedThresholds() {
        let threeColumnWidth =
            (CompanionMetricGridRouting.minimumColumnWidth * 3) + (CompanionMetricGridRouting.columnSpacing * 2)
        let fourColumnWidth =
            (CompanionMetricGridRouting.minimumColumnWidth * 4) + (CompanionMetricGridRouting.columnSpacing * 3)

        XCTAssertEqual(CompanionMetricGridRouting.columnCount(for: threeColumnWidth), 3)
        XCTAssertEqual(CompanionMetricGridRouting.columnCount(for: fourColumnWidth), 4)
    }

    func testRowsKeepIncompleteSecondRowInLeadingColumnsForThreeColumns() {
        let items = Array(0..<5)
        let threeColumnWidth =
            (CompanionMetricGridRouting.minimumColumnWidth * 3) + (CompanionMetricGridRouting.columnSpacing * 2)

        let rows = CompanionMetricGridRouting.rows(for: items, availableWidth: threeColumnWidth)

        XCTAssertEqual(rows, [[0, 1, 2], [3, 4]])
    }

    func testRowsReflowWhenWidthSupportsFourColumns() {
        let items = Array(0..<6)
        let fourColumnWidth =
            (CompanionMetricGridRouting.minimumColumnWidth * 4) + (CompanionMetricGridRouting.columnSpacing * 3)

        let rows = CompanionMetricGridRouting.rows(for: items, availableWidth: fourColumnWidth)

        XCTAssertEqual(rows, [[0, 1, 2, 3], [4, 5]])
    }
}