# Rundr Apple Watch App — Build Spec for AI Code Generation

## Goal

Build a **watchOS-first Apple Watch app** for logging interval sessions with distance lap marking or GPS-based tracking, optimized for **fast launch**, **large glanceable workout UI**, **strong haptics**, and **persistent session history**.

This document is written as a **precise implementation spec** so another AI or developer can build the app.

Write tests and run them during development. Each feature should get several tests. They are our contract for understanding the functionality and also ensures stability for when adding new features.

---

## Important platform note

The app should store completed workouts in:

1. the app’s own local history, and
2. Apple Health / Fitness via HealthKit.

However, the implementation must treat these as **separate outputs**:

- **App history** must contain the full lap-by-lap model exactly as described below.
- **HealthKit export** must write the workout, route/distance, heart-rate data used during the workout, calories if available, and workout events. Every lap/interval should be listed there.
- The implementation should **attempt to map laps/rest/activity into HealthKit workout events and metadata**, but it must not assume the Apple Fitness app will render third-party custom laps exactly the same way the app does.

So the system must preserve the **full canonical lap record inside the app database** even if Health/Fitness display is more limited.

---

## Product requirements

### Core use case

User starts a session on Apple Watch, records interval laps while running, optionally marks rest periods, sees the running timer, sees recent laps in horizontally scrollable cards, sees live heart rate, and stores the full workout afterward.

### Non-functional requirements

- Launch fast on watch.
- History screen must feel instant.
- Avoid heavy calculations on the main thread.
- Persist settings across app restarts.
- Handle workout state safely if app goes to background or screen turns off.
- Large touch targets.
- Strong haptic feedback for key actions.

---

## Target platform

- **Primary target:** Apple Watch / watchOS app.
- Prefer **SwiftUI** for UI.
- Prefer **HealthKit workout session APIs** for live workout collection.
- Use **CoreLocation** only when needed for GPS mode.
- Persist local data with **SwiftData** or **Core Data**. If choosing one, prefer **SwiftData** unless backward compatibility requires Core Data.
- Use **AppStorage / UserDefaults** for lightweight settings persistence.

---

## Data model

### Session

Each completed workout session must store:

- `id: UUID`
- `startedAt: Date`
- `endedAt: Date`
- `durationSeconds: Double`
- `mode: enum { gps, dual, distanceDistance }`
- `sportVariantRaw: String?` (optional future classification / workout variant)
- `distanceLapDistanceMeters: Double?`
- `totalDistanceMeters: Double`
- `totalGPSDistanceMeters: Double?` — stored separately for dual mode or GPS workouts
- `averageSpeedMetersPerSecond: Double`
- `totalLaps: Int`
- `laps: [Lap]`
- `deviceSource: String` (for example Apple Watch model / app version)
- `healthKitWorkoutUUID: UUID?` or saved reference if available
- `createdAt: Date`
- `updatedAt: Date`
- `snapshotWorkoutPlan: WorkoutPlanSnapshot` — canonical snapshot of the exact interval/rest plan used

### Lap

Each lap in a session must store:

- `id: UUID`
- `index: Int` (1-based order)
- `startedAt: Date`
- `endedAt: Date`
- `durationSeconds: Double`
- `distanceMeters: Double`
- `gpsDistanceMeters: Double?` — separate measured GPS distance when manual intervals are active in dual mode
- `averageSpeedMetersPerSecond: Double`
- `averageHeartRateBPM: Double?`
- `lapType: enum { active, rest }`
- `source: enum { distanceTap, actionButton, autoDistance, autoTime, sessionEndSplit }`

### Session settings snapshot

Each session must store the exact settings used when it began:

- `trackingMode: gps | dual | distanceDistance`
- `distanceDistanceMeters: Double?`
- `distanceSegments: [DistanceSegment]?` (the full interval plan)
- any future settings added later

This prevents history from changing if defaults change later.

### DistanceSegment

Represents one step in an interval plan:

- `id: UUID`
- `distanceMeters: Double` — the fixed target distance when `distanceGoalMode = fixed`
- `distanceGoalMode: enum { fixed, open }`
- `repeatCount: Int?` — how many laps at this distance before advancing to the next segment. `nil` means unlimited (open-ended).
- `restSeconds: Int?` — rest duration after non-final repeats inside the segment. `nil` means manual rest.
- `lastRestSeconds: Int?` — optional override rest duration after the final repeat of the segment before the next segment begins. If `nil`, use `restSeconds`.
- `targetPaceSecondsPerKm: Double?`
- `targetTimeSeconds: Double?`

