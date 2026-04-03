import Foundation
import OSLog
import SwiftData

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

struct SessionSyncEnvelope: Codable, Equatable {
    var schemaVersion: Int = 1
    var session: SessionSyncRecord
}

struct RundrPlanTransfer: Codable, Equatable {
    var schemaVersion: Int = 1
    var autor: String?
    var title: String?
    var description: String?
    var sharedAt: Date
    var workoutPlan: WorkoutPlanSnapshot

    init(
        schemaVersion: Int = 1,
        autor: String? = nil,
        title: String? = nil,
        description: String? = nil,
        sharedAt: Date = Date(),
        workoutPlan: WorkoutPlanSnapshot
    ) {
        self.schemaVersion = schemaVersion
        self.autor = autor
        self.title = title
        self.description = description
        self.sharedAt = sharedAt
        self.workoutPlan = workoutPlan
    }

    init(
        schemaVersion: Int = 1,
        autor: String? = nil,
        title: String? = nil,
        sharedAt: Date = Date(),
        workoutPlan: WorkoutPlanSnapshot
    ) {
        self.init(
            schemaVersion: schemaVersion,
            autor: autor,
            title: title,
            description: nil,
            sharedAt: sharedAt,
            workoutPlan: workoutPlan
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case autor
        case title
        case description
        case sharedAt
        case workoutPlan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        autor = try container.decodeIfPresent(String.self, forKey: .autor)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        sharedAt = try container.decodeIfPresent(Date.self, forKey: .sharedAt) ?? Date(timeIntervalSince1970: 0)
        workoutPlan = try container.decode(WorkoutPlanSnapshot.self, forKey: .workoutPlan)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(autor, forKey: .autor)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(sharedAt, forKey: .sharedAt)
        try container.encode(workoutPlan, forKey: .workoutPlan)
    }
}

struct RundrSessionTransfer: Codable, Equatable {
    var schemaVersion: Int = 1
    var autor: String?
    var sharedAt: Date
    var session: SessionSyncRecord

