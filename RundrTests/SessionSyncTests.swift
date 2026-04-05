import SwiftData
import XCTest
@testable import Rundr

/// Tests for Watch ↔ iPhone session sync contracts: merge policy, lap merge, and wire payloads.
/// Transport (`WatchConnectivitySyncManager`) is not unit-tested here; logic lives in `SessionSyncRecord` + `PersistenceManager.upsertSessionRecord`.
final class SessionSyncTests: XCTestCase {

    // MARK: - shouldReplace (conflict resolution)

    func testShouldReplacePrefersNewerUpdatedAt() {
        let id = UUID()
        let t0 = Date().addingTimeInterval(-100)
        let t1 = Date()

        let existing = makeSession(id: id, updatedAt: t0, deviceSource: "device-a")
        let incoming = makeSessionSyncRecord(id: id, updatedAt: t1, deviceSource: "device-b")

        XCTAssertTrue(incoming.shouldReplace(existingSession: existing))
    }

    func testShouldReplaceRejectsOlderUpdatedAt() {
        let id = UUID()
        let older = Date().addingTimeInterval(-50)
        let newer = Date()

        let existing = makeSession(id: id, updatedAt: newer, deviceSource: "device-a")
        let incoming = makeSessionSyncRecord(id: id, updatedAt: older, deviceSource: "device-b")

        XCTAssertFalse(incoming.shouldReplace(existingSession: existing))
    }

    func testShouldReplaceUsesLexicographicDeviceSourceTieBreakWhenUpdatedAtEqual() {
        let id = UUID()
        let t = Date()

        let existingA = makeSession(id: id, updatedAt: t, deviceSource: "A")
        let incomingB = makeSessionSyncRecord(id: id, updatedAt: t, deviceSource: "B")

        XCTAssertTrue(incomingB.shouldReplace(existingSession: existingA))

        let existingB = makeSession(id: id, updatedAt: t, deviceSource: "B")
        let incomingA = makeSessionSyncRecord(id: id, updatedAt: t, deviceSource: "A")

        XCTAssertFalse(incomingA.shouldReplace(existingSession: existingB))
    }

    func testShouldReplaceRejectsWhenUpdatedAtAndDeviceSourceMatch() {
        let id = UUID()
        let t = Date()
        let source = "same-device"

        let existing = makeSession(id: id, updatedAt: t, deviceSource: source)
        let incoming = makeSessionSyncRecord(id: id, updatedAt: t, deviceSource: source)

        XCTAssertFalse(incoming.shouldReplace(existingSession: existing))
    }

    func testSettingsSyncRecordPrefersNewerUpdatedAt() {
        let earlier = Date().addingTimeInterval(-30)
        let later = Date()
        let existing = makeSettingsSyncRecord(updatedAt: earlier, deviceSource: "watch")
        let incoming = makeSettingsSyncRecord(updatedAt: later, deviceSource: "iphone")

        XCTAssertTrue(incoming.shouldReplace(existingRecord: existing))
    }

    func testSettingsSyncRecordUsesDeviceSourceTieBreakWhenUpdatedAtEqual() {
        let timestamp = Date()
        let existing = makeSettingsSyncRecord(updatedAt: timestamp, deviceSource: "iphone")
        let incoming = makeSettingsSyncRecord(updatedAt: timestamp, deviceSource: "watch")

        XCTAssertTrue(incoming.shouldReplace(existingRecord: existing))
        XCTAssertFalse(existing.shouldReplace(existingRecord: incoming))
    }

    func testSettingsSyncRecordDecodesLegacyPayloadWithAppearanceSyncDefaultingToTrue() throws {
        let original = makeSettingsSyncRecord(updatedAt: Date(), deviceSource: "iphone")
        let data = try JSONEncoder().encode(original)
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var legacyObject = jsonObject
        legacyObject.removeValue(forKey: "syncAppearanceMode")

        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject, options: [.sortedKeys])
        let decoded = try JSONDecoder().decode(SettingsSyncRecord.self, from: legacyData)

