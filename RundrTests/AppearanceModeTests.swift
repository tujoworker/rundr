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

    func testAppThemeUsesOriginalSettingsIconsInDarkModeAndNeutralIconsInLightMode() {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        XCTAssertEqual(darkTheme.icon.original, .original)
        XCTAssertEqual(lightTheme.icon.neutral, .neutral)
        XCTAssertEqual(darkTheme.icon.settingsRow, darkTheme.icon.original)
        XCTAssertEqual(lightTheme.icon.settingsRow, lightTheme.icon.neutral)
    }

    func testAppThemeUsesWhiteNeutralTextColorsForDarkAndLightModes() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        XCTAssertEqual(try rgbaComponents(for: darkTheme.text.neutral), [1, 1, 1, 1])
        XCTAssertEqual(try rgbaComponents(for: lightTheme.text.neutral), [1, 1, 1, 1])
    }

    func testAppThemeUsesDifferentNeutralBackgroundColorsForDarkAndLightModes() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.neutral),
            [1, 1, 1, Tokens.Opacity.fillCard],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.neutral),
            [0, 0, 0, 0.08],
            accuracy: 0.001
        )
    }

    func testAppThemeUsesWhiteHistoryBackgroundInLightMode() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.history),
            [1, 1, 1, Tokens.Opacity.fillCard],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.history),
            [1, 1, 1, Tokens.Opacity.fillCard],
            accuracy: 0.001
        )
    }

    func testAppThemeUsesHistoryRestTokens() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.historyRest),
            [1, 1, 1, 1],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.historyRest),
            [1, 1, 1, 1],
            accuracy: 0.001
        )
        XCTAssertEqual(try rgbaComponents(for: darkTheme.text.historyRest), [0, 0, 0, 1])
        XCTAssertEqual(try rgbaComponents(for: lightTheme.text.historyRest), [0, 0, 0, 1])
    }

    func testAppThemeUsesDifferentNeutralInteractionBackgroundColorsForDarkAndLightModes() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.neutralInteraction),
            [1, 1, 1, Tokens.Opacity.fillInput],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.neutralInteraction),
            [0, 0, 0, 0.06],
            accuracy: 0.001
        )
    }

    func testAppThemeUsesButtonSpecificBackgroundTokens() throws {
        let accent = Color(red: 0.8, green: 0.4, blue: 0.2)
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.emphasisAction(accent)),
            [0.8, 0.4, 0.2, Tokens.Opacity.fillAccent],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.emphasisAction(accent)),
            [1, 1, 1, Tokens.Opacity.fillAccent],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.destructiveAction(accent)),
            [0.8, 0.4, 0.2, Tokens.Opacity.fillDestructive],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.destructiveAction(accent)),
            [0, 0, 0, Tokens.Opacity.fillDestructive],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.boldAction),
            [1, 1, 1, Tokens.Opacity.foregroundRest],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.boldAction),
            [1, 1, 1, 1],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: darkTheme.stroke.emphasisAction(accent)),
            [0.8, 0.4, 0.2, Tokens.Opacity.strokeAccent],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.stroke.emphasisAction(accent)),
            [1, 1, 1, Tokens.Opacity.strokeAccent],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: darkTheme.stroke.headerDivider(accent)),
            [0.8, 0.4, 0.2, Tokens.Opacity.strokeAccentStrong],
            accuracy: 0.001
        )
        XCTAssertEqual(try rgbaComponents(for: lightTheme.stroke.headerDivider(accent)), [1, 1, 1, 1])
        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.swipeAction(accent)),
            [0.8, 0.4, 0.2, 1],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.swipeAction(accent)),
            [1, 1, 1, Tokens.Opacity.fillAccent],
            accuracy: 0.001
        )
    }

    func testAppThemeUsesWhiteActiveCardBackgroundInLightMode() throws {
        let accent = Color(red: 0.8, green: 0.4, blue: 0.2)
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.emphasisCard(accent)),
            [0.8, 0.4, 0.2, Tokens.Opacity.fillAccent],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.emphasisCard(accent)),
            [1, 1, 1, Tokens.Opacity.fillAccent],
            accuracy: 0.001
        )
    }

    func testAppThemeUsesWhiteBoldSurfacesAndBlackBoldTextInLightMode() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.bold),
            [1, 1, 1, Tokens.Opacity.foregroundRest],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.bold),
            [1, 1, 1, 1],
            accuracy: 0.001
        )
        XCTAssertEqual(try rgbaComponents(for: darkTheme.text.bold), [0, 0, 0, 1])
        XCTAssertEqual(try rgbaComponents(for: lightTheme.text.bold), [0, 0, 0, 1])
    }

    func testAppThemeUsesSuccessTokens() throws {
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.background.success),
            [0, 0.5019608, 0, Tokens.Opacity.fillCard],
            accuracy: 0.01
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.success),
            [0, 0.5019608, 0, 0.12],
            accuracy: 0.01
        )
        assertEqualComponents(
            try rgbaComponents(for: darkTheme.stroke.success),
            [0, 0.5019608, 0, Tokens.Opacity.strokeAccent],
            accuracy: 0.01
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.stroke.success),
            [0, 0.5019608, 0, 0.28],
            accuracy: 0.01
        )
    }

    func testAppThemeUsesDifferentAppBackgroundColorsForDarkAndLightModes() throws {
        let accent = Color(red: 0.8, green: 0.4, blue: 0.2)
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        XCTAssertEqual(try rgbaComponents(for: darkTheme.background.app(accent)), [0, 0, 0, 1])
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.background.app(accent)),
            [0.8, 0.4, 0.2, 1],
            accuracy: 0.001
        )
    }

    func testAppThemeUsesDarkGradientStartAndLightAccentGradientStart() throws {
        let accent = Color(red: 0.8, green: 0.4, blue: 0.2)
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.appGradientStart(accent: accent)),
            [0, 0, 0, 1],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.appGradientStart(accent: accent)),
            [0.8, 0.4, 0.2, 1],
            accuracy: 0.001
        )
    }

    func testAppThemeUsesDarkGradientEndAndLightAccentGradientEnd() throws {
        let accent = Color(red: 0.8, green: 0.4, blue: 0.2)
        let darkTheme = AppTheme(colorScheme: .dark)
        let lightTheme = AppTheme(colorScheme: .light)

        assertEqualComponents(
            try rgbaComponents(for: darkTheme.appGradientEnd(accent: accent)),
            [0.8, 0.4, 0.2, Tokens.Opacity.fillGradientEnd],
            accuracy: 0.001
        )
        assertEqualComponents(
            try rgbaComponents(for: lightTheme.appGradientEnd(accent: accent)),
            [0.8, 0.4, 0.2, 1],
            accuracy: 0.001
        )
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