Behavior notes:

- `fixed` segments use `distanceMeters` as their canonical lap distance.
- `open` segments have no manual distance target and must use measured GPS distance instead.
- `open` segments may still define a target time.
- pace-derived target time only applies to `fixed` segments.
- when a segment repeats multiple times, `restSeconds` applies between reps and `lastRestSeconds` applies only after the final rep when advancing into another segment.
- if `lastRestSeconds` is omitted, the app must fall back to `restSeconds` for segment-to-segment transitions so existing saved plans keep the same behavior.

Default plan: a single segment of 400 m with unlimited repeats.

---

## Settings persistence

Persist the following across app restarts:

- last selected tracking mode (`gps`, `dual`, or `distanceDistance`)
- last entered manual distance in meters (legacy, for backward compatibility)
- distance segments array (JSON-encoded interval plan)
- saved interval presets array (JSON-encoded preset library)
- rest mode (`manual` or `autoDetect`) — manual: user taps to enter/exit rest; auto: HealthKit motion events enter/exit rest
- primary accent color (blue, green, yellow, orange, pink, dark) — white was removed; migration maps legacy "white" to blue
- any future session options

Preset library requirements:

- provide a library of predefined interval presets and user-saved presets
- normalize saved interval plans so earlier open-ended segments become `×1` when later segments exist
- only save presets for modes that use manual intervals (`distanceDistance`, `dual`)
- when applying a manual-interval workout plan while the current persisted mode is `gps`, upgrade to `dual` so GPS tracking is preserved alongside manual lap targets

Use lightweight persistent storage so the settings screen restores instantly on app launch.

---

## App navigation structure

### Screen 1 — Home

Purpose: fast entry point for starting a session and opening recent sessions.

#### Layout

- Top area: one large **“Get Ready”** button.
- Button is centered horizontally.
- Below it: a recent sessions list.
- Show **maximum 3 sessions initially**.
- If there are more than 3, show a **“Load More”** button below the list.

#### Recent session row content

Each row must be easy to tap and show:

- total laps
- pace
- total time
- total distance
- when the session includes open intervals, show GPS distance as the primary distance metric instead of manual distance

Display format should favor quick reading on watch.
Example row structure:

- line 1: date/time or short session title
- line 2: `Laps: 12 • Avg: 4.3 m/s`
- line 3: `Time: 00:18:42 • Dist: 4.00 km`

#### Behavior

- Tapping a session opens Screen 2: Session Detail / Lap History.
- Tapping “Load More” reveals more history in batches, preferably 10 at a time.

#### Performance requirements

- Load only summary fields for the first 3 sessions on launch.
- Do not precompute lap detail on the home screen.
- Use lazy rendering for history rows.
- Opening the app should not block on HealthKit reads.
- Home screen should be driven by local persisted history first.

---

### Screen 2 — Session Detail / Lap History

Purpose: inspect a previous session.

#### Layout

Show a vertically scrollable session detail view with:

- a date range header (`start - end` on the same row)
- a compact stats grid showing mode, time, laps, and distance metrics relevant to the tracking mode
- a vertically scrollable list of all laps
- a "Reuse This Interval" action that loads the saved workout plan back into setup

Each lap row must show:

- elapsed time
- lap number for active laps, or a `Rest` badge for rest laps
- manual interval distance and pace when the session uses manual intervals
- GPS distance and GPS pace when the session uses GPS distance
- target time and/or target pace when the original segment defined one
- heart rate when available

Open-interval display rule:

- when the original segment used `distanceGoalMode = open`, do not show manual distance
- show GPS distance as the only distance metric for that lap
- continue showing pace for that lap

#### Suggested row layout

- line 1: lap badge / rest badge + elapsed time
- detail grid below: distance, pace, GPS distance, GPS pace, target time, target pace, heart rate as applicable

#### Behavior

- Sort by actual lap order / start time ascending.
- If heart rate or a metric is unavailable, show `—`.
- In dual mode, preserve both the manual interval distance and the measured GPS distance in the detail view.

---

### Screen 3 — Pre-Start Setup

Reached after tapping **Get Ready**.

#### Layout

- Top: large **Start** button.
- Below: vertically scrollable settings.
- Settings section order: **Settings** label (with top padding), then **Intervals** (distance segments), then **Mode** (tracking mode, rest mode, unit, color).

