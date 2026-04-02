import SwiftUI

// MARK: - App Theme

/// Semantic color and style tokens organised into three groups:
/// **Background**, **Stroke**, and **Text**.
///
/// Each group contains a small set of named levels:
/// - `neutral`  – default / content containers
/// - `subtle`   – reduced emphasis (text only)
/// - `emphasis`  – accent-tinted, takes an accent `Color`
/// - `bold`     – high-contrast / inverted
/// - `app`      – screen-level background (background only)
///
/// Use `@Environment(\.appTheme)` in views to access the active theme.
struct AppTheme {
    let colorScheme: ColorScheme
    private let successBaseColor = Color(red: 0, green: 0.5019608, blue: 0)

    var isDark: Bool { colorScheme == .dark }

    // MARK: - Grouped Tokens

    var background: BackgroundTokens { .init(isDark: isDark, successBaseColor: successBaseColor) }
    var stroke: StrokeTokens { .init(isDark: isDark, successBaseColor: successBaseColor) }
    var text: TextTokens { .init(isDark: isDark, successBaseColor: successBaseColor) }
    var icon: IconTokens { .init(isDark: isDark) }

    // MARK: Background

    struct BackgroundTokens {
        fileprivate let isDark: Bool
        fileprivate let successBaseColor: Color

        /// Screen / view background.
        func app(_ accent: Color) -> Color { isDark ? .black : .white }

        /// Cards, input fields, containers.
        var neutral: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.fillCard)
                : .white.opacity(0.84)
        }

        /// History cards and session detail containers.
        var history: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.fillCard)
                : .white.opacity(0.92)
        }

        /// Floating status badges and small callouts.
        var statusBadge: Color {
            isDark ? .white : .white.opacity(0.96)
        }

        /// Rest rows within history surfaces.
        var historyRest: Color {
            .white
        }

        /// Interactive controls: buttons, toggles, tappable fields.
        var neutralAction: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.fillCard)
                : .white.opacity(0.78)
        }

        /// Interactive rows and cards with embedded controls.
        var neutralInteraction: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.fillInput)
                : .white.opacity(0.72)
        }

        /// Accent-tinted buttons and primary actions.
        func emphasisAction(_ accent: Color) -> Color {
            isDark
                ? accent.opacity(Tokens.Opacity.fillAccent)
                : accent
        }

        /// Destructive action backgrounds.
        func destructiveAction(_ accent: Color) -> Color {
            isDark
                ? accent.opacity(Tokens.Opacity.fillDestructive)
                : accent.opacity(0.12)
        }

        /// Success surfaces, such as confirmation or guidance banners.
        var success: Color {
            isDark
                ? successBaseColor.opacity(Tokens.Opacity.fillCard)
                : successBaseColor.opacity(0.12)
        }

        /// Accent-tinted surfaces (buttons, banners).
        func emphasis(_ accent: Color) -> Color {
            accent.opacity(Tokens.Opacity.fillAccent)
        }

        /// Active-session lap cards.
        func emphasisCard(_ accent: Color) -> Color {
            isDark
                ? accent.opacity(Tokens.Opacity.fillAccent)
                : .white.opacity(0.88)
        }

        /// Swipe action backgrounds.
        func swipeAction(_ accent: Color) -> Color {
            isDark
                ? accent
                : .white.opacity(Tokens.Opacity.fillAccent)
        }

        /// High-contrast inverted surfaces (rest cards, badges, selected toggles).
        var bold: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.foregroundRest)
                    : .white
        }

        /// High-contrast button surfaces.
        var boldAction: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.foregroundRest)
                : .white
        }
    }

    // MARK: Stroke

    struct StrokeTokens {
        fileprivate let isDark: Bool
        fileprivate let successBaseColor: Color

        /// Subtle card borders, dividers.
        var neutral: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.fillSubtle)
                : .black.opacity(0.06)
        }

        /// Accent-tinted borders.
        func emphasis(_ accent: Color) -> Color {
            accent.opacity(Tokens.Opacity.strokeAccent)
        }

        /// Borders for accent-tinted buttons and primary actions.
        func emphasisAction(_ accent: Color) -> Color {
            isDark
                ? accent.opacity(Tokens.Opacity.strokeAccent)
                : accent.opacity(0.16)
        }

        /// Keypad header divider keeps the original accent stroke in dark mode
        /// and uses a white separator in light mode.
        func headerDivider(_ accent: Color) -> Color {
            isDark ? accent.opacity(Tokens.Opacity.strokeAccentStrong) : .white
        }

        /// Success borders.
        var success: Color {
            isDark
                ? successBaseColor.opacity(Tokens.Opacity.strokeAccent)
                : successBaseColor.opacity(0.28)
        }

        /// High-contrast borders.
        var bold: Color {
            isDark ? .white : .black
        }
    }

    // MARK: Text

    struct TextTokens {
        fileprivate let isDark: Bool
        fileprivate let successBaseColor: Color

        /// Primary readable text.
        var neutral: Color {
            isDark ? .white : .black.opacity(Tokens.Opacity.foregroundRest)
        }

        /// Secondary / muted text.
        var subtle: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.foregroundSecondary)
                : .black.opacity(Tokens.Opacity.foregroundQuaternary)
        }

        /// Text on emphasis (accent) surfaces.
        var emphasis: Color { .white }

        /// Success-highlighted text.
        var success: Color { successBaseColor }

        /// Text on bold (inverted) surfaces.
        var bold: Color { .black }

        /// Text on rest rows within history surfaces.
        var historyRest: Color { .black }

        /// Error text.
        var error: Color { .red.opacity(0.9) }
    }

    // MARK: Icon

    struct IconTokens {
        fileprivate let isDark: Bool

        /// Monochrome primary icon tint.
        var neutral: AppIconStyleToken { .neutral }

        /// Monochrome secondary icon tint.
        var subtle: AppIconStyleToken { .subtle }

        /// Use the symbol's built-in colours.
        var original: AppIconStyleToken { .original }

        /// Settings row icons use the symbol's built-in colours when available.
        var settingsRow: AppIconStyleToken {
            original
        }
    }

    // MARK: - Screen Gradient Helpers

    /// Start colour of the full-screen app gradient.
    func appGradientStart(accent: Color) -> Color {
        isDark ? accent.opacity(Tokens.Opacity.fillGradientEnd) : accent.opacity(0.22)
    }

    /// End colour of the full-screen app gradient.
    func appGradientEnd(accent: Color) -> Color {
        isDark ? background.app(accent) : .clear
    }
}

enum AppIconStyleToken: Equatable {
    case neutral
    case subtle
    case original
}

extension View {
    @ViewBuilder
    func appIconStyle(_ style: AppIconStyleToken, theme: AppTheme) -> some View {
        switch style {
        case .neutral:
            self
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(theme.text.neutral)
        case .subtle:
            self
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(theme.text.subtle)
        case .original:
            self
                .symbolRenderingMode(.multicolor)
        }
    }
}

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme(colorScheme: .dark)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - Theme Injection Modifier

/// Attach at the root of the app to inject the theme and honour the user's appearance setting.
struct ThemeProvider: ViewModifier {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var effectiveColorScheme: ColorScheme {
        appearanceMode.resolvedColorScheme(systemColorScheme: systemColorScheme)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.appTheme, AppTheme(colorScheme: effectiveColorScheme))
            .preferredColorScheme(appearanceMode.colorScheme)
    }
}

extension View {
    func withAppTheme() -> some View {
        modifier(ThemeProvider())
    }
}
