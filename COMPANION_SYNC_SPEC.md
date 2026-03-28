# Rundr Companion Sync Spec

## Goal

Extend Rundr from a watch-only app into a watch-first system with:

- a usable iPhone companion app
- live workout mirroring from Watch to iPhone
- reliable finished-session delivery from Watch to iPhone
- conflict-safe session import and dedupe by session ID
- CloudKit-backed persistence for eventual cross-device sync

The watch remains the only workout execution engine.

## Product Rules

### Watch authority

The Apple Watch is the sole authority for:

- HealthKit workout sessions
- heart-rate collection
- GPS collection
- lap marking
- rest state transitions
- final workout assembly

The iPhone companion must never start or run workouts itself.

### Session identity

Every workout receives a stable `sessionID` when the workout starts, not when it ends.

That ID must flow through:

- live workout state payloads
- ongoing workout recovery snapshots
- the final persisted session model
- WatchConnectivity transfer payloads
- iPhone import and dedupe
- CloudKit replication

### Sync transport split

Use two transport paths:

- `updateApplicationContext` for live workout state
- `transferFile` for completed session payloads

Live state is ephemeral and may be replaced by a newer payload.
Completed sessions are durable and must survive app suspension.

### Persistence merge rules

Use `sessionID` as the identity key.

Merge policy:

1. If no local session exists with that `sessionID`, insert it.
2. If a local session exists and the incoming `updatedAt` is newer, update it.
3. If `updatedAt` ties, use `deviceSource` as a deterministic tie-breaker.
4. If the incoming payload loses the tie-break, ignore it.

Lap merge policy:

- merge by lap ID
- update existing laps in place when IDs match
- insert missing laps
- delete obsolete laps not present in the newer payload

### CloudKit role

CloudKit is eventual replication, not the primary delivery path.

Immediate companion updates come from WatchConnectivity.
CloudKit provides durable replication and recovery across devices.

## Data Contracts

### SessionSyncEnvelope

- `schemaVersion: Int`
- `session: SessionSyncRecord`

### SessionSyncRecord

- `id: UUID`
- `startedAt: Date`
- `endedAt: Date`
- `durationSeconds: Double`
- `mode: TrackingMode`
- `sportVariantRaw: String?`
- `distanceLapDistanceMeters: Double?`
- `totalDistanceMeters: Double`
- `totalGPSDistanceMeters: Double?`
- `averageSpeedMetersPerSecond: Double`
- `totalLaps: Int`
- `laps: [LapSyncRecord]`
- `deviceSource: String`
- `healthKitWorkoutUUID: UUID?`
- `createdAt: Date`
- `updatedAt: Date`
- `snapshotWorkoutPlan: WorkoutPlanSnapshot`

### LapSyncRecord

- `id: UUID`
- `index: Int`
- `startedAt: Date`
- `endedAt: Date`
- `durationSeconds: Double`
- `distanceMeters: Double`
- `gpsDistanceMeters: Double?`
- `averageSpeedMetersPerSecond: Double`
- `averageHeartRateBPM: Double?`
- `lapType: LapType`
- `source: LapSource`

### LiveWorkoutStateRecord

- `sessionID: UUID`
- `startedAt: Date`
- `updatedAt: Date`
- `runState: WorkoutRunState`
- `trackingMode: TrackingMode`
- `elapsedSeconds: Double`
- `lapElapsedSeconds: Double`
- `completedLapCount: Int`
- `cumulativeDistanceMeters: Double`
- `cumulativeGPSDistanceMeters: Double?`
- `currentHeartRate: Double?`
- `currentTargetDistanceMeters: Double?`
- `restElapsedSeconds: Int?`
- `restDurationSeconds: Int?`
- `isGPSActive: Bool`

## Implementation Plan

### 1. Companion app target

Add a real iOS app entry point and SwiftUI navigation for:

- live workout summary card
- synced session history
- session detail view

### 2. Shared sync models

Create transport DTOs shared by Watch and iPhone.
Never send SwiftData `@Model` objects directly over WatchConnectivity.

### 3. Stable active session IDs

Generate the workout session UUID when a workout starts.
Persist it in recovery snapshots and use it when constructing the final `Session`.

### 4. WatchConnectivity manager

Create a shared manager responsible for:

- session activation
- live state publication
- completed session file transfer
- completed session import on iPhone

### 5. Dedupe-safe persistence

Extend persistence with:

- session upsert by `sessionID`
- timestamp-based conflict handling
- lap merge and deletion

### 6. CloudKit-backed SwiftData

Prefer a CloudKit-enabled `ModelConfiguration` and fall back to local-only storage if unavailable.

### 7. Verification

Add tests for:

- sync DTO conversion
- recovery snapshot session ID round-trip
- upsert insert behavior
- upsert replace behavior for newer payloads
- duplicate payload rejection for older payloads

## Non-Goals

This slice does not add:

- workout start or lap controls on iPhone
- HealthKit workout execution on iPhone
- bidirectional session editing
- CloudKit conflict UI