#### Setting 1 — Intervals (distance segments)

When a manual-interval mode (`Distance` or `Dual`) is selected, show an **Intervals** section first:

- list of **distance segments** forming the interval plan
- each segment has a distance mode (`Fixed` or `Open`), an optional repeat count, optional rest, an optional last-rest override between blocks, and optional targets
- default: one segment of `400` meters with unlimited (∞) repeats
- user can add new segments below the existing ones
- user can tap a segment to open **SegmentEditSheet** to edit distance mode, distance, repeat count, rest, and targets
- when a new segment is added, any earlier segment that was still unlimited must automatically become `×1` so later segments are reachable
- SegmentEditSheet: when `Fixed` is selected, distance is editable via TextField (manual entry); when `Open` is selected, hide manual distance entry because there is no manual distance target
- user can delete segments (at least one must remain)
- validate each fixed distance as a positive number greater than 0
- store the full segment plan and restore it on next launch
- repeat count of `nil` or empty means unlimited
- `Add Distance` should be labeled `Add Interval`
- include a Browse action that opens an interval library with predefined and saved presets
- saved presets can be created from interval setup and from completed sessions
- saved presets are sorted by most recently edited
- editing a preset that duplicates another saved preset should merge into the existing preset instead of creating duplicates

Open interval behavior in setup:

- if any segment uses `Open` distance while the selected tracking mode is `Distance`, auto-upgrade the workout to `Dual`
- show a green inline info banner under the distance control explaining that GPS is also enabled
- if location permission has not been requested yet, include a button in that banner to request access
- reuse the same tinted info-banner visual style used elsewhere in the app

#### Setting 2 — Mode (tracking mode, rest mode, unit, color)

- **Tracking mode**: dialog or segmented control with `Distance`, `Dual`, and `GPS`. Persist the selected value.
- **Rest mode**: `Manual` (user taps to enter/exit rest) or `Auto` (HealthKit motion events enter/exit rest). Persist the selected value.
- **Distance unit**: km or miles.
- **Primary color**: blue, green, yellow, orange, pink, dark. Persist the selected value.

#### GPS mode behavior

If `GPS` is selected:

- Intervals section is hidden or disabled
- lap distance is derived live from distance traveled between lap boundaries

#### Dual mode behavior

If `Dual` is selected:

- manual interval segments remain active and define the canonical lap distance
- GPS tracking stays active in parallel
- lap detail and session history should expose both manual distance/pace and GPS distance/pace

Exception for open intervals:

- if the active segment is `Open`, there is no canonical manual lap distance for that interval
- `Dual` must still stay active so GPS distance is captured
- history and detail should show GPS distance for that interval and continue showing pace

#### Start button behavior

When Start is pressed:

- create a new in-memory active session
- capture a settings snapshot
- initialize workout collection
- request HealthKit workout session start
- transition immediately to the active workout screen
- trigger strong haptic feedback

---

### Screen 4 — Active Session

Purpose: live workout UI while running.

#### Required layout

The active session uses a horizontal **paged TabView** with two pages and page indicators at the bottom:

**Page 0 — Controls page (left, swipe-to):**

- Scrollable vertically
- **Rest toggle button** (primary action, larger): shows a cooldown icon and "Rest" label in active state; shows a running icon and "End Rest" label in rest state. The button is content-only, uses pressed-scale feedback, and auto-swipes back to the tracking page after the action completes.
- **Second row** with two secondary-style buttons side by side:
  - **End** button (`stop.fill` icon) — shows a confirmation dialog before ending the session
  - **Pause / Resume** button (`pause.fill` / `play.fill` icon) — toggles workout pause, uses the same pressed-scale feedback, and auto-swipes back to the tracking page

**Page 1 — Tracking page (right, default on launch):**

- Center/main focus: elapsed seconds counting upward, **large and bold**
- A visible lap counter badge must remain visible across `active`, `rest`, `paused`, and `ending` states
- Top center: live heart rate
- Below main timer: horizontally scrollable lap cards
- Newest lap card appears on the **right**
- The lap cards area must always occupy its fixed height (60pt), even when no laps exist yet, to prevent layout shifts when the first card appears

#### Live timer