        XCTAssertTrue(decoded.syncAppearanceMode)
        XCTAssertEqual(decoded.appearanceMode, original.appearanceMode)
    }

    // MARK: - Persistence upsert + apply (lap merge)

    @MainActor
    func testUpsertSessionRecordIgnoresOlderPayload() {
        let persistence = PersistenceManager(inMemory: true)
        let sessionID = UUID()
        let newerTime = Date()
        let olderTime = newerTime.addingTimeInterval(-60)

        let newer = makeSessionSyncRecord(
            id: sessionID,
            updatedAt: newerTime,
            deviceSource: "watch",
            totalDistanceMeters: 5000,
            totalLaps: 2,
            laps: [
                LapSyncRecord(lap: Lap(index: 1, startedAt: Date(), endedAt: Date(), durationSeconds: 60, distanceMeters: 400, averageSpeedMetersPerSecond: 4)),
                LapSyncRecord(lap: Lap(index: 2, startedAt: Date(), endedAt: Date(), durationSeconds: 60, distanceMeters: 400, averageSpeedMetersPerSecond: 4))
            ]
        )

        let older = makeSessionSyncRecord(
            id: sessionID,
            updatedAt: olderTime,
            deviceSource: "watch",
            totalDistanceMeters: 100,
            totalLaps: 0,
            laps: []
        )

        persistence.upsertSessionRecord(newer)
        persistence.upsertSessionRecord(older)

        let stored = persistence.fetchSession(id: sessionID)
        XCTAssertEqual(stored?.totalDistanceMeters, 5000)
        XCTAssertEqual(stored?.totalLaps, 2)
        XCTAssertEqual(stored?.laps.count, 2)
    }

    @MainActor
    func testApplyMergesLapsByIdDeletesMissingAndUpdatesExisting() throws {
        let persistence = PersistenceManager(inMemory: true)
        let sessionID = UUID()
        let lap1ID = UUID()
        let lap2ID = UUID()
        let lap3ID = UUID()
        let base = Date().addingTimeInterval(-600)

        let lap1 = Lap(
            id: lap1ID,
            index: 1,
            startedAt: base,
            endedAt: base.addingTimeInterval(60),
            durationSeconds: 60,
            distanceMeters: 400,
            averageSpeedMetersPerSecond: 4
        )
        let lap2 = Lap(
            id: lap2ID,
            index: 2,
            startedAt: base.addingTimeInterval(60),
            endedAt: base.addingTimeInterval(120),
            durationSeconds: 60,
            distanceMeters: 400,
            averageSpeedMetersPerSecond: 4
        )

        let initial = makeSessionSyncRecord(
            id: sessionID,
            updatedAt: Date().addingTimeInterval(-10),
            deviceSource: "watch",
            totalLaps: 2,
            laps: [LapSyncRecord(lap: lap1), LapSyncRecord(lap: lap2)]
        )
        persistence.upsertSessionRecord(initial)

        guard let session = persistence.fetchSession(id: sessionID) else {
            XCTFail("Expected session")
            return
        }

        let lap1Updated = Lap(
            id: lap1ID,
            index: 1,
            startedAt: lap1.startedAt,
            endedAt: lap1.endedAt,
            durationSeconds: 60,
            distanceMeters: 999,
            averageSpeedMetersPerSecond: 5
        )
        let lap3 = Lap(
            id: lap3ID,
            index: 3,
            startedAt: base.addingTimeInterval(120),
            endedAt: base.addingTimeInterval(180),
            durationSeconds: 60,
            distanceMeters: 200,
            averageSpeedMetersPerSecond: 3
        )

        let merged = makeSessionSyncRecord(
            id: sessionID,
            updatedAt: Date(),
            deviceSource: "watch",
            totalLaps: 2,
            laps: [LapSyncRecord(lap: lap1Updated), LapSyncRecord(lap: lap3)]
        )

        merged.apply(to: session, in: persistence.modelContext)
        try persistence.modelContext.save()

        XCTAssertEqual(session.laps.count, 2)
        XCTAssertEqual(
            Set(session.laps.map(\.id)),
            Set([lap1ID, lap3ID])
        )
        let storedLap1 = session.laps.first { $0.id == lap1ID }
        XCTAssertEqual(storedLap1?.distanceMeters, 999)

        let lap2Descriptor = FetchDescriptor<Lap>(predicate: #Predicate { $0.id == lap2ID })
        let orphanLaps = try persistence.modelContext.fetch(lap2Descriptor)
        XCTAssertTrue(orphanLaps.isEmpty, "Lap removed from payload should be deleted from the store")
    }

    // MARK: - Wire format

    func testSessionSyncEnvelopeRoundTrip() throws {
        let session = Session(
            id: UUID(),
            startedAt: Date().addingTimeInterval(-300),
            endedAt: Date(),
            durationSeconds: 300,
            mode: .gps,
            totalDistanceMeters: 1500,
            averageSpeedMetersPerSecond: 3,
            totalLaps: 1,
            laps: [
                Lap(index: 1, startedAt: Date(), endedAt: Date(), durationSeconds: 60, distanceMeters: 400, averageSpeedMetersPerSecond: 4)
            ],
            deviceSource: "watch",
            snapshotTrackingMode: .gps
        )
        let envelope = SessionSyncEnvelope(session: SessionSyncRecord(session: session))

        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(SessionSyncEnvelope.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.session.id, envelope.session.id)
        XCTAssertEqual(decoded.session.laps.count, envelope.session.laps.count)
        XCTAssertEqual(decoded, envelope)
    }

    func testRundrPlanTransferRoundTrip() throws {
        let originPlanID = UUID()
        let sharedAt = Date().addingTimeInterval(-42)
        let transfer = RundrPlanTransfer(
            autor: "preset",
            title: "Track Night",
            description: "Fast 400s with short rest.",
            sharedAt: sharedAt,
            workoutPlan: WorkoutPlanSnapshot(
                trackingMode: .distanceDistance,
                distanceLapDistanceMeters: 400,
                distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
                restMode: .manual,
                originPlanID: originPlanID
            )
        )

        let data = try JSONEncoder().encode(transfer)
        let decoded = try JSONDecoder().decode(RundrPlanTransfer.self, from: data)

        XCTAssertEqual(decoded, transfer)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.autor, "preset")
        XCTAssertEqual(decoded.description, "Fast 400s with short rest.")
        XCTAssertEqual(decoded.sharedAt, sharedAt)
        XCTAssertEqual(decoded.workoutPlan.originPlanID, originPlanID)
    }

    func testRundrSessionTransferRoundTrip() throws {
        let record = makeSessionSyncRecord(id: UUID(), updatedAt: Date(), deviceSource: "watch")
        let sharedAt = Date().addingTimeInterval(-15)
        let transfer = RundrSessionTransfer(autor: "Sender Device", sharedAt: sharedAt, session: record)

        let data = try JSONEncoder().encode(transfer)
        let decoded = try JSONDecoder().decode(RundrSessionTransfer.self, from: data)

        XCTAssertEqual(decoded, transfer)
        XCTAssertEqual(decoded.autor, "Sender Device")
        XCTAssertEqual(decoded.sharedAt, sharedAt)
        XCTAssertEqual(decoded.session.id, record.id)
    }

    func testRundrPlanTransferLegacyDecodeDefaultsMissingSharedTimestamp() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "autor": "preset",
            "title": "Track Night",
            "workoutPlan": [
                "trackingMode": TrackingMode.distanceDistance.rawValue,
                "distanceLapDistanceMeters": 400,
                "distanceSegments": [[
                    "id": UUID().uuidString,
                    "distanceMeters": 400,
                    "distanceGoalMode": DistanceGoalMode.fixed.rawValue,
                    "repeatCount": 6,
                    "restSeconds": 60
                ]],
                "restMode": RestMode.manual.rawValue
            ]
        ], options: [.sortedKeys])

        let decoded = try JSONDecoder().decode(RundrPlanTransfer.self, from: data)

        XCTAssertEqual(decoded.sharedAt, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(decoded.title, "Track Night")
        XCTAssertNil(decoded.description)
    }

    // MARK: - Helpers

    private func makeSession(id: UUID, updatedAt: Date, deviceSource: String) -> Session {
        Session(
            id: id,
            startedAt: Date().addingTimeInterval(-600),
            endedAt: Date(),
            durationSeconds: 600,
            mode: .gps,
            totalDistanceMeters: 1000,
            averageSpeedMetersPerSecond: 3,
            totalLaps: 0,
            laps: [],
            deviceSource: deviceSource,
            createdAt: Date().addingTimeInterval(-600),
            updatedAt: updatedAt,
            snapshotTrackingMode: .gps
        )
    }

    private func makeSessionSyncRecord(
        id: UUID,
        updatedAt: Date,
        deviceSource: String,
        totalDistanceMeters: Double = 1000,
        totalLaps: Int = 0,
        laps: [LapSyncRecord] = []
    ) -> SessionSyncRecord {
        let startedAt = Date().addingTimeInterval(-600)
        return SessionSyncRecord(
            id: id,
            startedAt: startedAt,
            endedAt: Date(),
            durationSeconds: 600,
            mode: .gps,
            sportVariantRaw: nil,
            distanceLapDistanceMeters: nil,
            totalDistanceMeters: totalDistanceMeters,
            totalGPSDistanceMeters: nil,
            averageSpeedMetersPerSecond: 3,
            totalLaps: totalLaps,
            laps: laps,
            deviceSource: deviceSource,
            healthKitWorkoutUUID: nil,
            createdAt: startedAt,
            updatedAt: updatedAt,
            snapshotWorkoutPlan: WorkoutPlanSnapshot(trackingMode: .gps)
        )
    }

    private func makeSettingsSyncRecord(updatedAt: Date, deviceSource: String) -> SettingsSyncRecord {
        SettingsSyncRecord(
            trackingMode: .distanceDistance,
            distanceDistanceMeters: 400,
            distanceUnit: .km,
            primaryColor: .blue,
            restMode: .manual,
            lapAlerts: true,
            restAlerts: false,
            activeRecoveryAlerts: true,
            appearanceMode: .dark,
            syncAppearanceMode: true,
            distanceSegments: [DistanceSegment(distanceMeters: 400, repeatCount: 6, restSeconds: 60)],
            intervalPresets: [],
            updatedAt: updatedAt,
            deviceSource: deviceSource
        )
    }
}