    init(
        schemaVersion: Int = 1,
        autor: String? = nil,
        sharedAt: Date = Date(),
        session: SessionSyncRecord
    ) {
        self.schemaVersion = schemaVersion
        self.autor = autor
        self.sharedAt = sharedAt
        self.session = session
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case autor
        case sharedAt
        case session
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        autor = try container.decodeIfPresent(String.self, forKey: .autor)
        sharedAt = try container.decodeIfPresent(Date.self, forKey: .sharedAt) ?? Date(timeIntervalSince1970: 0)
        session = try container.decode(SessionSyncRecord.self, forKey: .session)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(autor, forKey: .autor)
        try container.encode(sharedAt, forKey: .sharedAt)
        try container.encode(session, forKey: .session)
    }
}

struct SessionSyncRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var mode: TrackingMode
    var sportVariantRaw: String?
    var distanceLapDistanceMeters: Double?
    var totalDistanceMeters: Double
    var totalGPSDistanceMeters: Double?
    var averageSpeedMetersPerSecond: Double
    var totalLaps: Int
    var laps: [LapSyncRecord]
    var deviceSource: String
    var healthKitWorkoutUUID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var snapshotWorkoutPlan: WorkoutPlanSnapshot

    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Double,
        mode: TrackingMode,
        sportVariantRaw: String?,
        distanceLapDistanceMeters: Double?,
        totalDistanceMeters: Double,
        totalGPSDistanceMeters: Double?,
        averageSpeedMetersPerSecond: Double,
        totalLaps: Int,
        laps: [LapSyncRecord],
        deviceSource: String,
        healthKitWorkoutUUID: UUID?,
        createdAt: Date,
        updatedAt: Date,
        snapshotWorkoutPlan: WorkoutPlanSnapshot
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.mode = mode
        self.sportVariantRaw = sportVariantRaw
        self.distanceLapDistanceMeters = distanceLapDistanceMeters
        self.totalDistanceMeters = totalDistanceMeters
        self.totalGPSDistanceMeters = totalGPSDistanceMeters
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.totalLaps = totalLaps
        self.laps = laps
        self.deviceSource = deviceSource
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.snapshotWorkoutPlan = snapshotWorkoutPlan
    }

    init(session: Session) {
        id = session.id
        startedAt = session.startedAt
        endedAt = session.endedAt
        durationSeconds = session.durationSeconds
        mode = session.mode
        sportVariantRaw = session.sportVariantRaw
        distanceLapDistanceMeters = session.distanceLapDistanceMeters
        totalDistanceMeters = session.totalDistanceMeters
        totalGPSDistanceMeters = session.totalGPSDistanceMeters
        averageSpeedMetersPerSecond = session.averageSpeedMetersPerSecond
        totalLaps = session.totalLaps
        laps = session.laps.sorted { $0.startedAt < $1.startedAt }.map(LapSyncRecord.init(lap:))
        deviceSource = session.deviceSource
        healthKitWorkoutUUID = session.healthKitWorkoutUUID
        createdAt = session.createdAt
        updatedAt = session.updatedAt
        snapshotWorkoutPlan = session.snapshotWorkoutPlan
    }

    func makeModel() -> Session {
        Session(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            mode: mode,
            sportVariantRaw: sportVariantRaw,
            distanceLapDistanceMeters: distanceLapDistanceMeters,
            totalDistanceMeters: totalDistanceMeters,
            totalGPSDistanceMeters: totalGPSDistanceMeters,
            averageSpeedMetersPerSecond: averageSpeedMetersPerSecond,
            totalLaps: totalLaps,
            laps: laps.map { $0.makeModel() },
            deviceSource: deviceSource,
            healthKitWorkoutUUID: healthKitWorkoutUUID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            snapshotTrackingMode: snapshotWorkoutPlan.trackingMode,
            snapshotDistanceDistanceMeters: snapshotWorkoutPlan.distanceLapDistanceMeters,
            snapshotWorkoutPlan: snapshotWorkoutPlan
        )
    }

    func shouldReplace(existingSession: Session) -> Bool {
        if updatedAt != existingSession.updatedAt {
            return updatedAt > existingSession.updatedAt
        }

        if deviceSource != existingSession.deviceSource {
            return deviceSource.lexicographicallyPrecedes(existingSession.deviceSource) == false
        }

        return false
    }

    func apply(to session: Session, in modelContext: ModelContext) {
        session.startedAt = startedAt
        session.endedAt = endedAt
        session.durationSeconds = durationSeconds
        session.mode = mode
        session.sportVariantRaw = sportVariantRaw
        session.distanceLapDistanceMeters = distanceLapDistanceMeters
        session.totalDistanceMeters = totalDistanceMeters
        session.totalGPSDistanceMeters = totalGPSDistanceMeters
        session.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        session.totalLaps = totalLaps
        session.deviceSource = deviceSource
        session.healthKitWorkoutUUID = healthKitWorkoutUUID
        session.createdAt = createdAt
        session.updatedAt = updatedAt
        session.snapshotTrackingMode = snapshotWorkoutPlan.trackingMode
        session.snapshotDistanceDistanceMeters = snapshotWorkoutPlan.distanceLapDistanceMeters
        session.snapshotWorkoutPlan = snapshotWorkoutPlan

        var existingLapsByID = Dictionary(uniqueKeysWithValues: session.laps.map { ($0.id, $0) })
        var mergedLaps: [Lap] = []
        mergedLaps.reserveCapacity(laps.count)

        for lapRecord in laps {
            if let existingLap = existingLapsByID.removeValue(forKey: lapRecord.id) {
                lapRecord.apply(to: existingLap)
                mergedLaps.append(existingLap)
            } else {
                mergedLaps.append(lapRecord.makeModel())
            }
        }

        for obsoleteLap in existingLapsByID.values {
            modelContext.delete(obsoleteLap)
        }

        session.laps = mergedLaps.sorted {
            if $0.startedAt != $1.startedAt {
                return $0.startedAt < $1.startedAt
            }

            if $0.index != $1.index {
                return $0.index < $1.index
            }

            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

struct LapSyncRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var index: Int
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var distanceMeters: Double
    var gpsDistanceMeters: Double?
    var averageSpeedMetersPerSecond: Double
    var averageHeartRateBPM: Double?
    var lapType: LapType
    var source: LapSource

    init(lap: Lap) {
        id = lap.id
        index = lap.index
        startedAt = lap.startedAt
        endedAt = lap.endedAt
        durationSeconds = lap.durationSeconds
        distanceMeters = lap.distanceMeters
        gpsDistanceMeters = lap.gpsDistanceMeters
        averageSpeedMetersPerSecond = lap.averageSpeedMetersPerSecond
        averageHeartRateBPM = lap.averageHeartRateBPM
        lapType = lap.lapType
        source = lap.source
    }

    func makeModel() -> Lap {
        Lap(
            id: id,
            index: index,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            gpsDistanceMeters: gpsDistanceMeters,
            averageSpeedMetersPerSecond: averageSpeedMetersPerSecond,
            averageHeartRateBPM: averageHeartRateBPM,
            lapType: lapType,
            source: source
        )
    }

    func apply(to lap: Lap) {
        lap.index = index
        lap.startedAt = startedAt
        lap.endedAt = endedAt
        lap.durationSeconds = durationSeconds
        lap.distanceMeters = distanceMeters
        lap.gpsDistanceMeters = gpsDistanceMeters
        lap.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        lap.averageHeartRateBPM = averageHeartRateBPM
        lap.lapType = lapType
        lap.source = source
    }
}

struct LiveWorkoutStateRecord: Codable, Equatable, Identifiable {
    var sessionID: UUID
    var startedAt: Date
    var updatedAt: Date
    var runState: WorkoutRunState
    var trackingMode: TrackingMode
    var elapsedSeconds: Double
    var lapElapsedSeconds: Double
    var completedLapCount: Int
    var cumulativeDistanceMeters: Double
    var cumulativeGPSDistanceMeters: Double?
    var currentHeartRate: Double?
    var currentTargetDistanceMeters: Double?
    var restElapsedSeconds: Int?
    var restDurationSeconds: Int?
    var isGPSActive: Bool

    var id: UUID { sessionID }

    var isTerminalState: Bool {
        runState == .ended
    }
}

struct CompletedSessionTransferManifest: Codable, Equatable {
    var pendingSessionIDs: [UUID] = []
}

struct CompletedSessionAcknowledgementManifest: Codable, Equatable {
    var acknowledgedSessionIDs: [UUID] = []
}

struct SettingsSyncRecord: Codable, Equatable {
    var trackingMode: TrackingMode
    var distanceDistanceMeters: Double
    var distanceUnit: DistanceUnit
    var primaryColor: PrimaryColorOption
    var restMode: RestMode
    var lapAlerts: Bool
    var restAlerts: Bool
    var appearanceMode: AppearanceMode
    var syncAppearanceMode: Bool
    var distanceSegments: [DistanceSegment]
    var workoutPlanOriginID: UUID? = nil
    var intervalPresets: [IntervalPreset]
    var updatedAt: Date
    var deviceSource: String

    init(
        trackingMode: TrackingMode,
        distanceDistanceMeters: Double,
        distanceUnit: DistanceUnit,
        primaryColor: PrimaryColorOption,
        restMode: RestMode,
        lapAlerts: Bool,
        restAlerts: Bool,
        appearanceMode: AppearanceMode,
        syncAppearanceMode: Bool = true,
        distanceSegments: [DistanceSegment],
        workoutPlanOriginID: UUID? = nil,
        intervalPresets: [IntervalPreset],
        updatedAt: Date,
        deviceSource: String
    ) {
        self.trackingMode = trackingMode
        self.distanceDistanceMeters = distanceDistanceMeters
        self.distanceUnit = distanceUnit
        self.primaryColor = primaryColor
        self.restMode = restMode
        self.lapAlerts = lapAlerts
        self.restAlerts = restAlerts
        self.appearanceMode = appearanceMode
        self.syncAppearanceMode = syncAppearanceMode
        self.distanceSegments = distanceSegments
        self.workoutPlanOriginID = workoutPlanOriginID
        self.intervalPresets = intervalPresets
        self.updatedAt = updatedAt
        self.deviceSource = deviceSource
    }

    private enum CodingKeys: String, CodingKey {
        case trackingMode
        case distanceDistanceMeters
        case distanceUnit
        case primaryColor
        case restMode
        case lapAlerts
        case restAlerts
        case appearanceMode
        case syncAppearanceMode
        case distanceSegments
        case workoutPlanOriginID
        case intervalPresets
        case updatedAt
        case deviceSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackingMode = try container.decode(TrackingMode.self, forKey: .trackingMode)
        distanceDistanceMeters = try container.decode(Double.self, forKey: .distanceDistanceMeters)
        distanceUnit = try container.decode(DistanceUnit.self, forKey: .distanceUnit)
        primaryColor = try container.decode(PrimaryColorOption.self, forKey: .primaryColor)
        restMode = try container.decode(RestMode.self, forKey: .restMode)
        lapAlerts = try container.decode(Bool.self, forKey: .lapAlerts)
        restAlerts = try container.decode(Bool.self, forKey: .restAlerts)
        appearanceMode = try container.decode(AppearanceMode.self, forKey: .appearanceMode)
        syncAppearanceMode = try container.decodeIfPresent(Bool.self, forKey: .syncAppearanceMode) ?? true
        distanceSegments = try container.decode([DistanceSegment].self, forKey: .distanceSegments)
        workoutPlanOriginID = try container.decodeIfPresent(UUID.self, forKey: .workoutPlanOriginID)
        intervalPresets = try container.decode([IntervalPreset].self, forKey: .intervalPresets)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deviceSource = try container.decode(String.self, forKey: .deviceSource)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trackingMode, forKey: .trackingMode)
        try container.encode(distanceDistanceMeters, forKey: .distanceDistanceMeters)
        try container.encode(distanceUnit, forKey: .distanceUnit)
        try container.encode(primaryColor, forKey: .primaryColor)
        try container.encode(restMode, forKey: .restMode)
        try container.encode(lapAlerts, forKey: .lapAlerts)
        try container.encode(restAlerts, forKey: .restAlerts)
        try container.encode(appearanceMode, forKey: .appearanceMode)
        try container.encode(syncAppearanceMode, forKey: .syncAppearanceMode)
        try container.encode(distanceSegments, forKey: .distanceSegments)
        try container.encodeIfPresent(workoutPlanOriginID, forKey: .workoutPlanOriginID)
        try container.encode(intervalPresets, forKey: .intervalPresets)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(deviceSource, forKey: .deviceSource)
    }

    func shouldReplace(existingRecord: SettingsSyncRecord) -> Bool {
        if updatedAt != existingRecord.updatedAt {
            return updatedAt > existingRecord.updatedAt
        }

        if deviceSource != existingRecord.deviceSource {
            return deviceSource.lexicographicallyPrecedes(existingRecord.deviceSource) == false
        }

        return false
    }
}