- Must continue counting even during rest mode
- Must work in the background when temporarily closed
- Must be highly visible
- Use monospaced digits for stability
- Example: `08:43`
- In distance mode, show the **current target distance** above the timer (from the active segment in the interval plan)
- If the active segment has a target time or target pace, prefer showing that target summary above the timer
- For an open interval with a target time, show an `Open • <time>` style target summary above the timer
- when the interval plan has a finite total, show the **remaining planned laps** beside that label, e.g. `400 m · 5 left`
- During rest, show "Rest Mode" above the timer instead
- During a full pause, show `Paused` and stop accumulating elapsed workout time until resumed

#### Lap cards

Show recent completed laps in horizontally scrollable boxes/cards.
Each card shows:

- lap time (large)
- distance or GPS distance summary when available
- pace summary (smaller)
- optionally (maybe with a setting) lap label and rest/activity state (maybe just in color)

Behavior:

- newest completed lap is appended to the right
- user can scroll horizontally through previous laps
- cards must remain readable during motion
- tapping a card opens a dedicated lap editor screen
- the lap editor must support:
  - changing the lap type between `Activity` and `Rest`
  - changing the lap distance with the same +/- stepper style used in the interval editor
  - deleting the lap
- editing or deleting a lap must recalculate lap numbering, cumulative distance, and interval-plan progress so the session state stays consistent

#### Session control state machine

Current states during an active workout:

- `Rest` enters rest mode without stopping the workout clock
- a pause control can move the workout into a full `paused` state; paused time should not count toward workout elapsed time
- rest and paused states expose resume actions via the controls page
- the end-session flow is triggered from the controls page End button

Important interpretation:

- `Rest` is not a stopwatch pause.
- `Paused` is a true pause that temporarily freezes elapsed workout time until resumed.
- the session clock continues through rest, but not through a full pause.

#### Lap action during active session

The app must support creating laps during the session.
Sources:

- on-screen interaction if implemented
- Apple Watch Action Button

When a lap is created:

- close the current segment
- compute duration, distance, avg speed, avg HR
- store as completed lap
- create a new current segment starting immediately
- append new completed lap card to the right
- trigger strong haptic

#### Heart rate display

- show current live heart rate on top right
- update from HealthKit live workout stream
- if unavailable, show `—`

#### Background / wrist-down behavior

- session timing and collection must continue correctly while watch is not actively displaying the app
- when app reappears, restore the active session UI without data loss
- persist a lightweight ongoing-workout snapshot during the workout so the app can recover after process death or relaunch
- if a recoverable snapshot exists on launch, show a recovery prompt with `Continue Workout` and `Discard Workout`
- continuing a recovered workout should reopen the active session in a paused state so the runner explicitly decides when to resume

---

## Action Button behavior

The user wants the Action Button to be usable for:

- `Get Ready`
- `Start`
- `Lap`

Implementation requirement:

- support Action Button integration where allowed by watchOS APIs and device capabilities
- define context-sensitive behavior:
  - on Home: Action Button opens **Get Ready**
  - on Pre-Start Setup: Action Button triggers **Start**
  - during Active Session: Action Button triggers **Lap**

- every successful Action Button press triggers strong haptic feedback

If some Action Button mappings are restricted by the platform, prioritize this fallback order:

1. Lap during active workout
2. Start from pre-start screen
3. Get Ready from home screen

---

## Workout logic

### Session start

At start time:

- record `startedAt`
- start HealthKit workout session
- start elapsed timer based on wall clock / elapsed reference time, not repeated timer accumulation
- begin live collection for heart rate and distance where available
- create an open current segment with type `active`

### Lap creation rules

A lap is finalized when:

- user presses lap action, or
- user presses Rest and the current active segment should be closed, or
- user resumes from a rest segment into activity if that interaction is later added, or
- session ends and there is an open segment that should be committed

### Distance calculation

#### GPS mode

For each lap:

- lap distance = difference in cumulative workout distance between lap start and lap end
- if GPS temporarily drops out, keep timing the lap and use best available distance estimate
- store distance as meters

#### Dual mode

For each lap:

- canonical `distanceMeters` comes from the active manual interval segment
- `gpsDistanceMeters` stores the measured GPS distance covered during that same lap
- history and analytics should keep those values separate instead of collapsing one into the other

Open interval exception:

- when the active segment uses `distanceGoalMode = open`, `distanceMeters` should store the measured GPS distance for that lap
- `currentTargetDistanceMeters` should be `nil`
- if the open segment has `targetTimeSeconds`, the lap should auto-complete on time and use `source = autoTime`

#### Distance mode

For each lap:

