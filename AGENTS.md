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

## Coding Style

- Keep changes minimal and targeted.
- Preserve existing public APIs unless the task requires API changes.
- Follow the existing SwiftUI style already in the repo.
- Prefer small helper properties/functions when they make repeated UI logic clearer.
- Avoid unrelated refactors while implementing a feature.
- Keep duplicated flows in sync when the app intentionally mirrors behavior in multiple places, such as the pre-start and interval setup editors.
- Keep the iPhone companion `Session Plan` list in `Workouts` and the companion `Adjust Interval` editor in sync for shared controls and interactions, especially reorder/edit affordances.

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

## Design Tokens

- Always use tokens for visual decisions: colors, opacity, spacing, font sizes, line widths, corner radius, shadows, and similar values.
- Raw `Tokens` values are context-free building blocks. They are the foundation. Use them for primitives such as `Radius`, `Spacing`, `Opacity`, `FontSize`, and `LineWidth`.
- In views, use semantic theme tokens from `AppTheme` for color decisions instead of raw color literals or ad-hoc opacity chains.
- Use the semantic groups consistently:
  - `theme.background` for fills and surfaces.
  - `theme.stroke` for borders and dividers.
  - `theme.text` for foreground text colors.
  - `theme.icon` for symbol rendering/tint behavior.
- Token names should describe purpose, role, or emphasis level, not a specific screen or hard-coded color. Prefer names like `neutral`, `subtle`, `emphasis`, `bold`, `success`, or `destructive`.
- Keep semantic token usage the same across light and dark mode. If a component needs different visual balance per color scheme, change the token value or the semantic token implementation, not the token name used by the mode.
- Reuse an existing token before adding a new one. Only add a new token when the role is genuinely different and will stay meaningful across the app.
- Avoid inline visual constants in feature code such as raw `CGFloat` spacing, direct opacity numbers, or custom `Color` combinations when an existing token can express the same intent.