#if canImport(WatchConnectivity)
private enum WatchConnectivitySyncKeys {
    static let liveStateContext = "liveWorkoutState"
    static let completedSessionAcknowledgement = "completedSessionAcknowledgement"
    static let completedSessionAcknowledgementsContext = "completedSessionAcknowledgements"
    static let completedSessionEnvelope = "completedSessionEnvelope"
    static let settingsContext = "settingsSyncRecord"
}
#endif

final class CompletedSessionTransferStore {
    private let userDefaults: UserDefaults
    private let manifestKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        manifestKey: String = "pendingCompletedSessionTransfersJSON"
    ) {
        self.userDefaults = userDefaults
        self.manifestKey = manifestKey
    }

    var pendingSessionIDs: [UUID] {
        manifest.pendingSessionIDs
    }

    func markPending(_ sessionID: UUID) {
        var ids = manifest.pendingSessionIDs
        guard !ids.contains(sessionID) else { return }
        ids.append(sessionID)
        saveManifest(CompletedSessionTransferManifest(pendingSessionIDs: ids))
    }

    func clearPending(_ sessionID: UUID) {
        let ids = manifest.pendingSessionIDs.filter { $0 != sessionID }
        saveManifest(CompletedSessionTransferManifest(pendingSessionIDs: ids))
    }

    private var manifest: CompletedSessionTransferManifest {
        guard let json = userDefaults.string(forKey: manifestKey),
              let data = json.data(using: .utf8),
              let manifest = try? decoder.decode(CompletedSessionTransferManifest.self, from: data) else {
            return CompletedSessionTransferManifest()
        }
        return manifest
    }

    private func saveManifest(_ manifest: CompletedSessionTransferManifest) {
        guard let data = try? encoder.encode(manifest),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        userDefaults.set(json, forKey: manifestKey)
    }
}