- lap distance = the target distance from the **current segment** in the interval plan
- after each active lap, the segment counter advances:
  - increment the repeat counter for the current segment
  - if the repeat count is reached, advance to the next segment
  - if already at the last segment and its repeats are exhausted or unlimited, remain on the last segment
- rest laps do not advance the segment counter
- this applies to both active and rest laps only if explicitly desired by product rules

Recommended product rule:

- for **active** laps in distance mode, use the current segment's target distance
- for **rest** laps in distance mode, default distance to `0` unless user explicitly marks rest as moving distance in a future version

### Average speed calculation

For each lap:

- `averageSpeedMetersPerSecond = distanceMeters / durationSeconds`
- if duration is zero, store speed as zero

### Heart rate calculation per lap

For each lap:

- collect all heart-rate samples whose timestamps fall within lap start/end
- lap average heart rate = arithmetic mean of those samples
- if no samples exist, store null

### Rest mode semantics

When entering rest mode:

- overall session continues
- next segment type becomes `rest`
- elapsed timer never stops

The end-session flow is a three-step confirmation sequence:

1. **Rest** (blue circle) – enters rest state; button changes to a red ✕.
2. **✕** (red circle) – commits the current lap as a card, stops the timer; button changes to a red "Confirm End" capsule.
3. **Confirm End** (red capsule) – ends the session in a single tap, saves to local storage, writes to HealthKit, and navigates home.

At any point before step 3, pressing the **Resume** button (the main Lap button) cancels the end flow, restarts the timer, and returns to active state.

Additional rules:

- Pressing **Rest** marks the workout as entering rest state.
- While in rest state, pressing the **Resume/Lap** button resumes active tracking and creates a new lap.
- New laps created while in rest state are stored with `lapType = rest`.
- The heart rate display remains visible throughout all end-flow states.
- when a finite interval plan reaches `0 left` and there is no configured timed rest, the workout should automatically enter rest mode while still allowing the user to continue creating additional laps manually

---

## HealthKit / Apple Fitness integration

### Must do

On session completion, write:

- a HealthKit workout sample
- total duration
- total distance
- route when GPS data is available and permitted
- workout activity type chosen for running-style intervals
- heart-rate samples gathered through workout collection
- workout events / metadata where possible to represent laps, rests, and splits

### Canonical source of truth

The app’s own local session store is the canonical source for:

- every lap
- lap order
- lap type
- per-lap average speed
- per-lap average heart rate
- per-lap distance
- per-lap duration

### Important implementation warning

The code generator must not assume Apple Fitness will visually display:

- every custom lap row
- rest/activity split labels
- custom average speed per lap
- custom lap metadata in the exact layout of the app

So the export pipeline must be:

1. save exact lap model locally
2. save best-possible workout representation to HealthKit
3. link the local session to the HealthKit workout identifier when available

---

## Performance requirements

### Startup performance

- App launch should render Home quickly from local storage.
- Avoid expensive HealthKit reads on first frame.
- Do not load full lap arrays for all history sessions on launch.
- Read only summary fields needed for top 3 recent sessions.

### Active session performance

- Timer UI should use a stable update mechanism, not heavy state churn.
- Heart rate and distance updates should be debounced/throttled to avoid unnecessary UI redraws.
- Lap cards should only re-render when a lap is completed or visible values change.

### Storage performance

- Save completed session atomically.
- Avoid writing every second to persistent storage.
- During workout, keep state in memory and checkpoint only what is needed for recovery.
- A lightweight recovery snapshot may be refreshed on important state changes and at most once per elapsed second.

---

## Accessibility and usability

- Large tap targets.
- Large text for timer and last-lap stats.
- High contrast.
- Use haptics for key actions:
  - Get Ready
  - Start
  - Lap
  - Rest
  - End

- Use short labels with minimal clutter.
- Prefer monospaced numerals for time.

---

## Edge cases

- App restarts during an active workout: offer recovery from the persisted snapshot if recoverable.
- HealthKit authorization denied: app should still work with local history, but show that Health/Fitness sync is unavailable.
- GPS unavailable: allow session to continue, but mark distance accuracy as degraded.
- Manual distance invalid or empty: Start button disabled.
- Heart rate unavailable: show `—` and continue.
- Ending session with no completed lap yet: commit current segment if meaningful.
- Very short accidental session: still store if user ends it, unless explicitly under a discard threshold.

---

## Suggested state model

### App state enums

