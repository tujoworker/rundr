import Foundation
import Combine
import HealthKit
import CoreLocation
import WatchKit

@MainActor
final class WorkoutSessionController: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var runState: WorkoutRunState = .idle
    @Published var elapsedSeconds: Double = 0
    @Published var lapElapsedSeconds: Double = 0
    @Published var currentHeartRate: Double? = nil
    @Published var cumulativeDistanceMeters: Double = 0
    @Published var currentLapDistanceMeters: Double = 0
    @Published var cumulativeGPSDistanceMeters: Double = 0
    @Published var currentLapGPSDistanceMeters: Double = 0
    @Published var completedLaps: [Lap] = []
    @Published var isGPSActive: Bool = false
    /// Elapsed seconds in current timed rest. `nil` when not in a timed rest.
    @Published var restElapsedSeconds: Int? = nil
    /// Total rest duration in seconds for the current timed rest.
    @Published var restDurationSeconds: Int? = nil
    /// True when ≤5 seconds remain in a timed rest (for UI warning pulse).
    @Published var isRestWarningActive: Bool = false

    // MARK: - Settings Snapshot

    private(set) var trackingMode: TrackingMode = .gps
    private(set) var distanceLapDistanceMeters: Double = 400
    private(set) var restMode: RestMode = .manual

    private var usesGPSDistance: Bool {
        trackingMode.usesGPSDistance
    }

    private var usesManualIntervals: Bool {
        trackingMode.usesManualIntervals
    }

    // MARK: - Distance Segments

    /// Ordered list of distance segments for the workout plan.
    private(set) var distanceSegments: [DistanceSegment] = [.default]
    /// Index into `distanceSegments` for the current segment.
    private(set) var currentSegmentIndex: Int = 0
    /// How many laps have been completed in the current segment.
    private(set) var currentSegmentRepeatsDone: Int = 0

    /// The target distance for the next/current lap based on the segment plan.
    var currentTargetDistanceMeters: Double {
        guard usesManualIntervals else { return 0 }
        let segment = currentSegment
        return segment.distanceMeters
    }

    /// Effective target time for the current segment, derived from pace or direct time.
    var currentTargetTimeSeconds: Double? {
        guard usesManualIntervals else { return nil }
        return currentSegment.effectiveTargetTimeSeconds
    }

    /// All unique distances defined in the segments, for quick-pick UI.
    var availableDistances: [Double] {
        Array(Set(distanceSegments.map(\.distanceMeters))).sorted()
    }

    /// Total number of planned active intervals when all segments have explicit repeat counts.
    var totalPlannedIntervals: Int? {
        guard usesManualIntervals else { return nil }
        let counts = distanceSegments.compactMap(\.repeatCount)
        guard counts.count == distanceSegments.count else { return nil }
        return counts.reduce(0, +)
    }

    /// Remaining number of planned active intervals, including the current one.
    var remainingPlannedIntervals: Int? {
        guard let totalPlannedIntervals else { return nil }
        let completedActiveIntervals = completedLaps.filter { $0.lapType == .active }.count
        return max(0, totalPlannedIntervals - completedActiveIntervals)
    }

    private var currentSegment: DistanceSegment {
        guard currentSegmentIndex < distanceSegments.count else {
            return distanceSegments.last ?? .default
        }
        return distanceSegments[currentSegmentIndex]
    }

    // MARK: - Internal

    private var sessionStartDate: Date?
    private var currentSessionID: UUID?
    private var currentLapStartDate: Date?
    private var currentLapHeartRateSamples: [Double] = []
    private var pauseStartedAt: Date?
    private var pausedRunState: WorkoutRunState?
    private var pausedRestElapsedSeconds: Int?
    private var pausedRestDurationSeconds: Int?

    private var timerCancellable: AnyCancellable?
    private var restTimerCancellable: AnyCancellable?
    private var pendingAutoRestTask: Task<Void, Never>?
    private var healthKitManager: HealthKitManager?
    private var ongoingWorkoutStore: OngoingWorkoutStore?
    private weak var syncManager: WatchConnectivitySyncManager?
    private var lastHealthKitCumulativeDistanceMeters: Double = 0
    private var lastPersistedElapsedSecond: Int = -1

    var autoRestDetectionDelay: Duration = .seconds(10)

    // HealthKit workout session
    private var hkWorkoutSession: HKWorkoutSession?
    private var hkLiveBuilder: HKLiveWorkoutBuilder?

    // Location
    private var locationManager: CLLocationManager?
    private var lastLocation: CLLocation?

    // MARK: - Configuration

    func attachOngoingWorkoutStore(_ store: OngoingWorkoutStore) {
        ongoingWorkoutStore = store
    }

    func attachSyncManager(_ manager: WatchConnectivitySyncManager) {
        syncManager = manager
        publishLiveWorkoutStateIfNeeded()
    }

    func configure(
        trackingMode: TrackingMode,
        distanceLapDistanceMeters: Double,
        distanceSegments: [DistanceSegment] = [.default],
        restMode: RestMode = .manual,
        healthKitManager: HealthKitManager
    ) {
        cancelPendingAutoRestDetection()
        self.trackingMode = trackingMode
        self.distanceLapDistanceMeters = distanceLapDistanceMeters
        self.distanceSegments = distanceSegments.isEmpty ? [.default] : distanceSegments
        self.restMode = restMode
        self.healthKitManager = healthKitManager
        self.currentSegmentIndex = 0
        self.currentSegmentRepeatsDone = 0
    }

    func restore(snapshot: OngoingWorkoutSnapshot, healthKitManager: HealthKitManager) {
        cancelPendingAutoRestDetection()
        cancelRestTimer()
        stopTimer()
        stopLocationUpdates()

        self.healthKitManager = healthKitManager
        trackingMode = snapshot.trackingMode
        currentSessionID = snapshot.sessionID
        distanceLapDistanceMeters = snapshot.distanceLapDistanceMeters
        distanceSegments = snapshot.distanceSegments.isEmpty ? [.default] : snapshot.distanceSegments
        restMode = snapshot.restMode
        sessionStartDate = snapshot.sessionStartDate
        currentLapStartDate = snapshot.currentLapStartDate
        currentLapDistanceMeters = snapshot.currentLapDistanceMeters
        currentLapGPSDistanceMeters = snapshot.currentLapGPSDistanceMeters
        currentLapHeartRateSamples = []
        completedLaps = snapshot.completedLaps.map { $0.makeLap() }
        elapsedSeconds = snapshot.elapsedSeconds
        lapElapsedSeconds = snapshot.lapElapsedSeconds
        currentHeartRate = snapshot.currentHeartRate
        cumulativeDistanceMeters = snapshot.cumulativeDistanceMeters
        cumulativeGPSDistanceMeters = snapshot.cumulativeGPSDistanceMeters
        currentSegmentIndex = snapshot.currentSegmentIndex
        currentSegmentRepeatsDone = snapshot.currentSegmentRepeatsDone
        pauseStartedAt = snapshot.effectivePauseStartedAt
        pausedRunState = snapshot.resumeRunState
        pausedRestElapsedSeconds = snapshot.resumeRunState == .rest ? snapshot.restElapsedSeconds : nil
        pausedRestDurationSeconds = snapshot.resumeRunState == .rest ? snapshot.restDurationSeconds : nil
        restElapsedSeconds = snapshot.resumeRunState == .rest ? snapshot.restElapsedSeconds : nil
        restDurationSeconds = snapshot.resumeRunState == .rest ? snapshot.restDurationSeconds : nil
        isRestWarningActive = false
        lastHealthKitCumulativeDistanceMeters = 0
        lastLocation = nil
        hkWorkoutSession = nil
        hkLiveBuilder = nil
        runState = .paused
        isGPSActive = false
        lastPersistedElapsedSecond = Int(snapshot.elapsedSeconds)
        persistRecoverySnapshotIfNeeded()
        publishLiveWorkoutStateIfNeeded()
    }

    // MARK: - Lifecycle

    func getReady() {
        runState = .ready
        clearRecoverySnapshot()
        playHaptic(.notification)
    }

    func start() async {
        currentSessionID = UUID()
        sessionStartDate = Date()
        currentLapStartDate = Date()
        currentLapDistanceMeters = 0
        currentLapGPSDistanceMeters = 0
        currentLapHeartRateSamples = []
        completedLaps = []
        cumulativeDistanceMeters = 0
        cumulativeGPSDistanceMeters = 0
        elapsedSeconds = 0
        lapElapsedSeconds = 0
        currentHeartRate = nil
        lastHealthKitCumulativeDistanceMeters = 0
        lastLocation = nil
        clearPauseState()
        cancelPendingAutoRestDetection()
        runState = .active

        startTimer()
        await startHealthKitWorkout()
        if usesGPSDistance {
            startLocationUpdates()
        }

        lastPersistedElapsedSecond = 0
        persistRecoverySnapshotIfNeeded()
        publishLiveWorkoutStateIfNeeded()
        playHaptic(.notification)
    }

    /// Lightweight start for unit tests — skips HealthKit and location.
    func startWithoutHealthKit() {
        let start = Date(timeIntervalSinceNow: -1)
        currentSessionID = UUID()
        sessionStartDate = start
        currentLapStartDate = start
        currentLapDistanceMeters = 0
        currentLapGPSDistanceMeters = 0
        currentLapHeartRateSamples = []
        completedLaps = []
        cumulativeDistanceMeters = 0
        cumulativeGPSDistanceMeters = 0
        elapsedSeconds = 0
        lapElapsedSeconds = 0
        currentHeartRate = nil
        lastHealthKitCumulativeDistanceMeters = 0
        lastLocation = nil
        clearPauseState()
        cancelPendingAutoRestDetection()
        runState = .active
        lastPersistedElapsedSecond = 0
        persistRecoverySnapshotIfNeeded()
        publishLiveWorkoutStateIfNeeded()
    }

    func deleteLap(id: UUID) {
        guard runState == .active || runState == .rest || runState == .ending else { return }
        guard let index = completedLaps.firstIndex(where: { $0.id == id }) else { return }
        completedLaps.remove(at: index)
        recalculateCompletedLapDerivedState()
        persistRecoverySnapshotIfNeeded()
        playHaptic(.click)
    }

    func markLap(source: LapSource = .distanceTap) {
        guard runState == .active || runState == .rest || runState == .ending else { return }
        let wasResting = (runState == .rest)
        // Capture rest config before commit (which may advance the segment)
        let restSecondsBeforeCommit = (!wasResting && usesManualIntervals)
            ? currentSegment.restSeconds : nil

        if runState != .ending {
            commitCurrentLap(source: source)
        } else {
            currentLapStartDate = Date()
            currentLapDistanceMeters = 0
            currentLapHeartRateSamples = []
            lapElapsedSeconds = 0
        }

        // Auto-enter rest if the segment had restSeconds and we just finished an active lap
        if let seconds = restSecondsBeforeCommit, seconds > 0 {
            cancelRestTimer()
            startAutoRest(seconds: seconds)
        } else if !wasResting
                    && usesManualIntervals
                    && remainingPlannedIntervals == 0 {
            cancelRestTimer()
            runState = .rest
        } else {
            cancelRestTimer()
            runState = .active
            startTimer()
        }
        persistRecoverySnapshotIfNeeded()
        publishLiveWorkoutStateIfNeeded()
        playHaptic(.notification)
    }

    func commitFinalLap() {
        guard runState == .active || runState == .rest else { return }
        commitCurrentLap(source: .sessionEndSplit)
        runState = .ending
        stopTimer()
        persistRecoverySnapshotIfNeeded()
        publishLiveWorkoutStateIfNeeded()
        playHaptic(.notification)
    }

    func startRest() {
        guard runState == .active else { return }
        cancelPendingAutoRestDetection()
        playHaptic(.notification)
        runState = .rest
        persistRecoverySnapshotIfNeeded()
        publishLiveWorkoutStateIfNeeded()
    }

    func cancelRest() {
        guard runState == .rest else { return }
        cancelPendingAutoRestDetection()
        cancelRestTimer()
        playHaptic(.click)
        runState = .active
        startTimer()
        persistRecoverySnapshotIfNeeded()
        publishLiveWorkoutStateIfNeeded()
    }

    func pauseSession() {
        guard runState == .active || runState == .rest else { return }

        pauseStartedAt = Date()
        pausedRunState = runState
        pausedRestElapsedSeconds = restElapsedSeconds
        pausedRestDurationSeconds = restDurationSeconds

        cancelPendingAutoRestDetection()
        cancelRestTimer()
        stopTimer()
        stopLocationUpdates()
        pauseHealthKitWorkout()

        runState = .paused
        persistRecoverySnapshotIfNeeded()
        publishLiveWorkoutStateIfNeeded()
        playHaptic(.click)
    }

    func resumeSession() {
        guard runState == .paused, let previousRunState = pausedRunState else { return }

        applyPausedDuration(until: Date())
        let restElapsed = pausedRestElapsedSeconds ?? 0
        let restDuration = pausedRestDurationSeconds
        clearPauseState()

        runState = previousRunState
        startTimer()
        if usesGPSDistance {
            startLocationUpdates()
        }

        if previousRunState == .rest, let restDuration {
            startAutoRest(seconds: restDuration, initialElapsed: restElapsed)
        }

        if hkWorkoutSession == nil {
            lastHealthKitCumulativeDistanceMeters = 0
            Task { await startHealthKitWorkout() }
        } else {
            resumeHealthKitWorkout()
        }

        persistRecoverySnapshotIfNeeded()
        publishLiveWorkoutStateIfNeeded()
        playHaptic(.click)
    }

    func prepareForSessionEnd() {
        cancelPendingAutoRestDetection()
        cancelRestTimer()
    }

    func persistRecoverySnapshotIfNeeded() {
        persistRecoverySnapshot()
    }

    func endSession() async -> Session? {
        let endDate = Date()

        if runState == .paused {
            applyPausedDuration(until: endDate)
            if let pausedRunState {
                runState = pausedRunState
            }
            clearPauseState()
        }

        guard runState == .active || runState == .rest || runState == .ending else { return nil }

        // Commit any remaining open segment (skipped if already committed by commitFinalLap)
        if runState != .ending {
            commitCurrentLap(source: .sessionEndSplit)
        }

        cancelRestTimer()
        cancelPendingAutoRestDetection()
        runState = .ended
        stopTimer()
        stopLocationUpdates()
        publishLiveWorkoutStateIfNeeded()
        clearRecoverySnapshot()

        Task { await stopHealthKitWorkout(endDate: endDate) }

        guard let startDate = sessionStartDate else { return nil }

        let duration = endDate.timeIntervalSince(startDate)
        let totalDist = completedLaps.reduce(0) { $0 + $1.distanceMeters }
        let totalGPSDist = completedLaps.reduce(0.0) { partial, lap in
            partial + (lap.gpsDistanceMeters ?? 0)
        }
        let activeDuration = completedLaps
            .filter { $0.lapType != .rest }
            .reduce(0.0) { $0 + $1.durationSeconds }
        let avgSpeed = activeDuration > 0 && totalDist > 0 ? totalDist / activeDuration : 0

        let session = Session(
            id: currentSessionID ?? UUID(),
            startedAt: startDate,
            endedAt: endDate,
            durationSeconds: duration,
            mode: trackingMode,
            distanceLapDistanceMeters: usesManualIntervals ? distanceLapDistanceMeters : nil,
            totalDistanceMeters: totalDist,
            totalGPSDistanceMeters: usesGPSDistance ? totalGPSDist : nil,
            averageSpeedMetersPerSecond: avgSpeed,
            totalLaps: completedLaps.count,
            laps: completedLaps,
            deviceSource: deviceString(),
            snapshotTrackingMode: trackingMode,
            snapshotDistanceDistanceMeters: usesManualIntervals ? distanceLapDistanceMeters : nil,
            snapshotWorkoutPlan: WorkoutPlanSnapshot(
                trackingMode: trackingMode,
                distanceLapDistanceMeters: usesManualIntervals ? distanceLapDistanceMeters : nil,
                distanceSegments: distanceSegments,
                restMode: restMode
            )
        )

        playHaptic(.notification)
        return session
    }

    func resetForNextSession() {
        runState = .idle
        elapsedSeconds = 0
        lapElapsedSeconds = 0
        currentHeartRate = nil
        cumulativeDistanceMeters = 0
        cumulativeGPSDistanceMeters = 0
        completedLaps = []
        isGPSActive = false
        sessionStartDate = nil
        currentSessionID = nil
        currentLapStartDate = nil
        currentLapDistanceMeters = 0
        currentLapGPSDistanceMeters = 0
        currentLapHeartRateSamples = []
        currentSegmentIndex = 0
        currentSegmentRepeatsDone = 0
        lastHealthKitCumulativeDistanceMeters = 0
        lastLocation = nil
        clearPauseState()
        cancelPendingAutoRestDetection()
        cancelRestTimer()
        stopTimer()
        stopLocationUpdates()
        clearRecoverySnapshot()
    }

    func handleAutoRestMotionPause() {
        guard restMode == .autoDetect, runState == .active else { return }

        cancelPendingAutoRestDetection()
        let delay = autoRestDetectionDelay
        pendingAutoRestTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            await MainActor.run {
                self?.completePendingAutoRestDetection()
            }
        }
    }

    func handleAutoRestMotionResume() {
        cancelPendingAutoRestDetection()

        guard restMode == .autoDetect, runState == .rest else { return }
        cancelRest()
    }

    // MARK: - Timer

    private func startTimer() {
        timerCancellable = Timer.publish(every: 0.01, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.sessionStartDate else { return }
                let now = Date()
                self.elapsedSeconds = now.timeIntervalSince(start)
                if let lapStart = self.currentLapStartDate {
                    self.lapElapsedSeconds = now.timeIntervalSince(lapStart)
                }

                let elapsedSecond = Int(self.elapsedSeconds)
                if elapsedSecond != self.lastPersistedElapsedSecond {
                    self.lastPersistedElapsedSecond = elapsedSecond
                    self.persistRecoverySnapshot()
                }
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func completePendingAutoRestDetection() {
        pendingAutoRestTask = nil

        guard restMode == .autoDetect, runState == .active else { return }
        startRest()
    }

    private func cancelPendingAutoRestDetection() {
        pendingAutoRestTask?.cancel()
        pendingAutoRestTask = nil
    }

    // MARK: - Lap Commit

    /// Minimum lap duration to prevent accidental double-taps. Can be reduced for tests.
    var minimumLapDuration: TimeInterval = 0.5

    private func commitCurrentLap(source: LapSource) {
        guard let lapStart = currentLapStartDate else { return }
        let lapEnd = Date()
        let duration = lapEnd.timeIntervalSince(lapStart)
        guard duration > minimumLapDuration else { return }

        let isRest = (runState == .rest || runState == .ending)
        var distance: Double
        var gpsDistance: Double?
        if isRest {
            distance = 0
            gpsDistance = nil
        } else if usesManualIntervals {
            distance = currentTargetDistanceMeters
            gpsDistance = usesGPSDistance ? currentLapGPSDistanceMeters : nil
        } else {
            distance = currentLapGPSDistanceMeters
            gpsDistance = currentLapGPSDistanceMeters
        }
        let avgSpeed = duration > 0 && distance > 0 ? distance / duration : 0
        let avgHR: Double? = currentLapHeartRateSamples.isEmpty ? nil : currentLapHeartRateSamples.reduce(0, +) / Double(currentLapHeartRateSamples.count)

        let activeLapCount = completedLaps.filter { $0.lapType != .rest }.count
        let lapIndex = isRest ? 0 : activeLapCount + 1

        let lap = Lap(
            index: lapIndex,
            startedAt: lapStart,
            endedAt: lapEnd,
            durationSeconds: duration,
            distanceMeters: distance,
            gpsDistanceMeters: gpsDistance,
            averageSpeedMetersPerSecond: avgSpeed,
            averageHeartRateBPM: avgHR,
            lapType: isRest ? .rest : .active,
            source: source
        )
        completedLaps.append(lap)

        // Advance segment if this was an active lap in distance mode
        if !isRest && usesManualIntervals {
            advanceSegment()
        }

        // Reset for next lap
        currentLapStartDate = lapEnd
        currentLapDistanceMeters = 0
        currentLapGPSDistanceMeters = 0
        currentLapHeartRateSamples = []
        persistRecoverySnapshotIfNeeded()
    }

    /// Advances to the next repeat or next segment after completing a lap.
    private func advanceSegment() {
        let completedFromSegment = currentSegment
        currentSegmentRepeatsDone += 1
        if let count = completedFromSegment.repeatCount, currentSegmentRepeatsDone >= count {
            if currentSegmentIndex + 1 < distanceSegments.count {
                currentSegmentIndex += 1
                currentSegmentRepeatsDone = 0
            }
        }
        distanceLapDistanceMeters = currentTargetDistanceMeters
    }

    private func startAutoRest(seconds: Int, initialElapsed: Int = 0) {
        runState = .rest
        restElapsedSeconds = initialElapsed
        restDurationSeconds = seconds
        let remaining = seconds - initialElapsed
        isRestWarningActive = remaining <= 5 && remaining >= 0

        restTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self,
                      let elapsed = self.restElapsedSeconds,
                      let duration = self.restDurationSeconds else { return }
                let newElapsed = elapsed + 1
                self.restElapsedSeconds = newElapsed

                let remaining = duration - newElapsed
                if remaining <= 5 && remaining >= 0 {
                    if !self.isRestWarningActive {
                        self.isRestWarningActive = true
                    }
                    self.playHaptic(.notification)
                }

                self.persistRecoverySnapshot()
            }
    }

    private func cancelRestTimer() {
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        restElapsedSeconds = nil
        restDurationSeconds = nil
        isRestWarningActive = false
    }

    private func applyPausedDuration(until resumeDate: Date) {
        guard let pauseStartedAt else { return }
        let pausedDuration = resumeDate.timeIntervalSince(pauseStartedAt)
        guard pausedDuration > 0 else { return }

        if let startDate = sessionStartDate {
            sessionStartDate = startDate.addingTimeInterval(pausedDuration)
        }
        if let lapStartDate = currentLapStartDate {
            currentLapStartDate = lapStartDate.addingTimeInterval(pausedDuration)
        }
    }

    private func clearPauseState() {
        pauseStartedAt = nil
        pausedRunState = nil
        pausedRestElapsedSeconds = nil
        pausedRestDurationSeconds = nil
    }

    /// Change the distance of an already-completed lap.
    func changeLapDistance(id: UUID, newDistanceMeters: Double) {
        guard let index = completedLaps.firstIndex(where: { $0.id == id }) else { return }
        updateLap(id: id, newType: completedLaps[index].lapType, newDistanceMeters: newDistanceMeters)
    }

    /// Change the type and distance of an already-completed lap.
    func updateLap(id: UUID, newType: LapType, newDistanceMeters: Double) {
        guard let index = completedLaps.firstIndex(where: { $0.id == id }) else { return }

        completedLaps[index].lapType = newType
        completedLaps[index].distanceMeters = newType == .rest ? 0 : max(0, newDistanceMeters)
        if newType == .rest {
            completedLaps[index].gpsDistanceMeters = nil
        } else if trackingMode == .gps {
            completedLaps[index].gpsDistanceMeters = max(0, newDistanceMeters)
        }

        let duration = completedLaps[index].durationSeconds
        let distance = completedLaps[index].distanceMeters
        completedLaps[index].averageSpeedMetersPerSecond = duration > 0 && distance > 0 ? distance / duration : 0

        recalculateCompletedLapDerivedState()
    }

    private func recalculateCompletedLapDerivedState() {
        var activeIndex = 1
        cumulativeDistanceMeters = 0
        cumulativeGPSDistanceMeters = 0

        for index in completedLaps.indices {
            if completedLaps[index].lapType == .rest {
                completedLaps[index].index = 0
                completedLaps[index].distanceMeters = 0
                completedLaps[index].gpsDistanceMeters = nil
                completedLaps[index].averageSpeedMetersPerSecond = 0
                continue
            }

            completedLaps[index].index = activeIndex
            activeIndex += 1
            cumulativeDistanceMeters += completedLaps[index].distanceMeters
            cumulativeGPSDistanceMeters += completedLaps[index].gpsDistanceMeters ?? 0
        }

        recalculateSegmentProgress()
    }

    private func recalculateSegmentProgress() {
        guard usesManualIntervals else { return }

        var segmentIndex = 0
        var repeatsDone = 0
        let completedActiveIntervals = completedLaps.filter { $0.lapType == .active }.count

        for _ in 0..<completedActiveIntervals {
            guard segmentIndex < distanceSegments.count else { break }

            repeatsDone += 1
            if let count = distanceSegments[segmentIndex].repeatCount,
               repeatsDone >= count,
               segmentIndex + 1 < distanceSegments.count {
                segmentIndex += 1
                repeatsDone = 0
            }
        }

        currentSegmentIndex = min(segmentIndex, max(distanceSegments.count - 1, 0))
        currentSegmentRepeatsDone = repeatsDone
        distanceLapDistanceMeters = currentTargetDistanceMeters
    }

    // MARK: - HealthKit Workout Session

    private func startHealthKitWorkout() async {
        guard let hkManager = healthKitManager else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = usesGPSDistance ? .outdoor : .indoor

        do {
            let session = try HKWorkoutSession(healthStore: hkManager.healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: hkManager.healthStore, workoutConfiguration: configuration)

            self.hkWorkoutSession = session
            self.hkLiveBuilder = builder

            session.delegate = self
            builder.delegate = self

            session.startActivity(with: Date())
            try await builder.beginCollection(at: Date())
        } catch {
            // Failed to start HK workout
        }
    }

    private func stopHealthKitWorkout(endDate: Date) async {
        guard let session = hkWorkoutSession, let builder = hkLiveBuilder else { return }
        session.end()
        do {
            try await builder.endCollection(at: endDate)
            builder.discardWorkout()
        } catch {
            // Failed to stop HK live session
        }
        hkWorkoutSession = nil
        hkLiveBuilder = nil
    }

    private func pauseHealthKitWorkout() {
        hkWorkoutSession?.pause()
    }

    private func resumeHealthKitWorkout() {
        hkWorkoutSession?.resume()
    }

    // MARK: - Location

    private func startLocationUpdates() {
        lastLocation = nil
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.activityType = .fitness
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
        isGPSActive = true
    }

    private func stopLocationUpdates() {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
        lastLocation = nil
        isGPSActive = false
    }

    // MARK: - Helpers

    private func deviceString() -> String {
        return "Apple Watch – LapLog v1.0"
    }

    private func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    /// Called externally when distance/HR updates arrive
    func handleDistanceUpdate(additionalMeters: Double) {
        guard runState != .paused else { return }

        if trackingMode == .gps {
            handleGPSDistanceUpdate(additionalMeters: additionalMeters)
            return
        }

        cumulativeDistanceMeters += additionalMeters
        currentLapDistanceMeters += additionalMeters

        // Auto-split in distance mode
        if usesManualIntervals && runState == .active {
            while currentLapDistanceMeters >= currentTargetDistanceMeters {
                let overflow = currentLapDistanceMeters - currentTargetDistanceMeters
                currentLapDistanceMeters = currentTargetDistanceMeters
                commitCurrentLap(source: .autoDistance)
                currentLapDistanceMeters = overflow
            }
        }

        persistRecoverySnapshotIfNeeded()
    }

    func handleGPSDistanceUpdate(additionalMeters: Double) {
        guard runState != .paused else { return }

        cumulativeGPSDistanceMeters += additionalMeters
        currentLapGPSDistanceMeters += additionalMeters

        if trackingMode == .gps {
            cumulativeDistanceMeters += additionalMeters
            currentLapDistanceMeters += additionalMeters
        }

        persistRecoverySnapshotIfNeeded()
    }

    func handleHeartRateUpdate(bpm: Double) {
        guard runState != .paused else { return }

        currentHeartRate = bpm
        currentLapHeartRateSamples.append(bpm)
    }

    private var resumableRunState: WorkoutRunState? {
        switch runState {
        case .active, .rest:
            return runState
        case .paused:
            return pausedRunState ?? .active
        default:
            return nil
        }
    }

    private func persistRecoverySnapshot() {
        guard let ongoingWorkoutStore,
                            let sessionID = currentSessionID,
              let sessionStartDate,
              let currentLapStartDate,
              let resumeRunState = resumableRunState else {
            return
        }

        let snapshot = OngoingWorkoutSnapshot(
                        sessionID: sessionID,
            savedAt: Date(),
            sessionStartDate: sessionStartDate,
            currentLapStartDate: currentLapStartDate,
            elapsedSeconds: elapsedSeconds,
            lapElapsedSeconds: lapElapsedSeconds,
            trackingMode: trackingMode,
            distanceLapDistanceMeters: distanceLapDistanceMeters,
            distanceSegments: distanceSegments,
            restMode: restMode,
            completedLaps: completedLaps.map(OngoingWorkoutLapSnapshot.init(lap:)),
            cumulativeDistanceMeters: cumulativeDistanceMeters,
            currentLapDistanceMeters: currentLapDistanceMeters,
            cumulativeGPSDistanceMeters: cumulativeGPSDistanceMeters,
            currentLapGPSDistanceMeters: currentLapGPSDistanceMeters,
            currentHeartRate: currentHeartRate,
            currentSegmentIndex: currentSegmentIndex,
            currentSegmentRepeatsDone: currentSegmentRepeatsDone,
            resumeRunState: resumeRunState,
            restElapsedSeconds: resumeRunState == .rest ? (runState == .paused ? pausedRestElapsedSeconds : restElapsedSeconds) : nil,
            restDurationSeconds: resumeRunState == .rest ? (runState == .paused ? pausedRestDurationSeconds : restDurationSeconds) : nil,
            pauseStartedAt: runState == .paused ? pauseStartedAt : nil
        )

        ongoingWorkoutStore.save(snapshot)
        publishLiveWorkoutStateIfNeeded()
    }

    private func clearRecoverySnapshot() {
        lastPersistedElapsedSecond = -1
        ongoingWorkoutStore?.clear()
    }

    private func publishLiveWorkoutStateIfNeeded() {
        guard let liveWorkoutState = makeLiveWorkoutState() else { return }
        syncManager?.publishLiveWorkoutState(liveWorkoutState)
    }

    private var liveManualDistanceMeters: Double {
        guard usesManualIntervals else { return cumulativeDistanceMeters }

        return completedLaps.reduce(0) { partialResult, lap in
            guard lap.lapType == .active else { return partialResult }
            return partialResult + lap.distanceMeters
        }
    }

    private func makeLiveWorkoutState() -> LiveWorkoutStateRecord? {
        guard let sessionID = currentSessionID,
              let sessionStartDate else {
            return nil
        }

        return LiveWorkoutStateRecord(
            sessionID: sessionID,
            startedAt: sessionStartDate,
            updatedAt: Date(),
            runState: runState,
            trackingMode: trackingMode,
            elapsedSeconds: elapsedSeconds,
            lapElapsedSeconds: lapElapsedSeconds,
            completedLapCount: completedLaps.count,
            cumulativeDistanceMeters: liveManualDistanceMeters,
            cumulativeGPSDistanceMeters: usesGPSDistance ? cumulativeGPSDistanceMeters : nil,
            currentHeartRate: currentHeartRate,
            currentTargetDistanceMeters: usesManualIntervals ? currentTargetDistanceMeters : nil,
            restElapsedSeconds: restElapsedSeconds,
            restDurationSeconds: restDurationSeconds,
            isGPSActive: isGPSActive
        )
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionController: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // State changes handled internally
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didGenerate event: HKWorkoutEvent
    ) {
        let eventType = event.type
        Task { @MainActor in
            guard self.restMode == .autoDetect else { return }
            switch eventType {
            case .motionPaused:
                self.handleAutoRestMotionPause()
            case .motionResumed:
                self.handleAutoRestMotionResume()
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        // Workout session error
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionController: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }

                let statistics = workoutBuilder.statistics(for: quantityType)

                if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    if let value = statistics?.mostRecentQuantity()?.doubleValue(for: unit) {
                        self.handleHeartRateUpdate(bpm: value)
                    }
                }

                if quantityType == HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                    guard self.trackingMode != .gps else { continue }
                    if let newCumulative = statistics?.sumQuantity()?.doubleValue(for: .meter()) {
                        let delta = newCumulative - self.lastHealthKitCumulativeDistanceMeters
                        self.lastHealthKitCumulativeDistanceMeters = newCumulative
                        if delta > 0 {
                            self.handleDistanceUpdate(additionalMeters: delta)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WorkoutSessionController: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                if let last = self.lastLocation {
                    let delta = location.distance(from: last)
                    if delta > 0 && delta < 100 {
                        self.handleGPSDistanceUpdate(additionalMeters: delta)
                    }
                }
                self.lastLocation = location
            }
        }
    }
}