final class CompletedSessionAcknowledgementStore {
    private let userDefaults: UserDefaults
    private let manifestKey: String
    private let maxStoredSessionCount: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        manifestKey: String = "completedSessionAcknowledgementsJSON",
        maxStoredSessionCount: Int = 20
    ) {
        self.userDefaults = userDefaults
        self.manifestKey = manifestKey
        self.maxStoredSessionCount = max(1, maxStoredSessionCount)
    }

    var acknowledgedSessionIDs: [UUID] {
        manifest.acknowledgedSessionIDs
    }

    func markAcknowledged(_ sessionID: UUID) {
        var ids = manifest.acknowledgedSessionIDs.filter { $0 != sessionID }
        ids.append(sessionID)

        if ids.count > maxStoredSessionCount {
            ids = Array(ids.suffix(maxStoredSessionCount))
        }

        saveManifest(CompletedSessionAcknowledgementManifest(acknowledgedSessionIDs: ids))
    }

    private var manifest: CompletedSessionAcknowledgementManifest {
        guard let json = userDefaults.string(forKey: manifestKey),
              let data = json.data(using: .utf8),
              let manifest = try? decoder.decode(CompletedSessionAcknowledgementManifest.self, from: data) else {
            return CompletedSessionAcknowledgementManifest()
        }

        return manifest
    }

    private func saveManifest(_ manifest: CompletedSessionAcknowledgementManifest) {
        guard let data = try? encoder.encode(manifest),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        userDefaults.set(json, forKey: manifestKey)
    }
}

