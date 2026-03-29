# Rundr Agent Guide

## Product Context

- Rundr is a watchOS-first interval running app with an iPhone companion.
- The watch app is the primary surface; optimize for glanceability, large touch targets, and fast setup flows.

## Translation Rules

- **Never** write a bare string literal in any SwiftUI view or view-model that is displayed to the user.
  - Forbidden: `Text("Get Ready")`, `Button("Cancel", ...)`, `Section("Summary")`, `.navigationTitle("Session")`, `Label("Delete", ...)`, `LabeledContent("Time", ...)`
  - Required: `Text(L10n.getReady)`, `Button(L10n.cancel, ...)`, `Section(L10n.summary)`, `.navigationTitle(L10n.session)`, `Label(L10n.delete, ...)`, `LabeledContent(L10n.time, ...)`
  - Interpolated strings must also use L10n: use `L10n.heartRateBPM(value)` instead of `"Heart Rate \(value) bpm"`.
  - Exceptions that may stay as bare literals: SF Symbol names (`"figure.run"`), brand names (`"Rundr"`, `"Apple Watch"`), format specifiers, empty strings, and non-displayed identifiers.
- Before adding a new string, **search `L10n.swift`** for an existing constant with the same or equivalent wording. Reuse it if it fits.
- When a new user-facing string is needed, update **all four files together in the same change**:
  1. `Rundr/Helpers/L10n.swift` — add or update the `static let` / `static func`.
  2. `Rundr/de.lproj/Localizable.strings` — add the German translation.
  3. `Rundr/ja.lproj/Localizable.strings` — add the Japanese translation.
  4. `Rundr/nb.lproj/Localizable.strings` — add the Norwegian (Bokmål) translation.
- For dynamic strings (containing runtime values), create a `static func` that uses `String(format: String(localized: …), …)` — see `lapIndex(_:)` or `heartRateBPM(_:)` for examples.
- Do not leave new English-only UI text in the app.

## Design Tokens / Styling

- **Never** use hardcoded colors, opacities, spacing, corner radii, or line widths in SwiftUI views.
  - Forbidden: `.opacity(0.15)`, `.cornerRadius(12)`, `.padding(8)`, `.white.opacity(0.72)`, `Color(red:…)`, `lineWidth: 2`
  - Required: Use `AppTheme` semantic tokens for colors/surfaces and `Tokens.*` constants for raw values.
- **Colors & surfaces**: Access the theme via `@Environment(\.appTheme) var theme` and use semantic properties:
  - Text: `theme.textPrimary`, `theme.textSecondary`, `theme.textTertiary`, `theme.textBody`, `theme.textQuaternary`, `theme.textDisabled`
  - Surfaces: `theme.surfaceCard`, `theme.surfaceInput`, `theme.surfaceSubtle`, `theme.surfaceRestCard`
  - Borders: `theme.borderSubtle`
  - Accents: `theme.accentFill(_:)`, `theme.accentStroke(_:)`, `theme.accentSubtle(_:)`
  - Toggles: `theme.toggleSelectedBackground`, `theme.toggleSelectedForeground`, `theme.toggleUnselectedBackground`
  - Gradients: `theme.screenGradientStart`, `theme.screenGradientEnd(accent:)`
  - Badges: `theme.badgeForeground`
  - Errors: `theme.errorText`
- **Spacing**: Use `Tokens.Spacing.*` (`xxxs` through `xxxxl`) for all padding, spacing, and gaps.
- **Corner radii**: Use `Tokens.Radius.*` (`small` through `pill`).
- **Opacities**: Use `Tokens.Opacity.*` for any opacity value.
- **Line widths**: Use `Tokens.LineWidth.*` (`thin`, `regular`, `medium`, `thick`).
- When a needed semantic token does not exist, **add it** to `AppTheme.swift` (for colors) or `DesignTokens.swift` (for raw values) rather than inlining a magic number.
- Before adding a new token, check whether an existing one already covers the use case.

## Coding Style

- Keep changes minimal and targeted.
- Preserve existing public APIs unless the task requires API changes.
- Follow the existing SwiftUI style already in the repo.
- Prefer small helper properties/functions when they make repeated UI logic clearer.
- Avoid unrelated refactors while implementing a feature.
- Keep duplicated flows in sync when the app intentionally mirrors behavior in multiple places, such as the pre-start and interval setup editors.

## Tests

- Add or update tests for every meaningful behavior change.
- Prefer model/controller tests when behavior can be validated without UI automation.
- Run tests before finishing meaningful changes.
- Default command:

```sh
xcodebuild test -project Rundr.xcodeproj -scheme Rundr -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'
```

- If that simulator is unavailable, run `xcodebuild -showdestinations -project Rundr.xcodeproj -scheme Rundr` and choose an available watchOS simulator.

## Commits

- Create a commit after each completed feature or logical change.
- Keep each commit focused on one topic.
- Stage files explicitly; do not use broad adds when unrelated files may be present.
- Review the staged diff before committing.
- Write concise, scope-specific commit messages.

## Practical Repo Notes

- Stage changes with explicit paths, for example `git add path/to/file`.
- Check staged changes with `git diff --cached`.
- The lap cards area in `ActiveSessionView` must keep its fixed height even when there are no laps yet.
