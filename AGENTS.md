# Rundr Agent Guide

## Product Context

- Rundr is a watchOS-first interval running app with an iPhone companion.
- The watch app is the primary surface; optimize for glanceability, large touch targets, and fast setup flows.

## Translation Rules

- Always localize user-facing strings.
- Prefer `L10n` constants over inline string literals in SwiftUI and model/UI code.
- When adding a new user-facing string, update all three places together:
  - `Rundr/Helpers/L10n.swift`
  - `Rundr/de.lproj/Localizable.strings`
  - `Rundr/nb.lproj/Localizable.strings`
- Do not leave new English-only UI text in the app.
- Reuse existing localized labels when the wording already exists.

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
