import XCTest
import SwiftUI
import CoreGraphics
@testable import Rundr

final class AppearanceModeTests: XCTestCase {

    func testAppearanceModeResolvedColorSchemeUsesSystemWhenNeeded() {
        XCTAssertEqual(AppearanceMode.system.resolvedColorScheme(systemColorScheme: .dark), .dark)
        XCTAssertEqual(AppearanceMode.system.resolvedColorScheme(systemColorScheme: .light), .light)
    }

    func testAppearanceModeResolvedColorSchemeHonorsExplicitSelection() {
        XCTAssertEqual(AppearanceMode.light.resolvedColorScheme(systemColorScheme: .dark), .light)
        XCTAssertEqual(AppearanceMode.dark.resolvedColorScheme(systemColorScheme: .light), .dark)
    }

    func testAppThemeTracksSelectedPalette() {
        XCTAssertTrue(AppTheme(colorScheme: .dark).isDark)
        XCTAssertFalse(AppTheme(colorScheme: .light).isDark)
    }

    func testAppThemeUsesDifferentPrimaryTextColorsForDarkAndLightModes() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        XCTAssertEqual(try rgbaComponents(for: darkTheme.textPrimary), [1, 1, 1, 1])
        XCTAssertEqual(try rgbaComponents(for: lightTheme.textPrimary), [0, 0, 0, 1])
    }

    func testAppThemeUsesDifferentSurfaceCardColorsForDarkAndLightModes() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.surfaceCard),
            [1, 1, 1, Tokens.Opacity.fillCard],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.surfaceCard),
            [0, 0, 0, 0.08],
            accuracy: 0.001
        )
    }

    func testAppThemeUsesDifferentGradientStartColorsForDarkAndLightModes() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        XCTAssertEqual(try rgbaComponents(for: darkTheme.screenGradientStart), [0, 0, 0, 1])
        XCTAssertEqual(try rgbaComponents(for: lightTheme.screenGradientStart), [1, 1, 1, 1])
    }

    private func rgbaComponents(for color: Color) throws -> [CGFloat] {
        let cgColor = try XCTUnwrap(color.cgColor)
        let converted = try XCTUnwrap(
            cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)
        )
        let components = try XCTUnwrap(converted.components)

        if components.count == 4 {
            return components
        }

        if components.count == 2 {
            return [components[0], components[0], components[0], components[1]]
        }

        XCTFail("Unexpected color component count: \(components.count)")
        return []
    }

    private func assertEqualComponents(
        _ lhs: [CGFloat],
        _ rhs: [CGFloat],
        accuracy: CGFloat = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(lhs.count == rhs.count, file: file, line: line)

        for (lhsComponent, rhsComponent) in zip(lhs, rhs) {
            XCTAssertTrue(abs(lhsComponent - rhsComponent) <= accuracy, file: file, line: line)
        }
    }
}