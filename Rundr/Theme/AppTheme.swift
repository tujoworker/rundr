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

    var isDark: Bool { colorScheme == .dark }

    // MARK: - Grouped Tokens

    var background: BackgroundTokens { .init(isDark: isDark) }
    var stroke: StrokeTokens { .init(isDark: isDark) }
    var text: TextTokens { .init(isDark: isDark) }
    var icon: IconTokens { .init(isDark: isDark) }

    // MARK: Background

    struct BackgroundTokens {
        fileprivate let isDark: Bool

        /// Screen / view background.
        var app: Color { isDark ? .black : .white }

        /// Cards, input fields, containers.
        var neutral: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.fillCard)
                : .black.opacity(0.08)
        }

        /// Interactive controls: buttons, toggles, tappable fields.
        var neutralAction: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.fillCard)
                : .black.opacity(0.08)
        }

        /// Interactive rows and cards with embedded controls.
        var neutralInteraction: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.fillInput)
                : .black.opacity(0.06)
        }

        /// Accent-tinted buttons and primary actions.
        func emphasisAction(_ accent: Color) -> Color {
            accent.opacity(Tokens.Opacity.fillAccent)
        }

        /// Accent-tinted surfaces (buttons, banners).
        func emphasis(_ accent: Color) -> Color {
            accent.opacity(Tokens.Opacity.fillAccent)
        }

        /// High-contrast inverted surfaces (rest cards, badges, selected toggles).
        var bold: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.foregroundRest)
                : .black.opacity(0.85)
        }

        /// High-contrast button surfaces.
        var boldAction: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.foregroundRest)
                : .black.opacity(0.85)
        }
    }

    // MARK: Stroke

    struct StrokeTokens {
        fileprivate let isDark: Bool

        /// Subtle card borders, dividers.
        var neutral: Color {
            isDark
                ? .white.opacity(Tokens.Opacity.fillSubtle)
                : .black.opacity(0.08)
        }

        /// Accent-tinted borders.
        func emphasis(_ accent: Color) -> Color {
            accent.opacity(Tokens.Opacity.strokeAccent)
        }

        /// High-contrast borders.
        var bold: Color {
            isDark ? .white : .black
        }
    }

    // MARK: Text

    struct TextTokens {
        fileprivate let isDark: Bool

        /// Primary readable text.
        var neutral: Color { .white }

        /// Secondary / muted text.
        var subtle: Color {
            .white.opacity(Tokens.Opacity.foregroundSecondary)
        }

        /// Text on emphasis (accent) surfaces.
        var emphasis: Color { .white }

        /// Text on bold (inverted) surfaces.
        var bold: Color { isDark ? .black : .white }

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

        /// Settings row icons use original symbol colours in dark mode
        /// and a monochrome neutral tint in light mode.
        var settingsRow: AppIconStyleToken {
            isDark ? original : neutral
        }
    }

    // MARK: - Screen Gradient Helpers

    /// Start colour of the full-screen app gradient.
    func appGradientStart(accent: Color) -> Color {
        isDark ? .black : accent
    }

    /// End colour of the full-screen app gradient.
    func appGradientEnd(accent: Color) -> Color {
        isDark ? accent.opacity(Tokens.Opacity.fillGradientEnd) : accent
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