final class SettingsSyncMetadataStore {
    private let userDefaults: UserDefaults
    private let recordKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        recordKey: String = "latestSettingsSyncRecordJSON"
    ) {
        self.userDefaults = userDefaults
        self.recordKey = recordKey
    }

    var latestRecord: SettingsSyncRecord? {
        get {
            guard let json = userDefaults.string(forKey: recordKey),
                  let data = json.data(using: .utf8) else {
                return nil
            }

            return try? decoder.decode(SettingsSyncRecord.self, from: data)
        }
        set {
            guard let newValue else {
                userDefaults.removeObject(forKey: recordKey)
                return
            }

            guard let data = try? encoder.encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }

            userDefaults.set(json, forKey: recordKey)
        }
    }
}

@MainActor
final class WatchConnectivitySyncManager: NSObject, ObservableObject {
    @Published private(set) var liveWorkoutState: LiveWorkoutStateRecord?
    @Published private(set) var pendingCompletedSessionIDs: Set<UUID>

    private static let logger = Logger(subsystem: "Rundr", category: "WatchConnectivitySync")

    private weak var persistence: PersistenceManager?
    private weak var settings: SettingsStore?
    private let fileManager: FileManager
    private let transferStore: CompletedSessionTransferStore
    private let acknowledgementStore: CompletedSessionAcknowledgementStore
    private let settingsMetadataStore: SettingsSyncMetadataStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var isApplyingIncomingSettings = false
    private var latestLiveWorkoutStateData: Data?
    private var latestSettingsData: Data?

    #if canImport(WatchConnectivity)
    private let wcSession: WCSession?
    #endif

