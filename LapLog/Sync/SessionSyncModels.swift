import Foundation
import SwiftData

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

struct SessionSyncEnvelope: Codable, Equatable {
    var schemaVersion: Int = 1
    var session: SessionSyncRecord
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

        session.laps = mergedLaps
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
}

@MainActor
final class WatchConnectivitySyncManager: NSObject, ObservableObject {
    @Published private(set) var liveWorkoutState: LiveWorkoutStateRecord?

    private weak var persistence: PersistenceManager?
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    #if canImport(WatchConnectivity)
    private let wcSession: WCSession?
    private static let liveStateContextKey = "liveWorkoutState"
    #endif

    init(persistence: PersistenceManager? = nil, fileManager: FileManager = .default) {
        self.persistence = persistence
        self.fileManager = fileManager
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

    func activate() {
        #if canImport(WatchConnectivity)
        wcSession?.activate()
        #endif
    }

    func publishLiveWorkoutState(_ state: LiveWorkoutStateRecord) {
        liveWorkoutState = state
        #if canImport(WatchConnectivity)
        guard let wcSession,
              let data = try? encoder.encode(state) else {
            return
        }
        try? wcSession.updateApplicationContext([Self.liveStateContextKey: data])
        #endif
    }

    func queueCompletedSession(_ session: Session) {
        #if canImport(WatchConnectivity)
        guard let wcSession,
              let data = try? encoder.encode(SessionSyncEnvelope(session: SessionSyncRecord(session: session))) else {
            return
        }

        let fileURL = outboxDirectoryURL.appendingPathComponent("\(session.id.uuidString).json")

        do {
            try fileManager.createDirectory(at: outboxDirectoryURL, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            wcSession.transferFile(fileURL, metadata: ["sessionID": session.id.uuidString])
        } catch {
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

    private func handleLiveWorkoutStateContext(_ applicationContext: [String: Any]) {
        guard let data = applicationContext[Self.liveStateContextKey] as? Data,
              let state = try? decoder.decode(LiveWorkoutStateRecord.self, from: data) else {
            return
        }

        liveWorkoutState = state
    }

    private func importCompletedSessionFile(at fileURL: URL) {
        guard let data = try? Data(contentsOf: fileURL),
              let envelope = try? decoder.decode(SessionSyncEnvelope.self, from: data) else {
            return
        }

        persistence?.upsertSessionRecord(envelope.session)
        if liveWorkoutState?.sessionID == envelope.session.id {
            liveWorkoutState = nil
        }
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
            self.handleLiveWorkoutStateContext(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        Task { @MainActor in
            self.importCompletedSessionFile(at: file.fileURL)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        guard error == nil else { return }
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
    }
}
#endif