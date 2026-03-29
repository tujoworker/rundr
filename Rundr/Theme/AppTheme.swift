import SwiftUI

// MARK: - App Theme

/// Semantic color and style tokens that adapt to the current color scheme.
/// Use `@Environment(\.appTheme)` in views to access the active theme.
struct AppTheme {
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    // MARK: Foreground / Text

    /// Primary text — full contrast.
    var textPrimary: Color {
        isDark ? .white : .black
    }

    /// Timer secondary label, subtitle text.
    var textSecondary: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.foregroundSecondary)
            : .black.opacity(0.55)
    }

    /// Sidebar captions, tertiary info.
    var textTertiary: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.foregroundTertiary)
            : .black.opacity(0.45)
    }

    /// Prompt body, recovery description text.
    var textBody: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.foregroundBody)
            : .black.opacity(0.65)
    }

    /// De-emphasized counts, inactive labels.
    var textQuaternary: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.foregroundQuaternary)
            : .black.opacity(0.35)
    }

    /// Placeholder / disabled text.
    var textDisabled: Color {
        isDark
            ? .white.opacity(Tokens.Opacity.foregroundDisabled)
            : .black.opacity(0.28)
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

    /// Rest-state card background visible on dark backgrounds
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

    /// End color of the screen gradient (accent-tinted).
    func screenGradientEnd(accent: Color) -> Color {
        accent.opacity(isDark ? Tokens.Opacity.fillGradientEnd : 0.10)
    }

    /// Start color of the screen gradient.
    var screenGradientStart: Color {
        isDark ? .black : .white
    }

    // MARK: Accent Chrome

    /// Fill color for accent-tinted buttons.
    func accentFill(_ accent: Color) -> Color {
        accent.opacity(Tokens.Opacity.fillAccent)
    }

    /// Stroke color for accent-tinted buttons.
    func accentStroke(_ accent: Color) -> Color {
        accent.opacity(Tokens.Opacity.strokeAccent)
    }

    /// Subtle accent tint (lap cards, backgrounds).
    func accentSubtle(_ accent: Color) -> Color {
        accent.opacity(Tokens.Opacity.fillSubtle)
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
    var toggleUnselectedBackground: Color {
        surfaceInput
    }

    // MARK: Error

    var errorText: Color {
        .red.opacity(isDark ? 0.9 : 1)
    }

    // MARK: Badge

    /// Dark foreground text on bright badge backgrounds (lap numbers).
    var badgeForeground: Color {
        isDark
            ? Color(red: 0.07, green: 0.09, blue: 0.15)
            : .white
    }

    /// Bright badge background (lap number pill).
    var badgeBackground: Color {
        isDark ? .white : .black
    }

    /// Rest-state card text (dark-on-light).
    var textOnRestSurface: Color {
        isDark ? .black : .black
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

/// Attach at the root of the app to keep the theme in sync with the system color scheme.
struct ThemeProvider: ViewModifier {
    @Environment(\.colorScheme) private var systemColorScheme
    @EnvironmentObject private var settings: SettingsStore

    private var effectiveColorScheme: ColorScheme {
        settings.appearanceMode.colorScheme ?? systemColorScheme
    }

    func body(content: Content) -> some View {
        content
            .environment(\.appTheme, AppTheme(colorScheme: effectiveColorScheme))
            .preferredColorScheme(settings.appearanceMode.colorScheme)
    }
}

extension View {
    func withAppTheme() -> some View {
        modifier(ThemeProvider())
    }
}
