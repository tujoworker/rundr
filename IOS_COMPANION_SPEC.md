# Rundr iOS Companion Expansion Spec

## Goal

Turn the iPhone companion into the configuration and browsing surface for the watch-first app while keeping the Apple Watch as the only workout execution engine.

This slice adds:

- shared semantic design tokens in the iPhone target
- a three-tab iPhone shell: `Workouts`, `Browser`, `Settings`
- iPhone editing for the current workout interval plan used by the watch when a workout starts
- iPhone browsing for both saved and predefined interval presets
- sync for workout settings, interval plans, presets, color, and appearance between watch and iPhone

This slice does not add:

- workout execution on iPhone
- HealthKit workout control from iPhone
- a fully extracted shared UI package for watch + iPhone

## Product Rules

- Apple Watch remains the workout authority.
- The interval plan used on iPhone must map directly to the watch `SettingsStore` values that the watch start flow already uses.
- iPhone and watch should converge on the same configuration as quickly as WatchConnectivity permits.
- Semantic token names and color values must match the watch app exactly.

## Architecture

### 1. Theme sharing now, extraction later

- Add the existing watch `DesignTokens` and `AppTheme` sources to the iPhone target.
- Use the same semantic token groups on iPhone: `background`, `stroke`, `text`, `icon`.
- Later, these should be extracted into a shared module or package, but this slice keeps source-level sharing inside the current Xcode project.

### 2. Shared workout-plan logic

- Reuse the existing domain types: `WorkoutPlanSnapshot`, `DistanceSegment`, `IntervalPreset`, `TrackingMode`, `RestMode`, `DistanceUnit`.
- Move interval-plan display and normalization helpers into shared code so watch and iPhone use the same rules.
- Keep iPhone UI separate from the watch UI for now because the existing watch editor contains watch-specific layout and input behavior.

### 3. Realtime config sync

- Extend WatchConnectivity sync with a settings payload carrying:
  - tracking mode
  - distance unit
  - rest mode
  - current interval plan
  - saved interval presets
  - lap/rest alert toggles
  - primary color
  - appearance
  - `updatedAt`
  - `deviceSource`
- Use `updateApplicationContext` for the latest settings snapshot.
- Apply incoming payloads only when newer than the last accepted payload, using `updatedAt` and `deviceSource` tie-breaks.
- Publish settings on activation and whenever relevant companion/watch settings change.

## iPhone Navigation

### Workouts

- Show the current workout plan that the watch will use on start.
- Allow editing the interval plan and workout-related settings:
  - tracking mode
  - rest mode
  - distance unit
  - intervals
- Keep the existing live watch card and synced session history in this tab so the iPhone still acts as the watch companion.

### Browser

- Show `My intervals` and `Predefined` sections like the watch.
- Allow opening presets, editing them, saving them, and applying them to the current workout plan.

### Settings

- Only include color and appearance in this slice.
- Persist through `SettingsStore` and sync them to the watch.

## Testing

- Add unit coverage for settings sync conflict resolution.
- Add unit coverage for settings sync application into `SettingsStore`.
- Add unit coverage for shared workout-plan helpers used by both watch and iPhone.

## Follow-up

- Extract theme and shared editor logic into a dedicated shared module.
- Consider a more granular bidirectional sync transport if `updateApplicationContext` proves insufficient for larger preset libraries.
