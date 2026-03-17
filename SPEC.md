# LapLog Apple Watch App — Build Spec for AI Code Generation

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
- `mode: enum { gps, distanceDistance }`
- `distanceLapDistanceMeters: Double?`
- `totalDistanceMeters: Double`
- `averageSpeedMetersPerSecond: Double`
- `totalLaps: Int`
- `laps: [Lap]`
- `deviceSource: String` (for example Apple Watch model / app version)
- `healthKitWorkoutUUID: UUID?` or saved reference if available
- `createdAt: Date`
- `updatedAt: Date`

### Lap

Each lap in a session must store:

- `id: UUID`
- `index: Int` (1-based order)
- `startedAt: Date`
- `endedAt: Date`
- `durationSeconds: Double`
- `distanceMeters: Double`
- `averageSpeedMetersPerSecond: Double`
- `averageHeartRateBPM: Double?`
- `lapType: enum { active, rest }`
- `source: enum { distanceTap, autoDistance, sessionEndSplit }`

### Session settings snapshot

Each session must store the exact settings used when it began:

- `trackingMode: gps | distanceDistance`
- `distanceDistanceMeters: Double?`
- `distanceSegments: [DistanceSegment]?` (the full interval plan)
- any future settings added later

This prevents history from changing if defaults change later.

### DistanceSegment

Represents one step in an interval plan:

- `id: UUID`
- `distanceMeters: Double` — the target distance for laps in this segment (e.g. 400)
- `repeatCount: Int?` — how many laps at this distance before advancing to the next segment. `nil` means unlimited (open-ended).

Default plan: a single segment of 400 m with unlimited repeats.

---

## Settings persistence

Persist the following across app restarts:

- last selected tracking mode (`gps` or `distanceDistance`)
- last entered manual distance in meters (legacy, for backward compatibility)
- distance segments array (JSON-encoded interval plan)
- pause mode (`manual` or `autoDetect`) — manual: user taps to pause/resume; auto: HealthKit motion events pause/resume
- primary accent color (blue, green, yellow, orange, pink, dark) — white was removed; migration maps legacy "white" to blue
- any future session options

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
- average speed
- total time
- total distance

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

Show a vertically scrollable list of all laps.

Each lap row must show:

- lap number
- heart rate
- average speed
- distance
- time used
- whether it was `rest` or `activity`

#### Suggested row layout

- line 1: `Lap 4 • Activity`
- line 2: `Time: 00:01:32 • Dist: 400 m`
- line 3: `Avg Speed: 4.35 m/s • HR: 163 bpm`

#### Behavior

- Sort by lap index ascending.
- If heart rate is unavailable, show `—`.

---

### Screen 3 — Pre-Start Setup

Reached after tapping **Get Ready**.

#### Layout

- Top: large **Start** button.
- Below: vertically scrollable settings.
- Settings section order: **Settings** label (with top padding), then **Intervals** (distance segments), then **Mode** (tracking mode, pause mode, unit, color).

#### Setting 1 — Intervals (distance segments)

When `Distance` mode is selected, show an **Intervals** section first:

- list of **distance segments** forming the interval plan
- each segment has a distance value and an optional repeat count
- default: one segment of `400` meters with unlimited (∞) repeats
- user can add new segments below the existing ones
- user can tap a segment to open **SegmentEditSheet** to edit distance and repeat count
- SegmentEditSheet: distance via TextField (manual entry) and repeat count via +/- stepper; use `.textFieldStyle(.plain)` and `.scrollContentBackground(.hidden)` to avoid double backgrounds
- user can delete segments (at least one must remain)
- validate each distance as a positive number greater than 0
- store the full segment plan and restore it on next launch
- repeat count of `nil` or empty means unlimited

#### Setting 2 — Mode (tracking mode, pause, unit, color)

- **Tracking mode**: segmented control with `GPS` and `Distance`. Persist the selected value.
- **Pause mode**: `Manual` (user taps to pause/resume) or `Auto` (HealthKit motion events pause/resume). Persist the selected value.
- **Distance unit**: km or miles.
- **Primary color**: blue, green, yellow, orange, pink, dark. Persist the selected value.

#### GPS mode behavior

If `GPS` is selected:

- Intervals section is hidden or disabled
- lap distance is derived live from distance traveled between lap boundaries

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

- Center/main focus: elapsed seconds counting upward, **large and bold**
- Top left: **Rest** button
- Top right: live heart rate
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
- During rest/pause, show "Pause Mode" above the timer instead

#### Lap cards

Show recent completed laps in horizontally scrollable boxes/cards.
Each card shows:

- lap time (large)
- distance (for both GPS and distance mode when distance > 0)
- average speed / pace (smaller)
- optionally (maybe with a setting) lap label and rest/activity state (maybe just in color)

Behavior:

- newest completed lap is appended to the right
- user can scroll horizontally through previous laps
- cards must remain readable during motion
- tapping a card opens a dialog to change the lap's distance:
  - quick-pick from all unique distances defined in the interval plan
  - option to enter a custom distance manually
  - option to delete the lap

#### Top-left button state machine

Initial state during session:

- top-left button label: **Rest**

When user presses **Rest**:

- do **not** pause the overall session timer
- close the current lap if needed and mark subsequent segment as `rest`
- switch the top-left button label to **End**
- trigger strong haptic

When user presses **End**:

- finish the session
- save to local storage
- write to HealthKit
- navigate to post-save state or home
- trigger strong haptic

Important interpretation:

- `Rest` is not a stopwatch pause.
- It marks the workout as being in a rest segment.
- The session clock continues to run.

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

1. **Pause** (blue circle) – enters rest state; button changes to a red ✕.
2. **✕** (red circle) – commits the current lap as a card, stops the timer; button changes to a red "Confirm End" capsule.
3. **Confirm End** (red capsule) – ends the session in a single tap, saves to local storage, writes to HealthKit, and navigates home.

At any point before step 3, pressing the **Resume** button (the main Lap button) cancels the end flow, restarts the timer, and returns to active state.

Additional rules:

- Pressing **Pause** marks the workout as entering rest state.
- While in rest state, pressing the **Resume/Lap** button resumes active tracking and creates a new lap.
- New laps created while in rest state are stored with `lapType = rest`.
- The heart rate display remains visible throughout all end-flow states.

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

- App restarts during an active workout: restore active session if recoverable.
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
- activeSession
- sessionDetail(sessionID)

WorkoutRunState:
- idle
- ready
- active
- rest
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

- Displays all laps in order.
- Each lap shows heart rate, average speed, distance, time used, and rest/activity status.

### Pre-start acceptance criteria

- Start button visible at top.
- Settings scroll vertically.
- Tracking mode segmented control supports GPS and Distance.
- Distance mode reveals distance input in meters.
- Settings persist across restarts.

### Active session acceptance criteria

- Large bold elapsed timer visible.
- Horizontal scroll area of recent lap cards visible.
- Latest lap appears on right.
- Top-left Rest button changes to End after being pressed.
- Rest does not stop timer.
- Top-right shows live heart rate.
- Action Button can trigger Get Ready, Start, and Lap depending on context.
- Strong haptic feedback occurs for primary actions.

### Persistence acceptance criteria

- Completed sessions are saved locally.
- Completed sessions are exported to HealthKit/Fitness as fully as platform allows.
- App local history remains complete even if Fitness display is less detailed.

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

1. Build a watchOS SwiftUI app named **LapLog**.
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
