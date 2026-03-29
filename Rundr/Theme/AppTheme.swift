import SwiftUI

// MARK: - App Theme

/// Semantic color and style tokens.
/// Background is always the primary/accent color; text and chrome use white.
/// Use `@Environment(\.appTheme)` in views to access the active theme.
struct AppTheme {

    // MARK: Foreground / Text

    /// Primary text — full contrast.
    var textPrimary: Color { .white }

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
        .white.opacity(Tokens.Opacity.fillCard)
    }

    /// Input fields, subtle containers.
    var surfaceInput: Color {
        .white.opacity(Tokens.Opacity.fillInput)
    }

    /// Minimal tint surface (subtle accents on cards).
    var surfaceSubtle: Color {
        .white.opacity(Tokens.Opacity.fillSubtle)
    }

    /// Rest-state card foreground (inverted).
    var foregroundRest: Color {
        .white.opacity(Tokens.Opacity.foregroundRest)
    }

    /// Rest-state card background visible on dark backgrounds.
    var surfaceRestCard: Color {
        .white.opacity(Tokens.Opacity.foregroundRest)
    }

    // MARK: Borders & Strokes

    /// Subtle border for cards and overlays.
    var borderSubtle: Color {
        .white.opacity(Tokens.Opacity.fillSubtle)
    }

    // MARK: Screen Background

    /// The screen background is the accent/primary color at full opacity.
    func screenBackground(accent: Color) -> Color {
        accent
    }

    // MARK: Accent Chrome (white-based)

    /// Fill color for accent-tinted buttons.
    func accentFill(_ accent: Color) -> Color {
        .white.opacity(Tokens.Opacity.fillAccent)
    }

    /// Stroke color for accent-tinted buttons.
    func accentStroke(_ accent: Color) -> Color {
        .white.opacity(Tokens.Opacity.strokeAccent)
    }

    /// Subtle accent tint (lap cards, backgrounds).
    func accentSubtle(_ accent: Color) -> Color {
        .white.opacity(Tokens.Opacity.fillSubtle)
    }

    // MARK: Selection Toggle

    /// Background for the selected state of a toggle button.
    var toggleSelectedBackground: Color { .white }

    /// Foreground for the selected state of a toggle button.
    var toggleSelectedForeground: Color { .black }

    /// Background for the unselected state of a toggle button.
    var toggleUnselectedBackground: Color { surfaceInput }

    // MARK: Error

    var errorText: Color { .red.opacity(0.9) }

    // MARK: Badge

    /// Dark foreground text on bright badge backgrounds (lap numbers).
    var badgeForeground: Color {
        Color(red: 0.07, green: 0.09, blue: 0.15)
    }

    /// Bright badge background (lap number pill).
    var badgeBackground: Color { .white }

    /// Rest-state card text (dark-on-light).
    var textOnRestSurface: Color { .black }
}

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme()
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
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue

    private var colorScheme: ColorScheme? {
        (AppearanceMode(rawValue: appearanceModeRaw) ?? .system).colorScheme
    }

    func body(content: Content) -> some View {
        content
            .environment(\.appTheme, AppTheme())
            .preferredColorScheme(colorScheme)
    }
}

extension View {
    func withAppTheme() -> some View {
        modifier(ThemeProvider())
    }
}