    init(
        persistence: PersistenceManager? = nil,
        fileManager: FileManager = .default,
        transferStore: CompletedSessionTransferStore = CompletedSessionTransferStore(),
        acknowledgementStore: CompletedSessionAcknowledgementStore = CompletedSessionAcknowledgementStore(),
        settingsMetadataStore: SettingsSyncMetadataStore = SettingsSyncMetadataStore()
    ) {
        self.persistence = persistence
        self.fileManager = fileManager
        self.transferStore = transferStore
        self.acknowledgementStore = acknowledgementStore
        self.settingsMetadataStore = settingsMetadataStore
        self.pendingCompletedSessionIDs = Set(transferStore.pendingSessionIDs)
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            wcSession = WCSession.default
        } else {
            wcSession = nil
        }
        #endif
        super.init()
        #if canImport(WatchConnectivity)
        wcSession?.delegate = self
        #endif
    }

    func attachPersistence(_ persistence: PersistenceManager) {
        self.persistence = persistence
    }

    func attachSettings(_ settings: SettingsStore) {
        self.settings = settings
    }

    func activate() {
        #if canImport(WatchConnectivity)
        Self.logger.log("Activating WatchConnectivity session. Pending IDs: \(self.pendingCompletedSessionIDs.count)")
        wcSession?.activate()
        if let applicationContext = wcSession?.receivedApplicationContext {
            Self.logger.log("Processing cached application context during activate. Keys: \(applicationContext.keys.sorted().joined(separator: ","))")
            handleApplicationContext(applicationContext)
        }
        publishSettingsSnapshot()
        publishCompletedSessionAcknowledgementsIfNeeded()
        retryPendingCompletedSessions()
        #endif
    }

    func publishSettingsSnapshot(updatedAt: Date = Date()) {
        #if canImport(WatchConnectivity)
        guard !isApplyingIncomingSettings,
              let settings else {
            return
        }

        let record = settings.makeSettingsSyncRecord(
            updatedAt: updatedAt,
            deviceSource: localSettingsDeviceSource
        )
        settingsMetadataStore.latestRecord = record

        guard let data = try? encoder.encode(record) else {
            return
        }
        latestSettingsData = data
        publishApplicationContext()
        #endif
    }

    func publishLiveWorkoutState(_ state: LiveWorkoutStateRecord) {
        liveWorkoutState = state
        #if canImport(WatchConnectivity)
        guard let wcSession,
              let data = try? encoder.encode(state) else {
            return
        }
        _ = wcSession
        latestLiveWorkoutStateData = data
        publishApplicationContext()
        #endif
    }

    func hasPendingCompletedSessionTransfer(for sessionID: UUID) -> Bool {
        pendingCompletedSessionIDs.contains(sessionID)
    }

    func queueCompletedSession(_ session: Session) {
        #if canImport(WatchConnectivity)
        Self.logger.log("Queueing completed session \(session.id.uuidString, privacy: .public)")
        let envelope = SessionSyncEnvelope(session: SessionSyncRecord(session: session))
        guard let data = try? encoder.encode(envelope) else {
            Self.logger.error("Failed to encode completed session \(session.id.uuidString, privacy: .public)")
            return
        }

        let fileURL = outboxDirectoryURL.appendingPathComponent("\(session.id.uuidString).json")

        do {
            try fileManager.createDirectory(at: outboxDirectoryURL, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            markPendingTransfer(session.id)

            if sendCompletedSessionInteractivelyIfPossible(envelope) {
                Self.logger.log("Completed session \(session.id.uuidString, privacy: .public) sent interactively")
                return
            }

            Self.logger.log("Completed session \(session.id.uuidString, privacy: .public) falling back to file transfer")
            transferCompletedSessionIfPossible(sessionID: session.id)
        } catch {
            Self.logger.error("Failed to queue completed session \(session.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        #endif
    }

    #if canImport(WatchConnectivity)
    private var outboxDirectoryURL: URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseDirectory.appendingPathComponent("WatchConnectivityOutbox", isDirectory: true)
    }

    private func transferCompletedSessionIfPossible(sessionID: UUID) {
        guard let wcSession else { return }

        Self.logger.log("Attempting file transfer for completed session \(sessionID.uuidString, privacy: .public)")

        let fileURL = outboxDirectoryURL.appendingPathComponent("\(sessionID.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            Self.logger.log("No outbox file exists for \(sessionID.uuidString, privacy: .public); clearing pending state")
            clearPendingTransfer(sessionID)
            return
        }

        wcSession.transferFile(fileURL, metadata: ["sessionID": sessionID.uuidString])
    }

    private func retryPendingCompletedSessions() {
        Self.logger.log("Retrying pending completed sessions: \(self.transferStore.pendingSessionIDs.map(\.uuidString).joined(separator: ","), privacy: .public)")
        for sessionID in self.transferStore.pendingSessionIDs {
            if sendCompletedSessionInteractivelyIfPossible(sessionID: sessionID) {
                continue
            }

            transferCompletedSessionIfPossible(sessionID: sessionID)
        }
    }

    @discardableResult
    private func sendCompletedSessionInteractivelyIfPossible(_ envelope: SessionSyncEnvelope) -> Bool {
        guard let wcSession,
              wcSession.isReachable,
              let data = try? encoder.encode(envelope) else {
            Self.logger.log("Interactive send unavailable for completed session \(envelope.session.id.uuidString, privacy: .public)")
            return false
        }

        let sessionID = envelope.session.id
        Self.logger.log("Sending completed session interactively \(sessionID.uuidString, privacy: .public)")
        wcSession.sendMessageData(
            data,
            replyHandler: { _ in
                Task { @MainActor in
                    Self.logger.log("Received interactive acknowledgement for completed session \(sessionID.uuidString, privacy: .public)")
                    self.acknowledgeCompletedSession(sessionID)
                }
            },
            errorHandler: { _ in
                Task { @MainActor in
                    Self.logger.error("Interactive send failed for completed session \(sessionID.uuidString, privacy: .public); retrying with file transfer")
                    self.transferCompletedSessionIfPossible(sessionID: sessionID)
                }
            }
        )
        return true
    }

    @discardableResult
    private func sendCompletedSessionInteractivelyIfPossible(sessionID: UUID) -> Bool {
        let fileURL = outboxDirectoryURL.appendingPathComponent("\(sessionID.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL),
              let envelope = try? decoder.decode(SessionSyncEnvelope.self, from: data) else {
            return false
        }

        return sendCompletedSessionInteractivelyIfPossible(envelope)
    }

    private func acknowledgeCompletedSession(_ sessionID: UUID) {
        Self.logger.log("Acknowledging completed session \(sessionID.uuidString, privacy: .public)")
        clearPendingTransfer(sessionID)

        let fileURL = outboxDirectoryURL.appendingPathComponent("\(sessionID.uuidString).json")
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func sendCompletedSessionAcknowledgement(for sessionID: UUID) {
        guard let wcSession else { return }
        Self.logger.log("Sending completed session acknowledgement for \(sessionID.uuidString, privacy: .public)")
        acknowledgementStore.markAcknowledged(sessionID)
        publishCompletedSessionAcknowledgementsIfNeeded()
        wcSession.transferUserInfo([WatchConnectivitySyncKeys.completedSessionAcknowledgement: sessionID.uuidString])
    }

    private func publishCompletedSessionAcknowledgementsIfNeeded() {
        #if os(iOS)
        let sessionIDStrings = acknowledgementStore.acknowledgedSessionIDs.map(\.uuidString)
        guard !sessionIDStrings.isEmpty else { return }

        Self.logger.log("Publishing acknowledged completed sessions in application context: \(sessionIDStrings.joined(separator: ","), privacy: .public)")
        publishApplicationContext()
        #endif
    }

    private func markPendingTransfer(_ sessionID: UUID) {
        Self.logger.log("Marking completed session pending \(sessionID.uuidString, privacy: .public)")
        transferStore.markPending(sessionID)
        var updatedPendingIDs = pendingCompletedSessionIDs
        updatedPendingIDs.insert(sessionID)
        pendingCompletedSessionIDs = updatedPendingIDs
    }

    private func clearPendingTransfer(_ sessionID: UUID) {
        Self.logger.log("Clearing pending completed session \(sessionID.uuidString, privacy: .public)")
        transferStore.clearPending(sessionID)
        var updatedPendingIDs = pendingCompletedSessionIDs
        updatedPendingIDs.remove(sessionID)
        pendingCompletedSessionIDs = updatedPendingIDs
    }

    private func handleApplicationContext(_ applicationContext: [String: Any]) {
        Self.logger.log("Handling application context. Keys: \(applicationContext.keys.sorted().joined(separator: ","), privacy: .public)")
        handleLiveWorkoutStateContext(applicationContext)
        handleSettingsContext(applicationContext)
        handleCompletedSessionAcknowledgementsContext(applicationContext)
    }

    private func handleLiveWorkoutStateContext(_ applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchConnectivitySyncKeys.liveStateContext] as? Data,
              let state = try? decoder.decode(LiveWorkoutStateRecord.self, from: data) else {
            return
        }

        latestLiveWorkoutStateData = data
        liveWorkoutState = state
    }

    private func handleSettingsContext(_ applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchConnectivitySyncKeys.settingsContext] as? Data,
              let record = try? decoder.decode(SettingsSyncRecord.self, from: data) else {
            return
        }

        if let existingRecord = settingsMetadataStore.latestRecord,
           !record.shouldReplace(existingRecord: existingRecord) {
            return
        }

        settingsMetadataStore.latestRecord = record
        latestSettingsData = data

        guard let settings else { return }

        isApplyingIncomingSettings = true
        settings.apply(settingsSyncRecord: record)
        isApplyingIncomingSettings = false
    }

    private func handleCompletedSessionAcknowledgementsContext(_ applicationContext: [String: Any]) {
        guard let sessionIDStrings = applicationContext[WatchConnectivitySyncKeys.completedSessionAcknowledgementsContext] as? [String] else {
            return
        }

        Self.logger.log("Received acknowledged completed sessions from application context: \(sessionIDStrings.joined(separator: ","), privacy: .public)")

        for sessionIDString in sessionIDStrings {
            guard let sessionID = UUID(uuidString: sessionIDString) else { continue }
            acknowledgeCompletedSession(sessionID)
        }
    }

    private func importCompletedSessionFileData(_ data: Data) {
        guard let envelope = try? decoder.decode(SessionSyncEnvelope.self, from: data) else {
            Self.logger.error("Failed to decode completed session payload during import")
            return
        }

        Self.logger.log("Importing completed session \(envelope.session.id.uuidString, privacy: .public)")

        persistence?.upsertSessionRecord(envelope.session)
        sendCompletedSessionAcknowledgement(for: envelope.session.id)
        if liveWorkoutState?.sessionID == envelope.session.id {
            liveWorkoutState = nil
        }
    }

    private func importCompletedSessionFile(at fileURL: URL) {
        guard let data = try? Data(contentsOf: fileURL) else {
            return
        }

        importCompletedSessionFileData(data)
    }

    private func publishApplicationContext() {
        guard let wcSession else { return }

        var context: [String: Any] = [:]

        if let latestLiveWorkoutStateData {
            context[WatchConnectivitySyncKeys.liveStateContext] = latestLiveWorkoutStateData
        }

        if let latestSettingsData {
            context[WatchConnectivitySyncKeys.settingsContext] = latestSettingsData
        }

        #if os(iOS)
        let sessionIDStrings = acknowledgementStore.acknowledgedSessionIDs.map(\.uuidString)
        if !sessionIDStrings.isEmpty {
            context[WatchConnectivitySyncKeys.completedSessionAcknowledgementsContext] = sessionIDStrings
        }
        #endif

        guard !context.isEmpty else { return }
        try? wcSession.updateApplicationContext(context)
    }
    #endif
}

#if canImport(WatchConnectivity)
extension WatchConnectivitySyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        _ = activationState
        _ = error
        Task { @MainActor in
            Self.logger.log("WatchConnectivity activation completed. State: \(String(describing: activationState.rawValue), privacy: .public)")
            self.publishCompletedSessionAcknowledgementsIfNeeded()
            self.handleApplicationContext(session.receivedApplicationContext)
            self.publishSettingsSnapshot()
            self.retryPendingCompletedSessions()
        }
    }

	#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        _ = session
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
	#endif

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            Self.logger.log("Delegate received application context")
            self.handleApplicationContext(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        Task { @MainActor in
            Self.logger.log("Delegate received completed session file: \(file.fileURL.lastPathComponent, privacy: .public)")
            self.importCompletedSessionFile(at: file.fileURL)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let sessionIDString = userInfo[WatchConnectivitySyncKeys.completedSessionAcknowledgement] as? String,
              let sessionID = UUID(uuidString: sessionIDString) else {
            return
        }

        Task { @MainActor in
            Self.logger.log("Delegate received completed session acknowledgement userInfo for \(sessionID.uuidString, privacy: .public)")
            self.acknowledgeCompletedSession(sessionID)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data,
        replyHandler: @escaping (Data) -> Void
    ) {
        Task { @MainActor in
            Self.logger.log("Delegate received interactive completed session payload")
            self.importCompletedSessionFileData(messageData)
            replyHandler(Data())
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        guard error != nil,
              let sessionIDString = fileTransfer.file.metadata?["sessionID"] as? String,
              let sessionID = UUID(uuidString: sessionIDString) else {
            return
        }

        Task { @MainActor in
            self.markPendingTransfer(sessionID)
        }
    }
}
#endif

private extension WatchConnectivitySyncManager {
    var localSettingsDeviceSource: String {
        #if os(iOS)
        return "iphone"
        #else
        return "watch"
        #endif
    }
}
