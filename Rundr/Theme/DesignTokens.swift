import SwiftUI

// MARK: - Raw Design Tokens

/// Namespace for raw design token values used throughout the app.
/// These are context-free building blocks — use `AppTheme` semantic tokens
/// in views instead of referencing these directly.
enum Tokens {

    // MARK: Corner Radius

    enum Radius {
        /// 6 pt – lap number badges
        static let small: CGFloat = 6
        /// 8 pt – stat boxes, small containers
        static let medium: CGFloat = 8
        /// 12 pt – input field backgrounds
        static let large: CGFloat = 12
        /// 14 pt – cards, toggle buttons
        static let xl: CGFloat = 14
        /// 16 pt – medium accent buttons
        static let xxl: CGFloat = 16
        /// 18 pt – large accent buttons (default)
        static let xxxl: CGFloat = 18
        /// 22 pt – settings card rows
        static let xxxxl: CGFloat = 22
        /// 999 pt – pill / fully-rounded shapes
        static let pill: CGFloat = 999
    }

    // MARK: Spacing

    enum Spacing {
        static let xxxs: CGFloat = 1
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 14
        static let xxxl: CGFloat = 18
        /// 14 pt – floating status badge overlap
        static let badgeOverlap: CGFloat = 14
        static let xxxxl: CGFloat = 24
    }

    // MARK: Opacity

    enum Opacity {
        /// 0.90 – rest-state foreground (inverted cards)
        static let foregroundRest: Double = 0.90
        /// 0.84 – slightly muted primary text
        static let foregroundMuted: Double = 0.84
        /// 0.82 – timer secondary label
        static let foregroundTimerSecondary: Double = 0.82
        /// 0.80 – prompt body text, recovery body text
        static let foregroundBody: Double = 0.80
        /// 0.78 – pre-start small detail color
        static let foregroundDetail: Double = 0.78
        /// 0.78 – secondary text, hints, captions
        static let foregroundSecondary: Double = 0.78
        /// 0.68 – sidebar text in session detail
        static let foregroundTertiary: Double = 0.68
        /// 0.55 – de-emphasized counts, inactive labels
        static let foregroundQuaternary: Double = 0.55
        /// 0.45 – placeholder / disabled text
        static let foregroundDisabled: Double = 0.45
        /// 0.40 – accent button stroke
        static let strokeAccent: Double = 0.40
        /// 0.60 – strong accent divider stroke
        static let strokeAccentStrong: Double = 0.60
        /// 0.20 – accent button fill
        static let fillAccent: Double = 0.20
        /// 0.10 – destructive action backgrounds (delete, discard)
        static let fillDestructive: Double = 0.10
        /// 0.18 – screen gradient end, dark overlay base
        static let fillGradientEnd: Double = 0.18
        /// 0.15 – card background, circle fills
        static let fillCard: Double = 0.15
        /// 0.12 – input fields, subtle containers
        static let fillInput: Double = 0.12
        /// 0.10 – accent tint on lap cards, subtle borders
        static let fillSubtle: Double = 0.10
        /// 0.28 – icon / button drop shadows
        static let shadow: Double = 0.28
    }

    // MARK: Font Size

    enum FontSize {
        /// 12 pt – small icon indicators
        static let xs: CGFloat = 12
        /// 13 pt – stat labels, detail captions
        static let sm: CGFloat = 13
        /// 14 pt – banner text, secondary button labels
        static let md: CGFloat = 14
        /// 15 pt – inline values, lap header text
        static let base: CGFloat = 15
        /// 16 pt – action buttons, primary bold labels
        static let lg: CGFloat = 16
        /// 18 pt – section values, card content
        static let xl: CGFloat = 18
        /// 20 pt – numeric badges, keypad buttons
        static let xxl: CGFloat = 20
    }

    // MARK: Line Width

    enum LineWidth {
        static let thin: CGFloat = 1
        static let regular: CGFloat = 1.5
        static let medium: CGFloat = 2
        static let thick: CGFloat = 3
    }
}