```text
AppScreenState:
- home
- preStart
- intervalLibrary
- activeSession
- sessionDetail(sessionID)
- historySetup(sessionID)

WorkoutRunState:
- idle
- ready
- active
- rest
- paused
- ending
- ended
```

### Active workout controller responsibilities

Create a single workout session controller responsible for:

- HealthKit workout lifecycle
- elapsed time source
- current heart rate
- cumulative distance
- open lap segment
- completed lap array
- rest/active state
- save/export on finish

UI should observe this controller rather than embedding workout logic directly in views.

---

## Precise UI acceptance criteria

### Home screen acceptance criteria

- Shows one centered Get Ready button.
- Shows up to 3 recent sessions below.
- Each recent row shows total laps, average speed, total time, total distance.
- Tapping a row opens session detail.
- If more history exists, shows Load More.

### Session detail acceptance criteria

- Displays a date-range header and compact stats grid.
- Displays all laps in order.
- Each lap shows time used plus the relevant distance/pace metrics for the active tracking mode.
- Includes a reuse action that loads the saved interval plan back into setup.

### Pre-start acceptance criteria

- Start button visible at top.
- Settings scroll vertically.
- Tracking mode supports Distance, Dual, and GPS.
- Manual-interval modes reveal interval editing and library browsing.
- Settings persist across restarts.

### Active session acceptance criteria

- Large bold elapsed timer visible.
- Horizontal scroll area of recent lap cards visible.
- Latest lap appears on right.
- Lap counter remains visible across active session states.
- Rest does not stop timer.
- Pause freezes elapsed workout time until resumed.
- Top-right shows live heart rate.
- Action Button can trigger Get Ready, Start, and Lap depending on context.
- Strong haptic feedback occurs for primary actions.

### Persistence acceptance criteria

- Completed sessions are saved locally.
- Completed sessions are exported to HealthKit/Fitness as fully as platform allows.
- App local history remains complete even if Fitness display is less detailed.
- In-progress workouts are recoverable from a persisted snapshot after relaunch.

---

## Recommended implementation details for the coding AI

### Architecture

Use MVVM or a small unidirectional state architecture:

- `HomeViewModel`
- `HistoryDetailViewModel`
- `PreStartViewModel`
- `WorkoutSessionController`
- `HealthKitManager`
- `PersistenceManager`
- `SettingsStore`

### Suggested modules

- `UI/`
- `Domain/`
- `Health/`
- `Persistence/`
- `Workout/`

### Timer implementation

Do not build elapsed time by incrementing a counter every second. Instead:

- store `sessionStartDate`
- derive elapsed time from current clock minus start date
- this is more robust during backgrounding and frame drops

### Formatting helpers

Provide reusable formatters for:

- time (`HH:MM:SS` or `MM:SS`)
- meters/kilometers
- speed (`m/s`, optionally later min/km)
- heart rate (`bpm`)

---

## Explicit build instructions for the coding AI

1. Build a watchOS SwiftUI app named **Rundr**.
2. Make the watch app the primary experience.
3. Implement the four screens exactly as described.
4. Persist settings using AppStorage/UserDefaults.
5. Persist sessions and laps locally using SwiftData or Core Data.
6. Create a dedicated workout controller for live workout state.
7. Integrate HealthKit workout session APIs for heart rate, distance, and workout saving.
8. Support GPS mode and distance-distance mode.
9. Ensure the timer keeps running during rest mode.
10. Make Rest convert to End after being pressed.
11. Append newest lap cards to the right in the horizontal lap list.
12. Add strong haptic feedback to Get Ready, Start, Lap, Rest, End.
13. On finish, save locally first, then export to HealthKit.
14. Treat local lap history as the source of truth.
15. Optimize home-screen loading for speed by reading only recent summary rows first.

---

## Open questions that should be decided before code generation

These are the only product ambiguities that remain:

- Should there be an explicit **Resume** button after Rest in v1, or should rest only be ended by creating more laps and eventually pressing End?
- In **distance mode**, should rest laps always have zero distance?
- Should average speed also be shown in another unit such as min/km?
- Should a phone companion app exist, or watch-only for v1?

If no product answer is provided, use these defaults:

- no Resume button in v1
- rest laps in distance mode use distance `0`
- speed unit is `m/s`
- watch-only app for v1

---

## Final instruction to the coding AI

When platform limitations conflict with the desired Apple Fitness display, do **not** compromise the app’s own data model. Preserve exact lap data locally and export the richest HealthKit representation available, while keeping the in-app history complete and accurate.
