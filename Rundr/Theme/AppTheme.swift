import SwiftUI

// MARK: - App Theme

/// Semantic color and style tokens.
/// These adapt to the effective color scheme selected by the user.
/// Use `@Environment(\.appTheme)` in views to access the active theme.
struct AppTheme {
    let colorScheme: ColorScheme

    var isDark: Bool { colorScheme == .dark }

    // MARK: Foreground / Text

    /// Primary text — full contrast.
    var textPrimary: Color {
        .white
    }

    /// Timer secondary label, subtitle text.
    var textSecondary: Color {
        .white.opacity(Tokens.Opacity.foregroundSecondary)
    }

    /// Sidebar captions, tertiary info.
    var textTertiary: Color {
        .white.opacity(Tokens.Opacity.foregroundTertiary)
    }

    /// Prompt body, recovery description text.
    var textBody: Color {
        .white.opacity(Tokens.Opacity.foregroundBody)
    }

    /// De-emphasized counts, inactive labels.
    var textQuaternary: Color {
        .white.opacity(Tokens.Opacity.foregroundQuaternary)
    }

    /// Placeholder / disabled text.
    var textDisabled: Color {
        .white.opacity(Tokens.Opacity.foregroundDisabled)
    }

    // MARK: Surfaces

    /// Standard card background (lap cards, session row cards).
    var surfaceCard: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.fillCard)
            : .black.opacity(0.08)
    }

    /// Input fields, subtle containers.
    var surfaceInput: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.fillInput)
            : .black.opacity(0.06)
    }

    /// Minimal tint surface (subtle accents on cards).
    var surfaceSubtle: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.fillSubtle)
            : .black.opacity(0.04)
    }

    /// Rest-state card foreground (inverted).
    var foregroundRest: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.foregroundRest)
            : .black.opacity(0.85)
    }

    /// Rest-state card background visible on dark backgrounds.
    var surfaceRestCard: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.foregroundRest)
            : .black.opacity(0.06)
    }

    // MARK: Borders & Strokes

    /// Subtle border for cards and overlays.
    var borderSubtle: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.fillSubtle)
            : .black.opacity(0.08)
    }

    // MARK: Screen Background

    /// End color of the screen gradient.
    func screenGradientEnd(accent: Color) -> Color {
        isDark ? accent.opacity(Tokens.Opacity.fillGradientEnd) : accent
    }

    /// Start color of the screen gradient.
    var screenGradientStart: Color {
        isDark ? .black : .white
    }

    /// Start color used by the full-screen app background.
    func screenBackgroundStart(accent: Color) -> Color {
        isDark ? .black : accent
    }

    // MARK: Accent Chrome

    /// Fill color for accent-tinted buttons.
    func accentFill(_ accent: Color) -> Color {
        accent.opacity(Tokens.Opacity.fillAccent)
    }

    /// Fill color for primary action buttons.
    func accentButtonFill(_ accent: Color) -> Color {
        isDark ? accent.opacity(Tokens.Opacity.fillAccent) : .white.opacity(Tokens.Opacity.fillAccent)
    }

    /// Stroke color for accent-tinted buttons.
    func accentStroke(_ accent: Color) -> Color {
        accent.opacity(Tokens.Opacity.strokeAccent)
    }

    /// Stroke color for primary action buttons.
    func accentButtonStroke(_ accent: Color) -> Color {
        isDark ? accent.opacity(Tokens.Opacity.strokeAccent) : .white.opacity(Tokens.Opacity.strokeAccent)
    }

    /// Foreground color for primary action buttons.
    var accentButtonForeground: Color {
        .white
    }

    /// Subtle accent tint (lap cards, backgrounds).
    func accentSubtle(_ accent: Color) -> Color {
        accent.opacity(Tokens.Opacity.fillSubtle)
    }

    /// Bright surface for tinted secondary actions.
    var tintedButtonBackground: Color {
        isDark ? .white : .white.opacity(Tokens.Opacity.fillAccent)
    }

    /// Border for tinted secondary actions.
    func tintedButtonStroke(_ tint: Color) -> Color {
        tint.opacity(isDark ? 0.34 : 0.18)
    }

    // MARK: Selection Toggle

    /// Background for the selected state of a toggle button.
    var toggleSelectedBackground: Color {
        isDark ? .white : .black
    }

    /// Foreground for the selected state of a toggle button.
    var toggleSelectedForeground: Color {
        isDark ? .black : .white
    }

    /// Background for the unselected state of a toggle button.
    var toggleUnselectedBackground: Color { surfaceInput }

    // MARK: Error

    var errorText: Color {
        .red.opacity(isDark ? 0.9 : 1)
    }

    // MARK: Badge

    /// Dark foreground text on bright badge backgrounds (lap numbers).
    var badgeForeground: Color {
        Color(red: 0.07, green: 0.09, blue: 0.15)
    }

    /// Bright badge background (lap number pill).
    var badgeBackground: Color {
        .white
    }

    /// Rest-state card text (dark-on-light).
    var textOnRestSurface: Color { isDark ? .black : .white }
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
