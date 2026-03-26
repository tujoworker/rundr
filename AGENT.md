# Agent Notes

## Staging changes

- Stage only the files related to the task you completed.
- Prefer explicit `git add <path>` over broad adds so unrelated work stays out of the commit.
- Check the staged diff before committing with `git diff --cached`.

## Running tests

- Run the test suite before finishing meaningful code changes.
- Project scheme: `LapLog`
- Test target: `LapLogTests`
- Command:

```sh
xcodebuild test -project LapLog.xcodeproj -scheme LapLog -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'
```

- If that simulator is unavailable, use `xcodebuild -showdestinations -project LapLog.xcodeproj -scheme LapLog` and pick an available watchOS simulator.

## Commits

- Make a git commit after every new feature or logical change is completed.
- Make meaningful commits with a clear scope and message.
- Keep each commit focused on one logical change.
- Do not bundle unrelated refactors, generated files, or incidental edits into the same commit.

## Active session layout

- The lap cards scroll area at the bottom of `ActiveSessionView` must always reserve its fixed height (60pt), even when no laps exist yet, so the layout does not shift when the first card appears.

## Localization

- The app ships three locales: English (base), German (`de.lproj`), and Norwegian Bokmål (`nb.lproj`).
- When adding or changing a user-facing string, update all three places together:
  1. `LapLog/Helpers/L10n.swift` — add or update the `L10n` constant.
  2. `LapLog/de.lproj/Localizable.strings` — add the German translation.
  3. `LapLog/nb.lproj/Localizable.strings` — add the Norwegian translation.
- Never leave a new string without translations in both locale files.
