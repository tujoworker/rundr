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
    private(set) var pauseMode: PauseMode = .manual

    // MARK: - Distance Segments

    /// Ordered list of distance segments for the workout plan.
    private(set) var distanceSegments: [DistanceSegment] = [.default]
    /// Index into `distanceSegments` for the current segment.
    private(set) var currentSegmentIndex: Int = 0
    /// How many laps have been completed in the current segment.
    private(set) var currentSegmentRepeatsDone: Int = 0

    /// The target distance for the next/current lap based on the segment plan.
    var currentTargetDistanceMeters: Double {
        guard trackingMode == .distanceDistance else { return 0 }
        let segment = currentSegment
        return segment.distanceMeters
    }

    /// All unique distances defined in the segments, for quick-pick UI.
    var availableDistances: [Double] {
        Array(Set(distanceSegments.map(\.distanceMeters))).sorted()
    }

    /// Total number of planned active intervals when all segments have explicit repeat counts.
    var totalPlannedIntervals: Int? {
        guard trackingMode == .distanceDistance else { return nil }
        let counts = distanceSegments.compactMap(\.repeatCount)
        guard counts.count == distanceSegments.count else { return nil }
        return counts.reduce(0, +)
    }

    private var currentSegment: DistanceSegment {
        guard currentSegmentIndex < distanceSegments.count else {
            return distanceSegments.last ?? .default
        }
        return distanceSegments[currentSegmentIndex]
    }

    // MARK: - Internal

    private var sessionStartDate: Date?
    private var currentLapStartDate: Date?
    private var currentLapHeartRateSamples: [Double] = []

    private var timerCancellable: AnyCancellable?
    private var restTimerCancellable: AnyCancellable?
    private var healthKitManager: HealthKitManager?

    // HealthKit workout session
    private var hkWorkoutSession: HKWorkoutSession?
    private var hkLiveBuilder: HKLiveWorkoutBuilder?

    // Location
    private var locationManager: CLLocationManager?
    private var lastLocation: CLLocation?

    // MARK: - Configuration

    func configure(
        trackingMode: TrackingMode,
        distanceLapDistanceMeters: Double,
        distanceSegments: [DistanceSegment] = [.default],
        pauseMode: PauseMode = .manual,
        healthKitManager: HealthKitManager
    ) {
        self.trackingMode = trackingMode
        self.distanceLapDistanceMeters = distanceLapDistanceMeters
        self.distanceSegments = distanceSegments.isEmpty ? [.default] : distanceSegments
        self.pauseMode = pauseMode
        self.healthKitManager = healthKitManager
        self.currentSegmentIndex = 0
        self.currentSegmentRepeatsDone = 0
    }

    // MARK: - Lifecycle

    func getReady() {
        runState = .ready
        playHaptic(.notification)
    }

    func start() async {
        sessionStartDate = Date()
        currentLapStartDate = Date()
        currentLapDistanceMeters = 0
        currentLapHeartRateSamples = []
        completedLaps = []
        cumulativeDistanceMeters = 0
        elapsedSeconds = 0
        lapElapsedSeconds = 0
        currentHeartRate = nil
        runState = .active

        startTimer()
        await startHealthKitWorkout()
        if trackingMode == .gps {
            startLocationUpdates()
        }

        playHaptic(.notification)
    }

    /// Lightweight start for unit tests — skips HealthKit and location.
    func startWithoutHealthKit() {
        let start = Date(timeIntervalSinceNow: -1)
        sessionStartDate = start
        currentLapStartDate = start
        currentLapDistanceMeters = 0
        currentLapHeartRateSamples = []
        completedLaps = []
        cumulativeDistanceMeters = 0
        elapsedSeconds = 0
        lapElapsedSeconds = 0
        currentHeartRate = nil
        runState = .active
    }

    func deleteLap(id: UUID) {
        guard runState == .active || runState == .rest || runState == .ending else { return }
        guard let index = completedLaps.firstIndex(where: { $0.id == id }) else { return }
        let lap = completedLaps[index]
        completedLaps.remove(at: index)
        cumulativeDistanceMeters = max(0, cumulativeDistanceMeters - lap.distanceMeters)
        var activeIndex = 1
        for i in completedLaps.indices {
            if completedLaps[i].lapType != .rest {
                completedLaps[i].index = activeIndex
                activeIndex += 1
            }
        }
        playHaptic(.click)
    }

    func markLap(source: LapSource = .distanceTap) {
        guard runState == .active || runState == .rest || runState == .ending else { return }
        let wasResting = (runState == .rest)
        // Capture rest config before commit (which may advance the segment)
        let restSecondsBeforeCommit = (!wasResting && trackingMode == .distanceDistance)
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
        } else {
            cancelRestTimer()
            runState = .active
            startTimer()
        }
        playHaptic(.notification)
    }

    func commitFinalLap() {
        guard runState == .active || runState == .rest else { return }
        commitCurrentLap(source: .sessionEndSplit)
        runState = .ending
        stopTimer()
        playHaptic(.notification)
    }

    func startRest() {
        guard runState == .active else { return }
        playHaptic(.notification)
        runState = .rest
    }

    func cancelRest() {
        guard runState == .rest else { return }
        cancelRestTimer()
        playHaptic(.click)
        runState = .active
        startTimer()
    }

    func endSession() async -> Session? {
        guard runState == .active || runState == .rest || runState == .ending else { return nil }

        // Commit any remaining open segment (skipped if already committed by commitFinalLap)
        if runState != .ending {
            commitCurrentLap(source: .sessionEndSplit)
        }

        runState = .ended
        stopTimer()
        stopLocationUpdates()

        let endDate = Date()
        Task { await stopHealthKitWorkout(endDate: endDate) }

        guard let startDate = sessionStartDate else { return nil }

        let duration = endDate.timeIntervalSince(startDate)
        let totalDist = completedLaps.reduce(0) { $0 + $1.distanceMeters }
        let activeDuration = completedLaps
            .filter { $0.lapType != .rest }
            .reduce(0.0) { $0 + $1.durationSeconds }
        let avgSpeed = activeDuration > 0 && totalDist > 0 ? totalDist / activeDuration : 0

        let session = Session(
            startedAt: startDate,
            endedAt: endDate,
            durationSeconds: duration,
            mode: trackingMode,
            distanceLapDistanceMeters: trackingMode == .distanceDistance ? distanceLapDistanceMeters : nil,
            totalDistanceMeters: totalDist,
            averageSpeedMetersPerSecond: avgSpeed,
            totalLaps: completedLaps.count,
            laps: completedLaps,
            deviceSource: deviceString(),
            snapshotTrackingMode: trackingMode,
            snapshotDistanceDistanceMeters: trackingMode == .distanceDistance ? distanceLapDistanceMeters : nil
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
        completedLaps = []
        isGPSActive = false
        sessionStartDate = nil
        currentLapStartDate = nil
        currentLapDistanceMeters = 0
        currentLapHeartRateSamples = []
        currentSegmentIndex = 0
        currentSegmentRepeatsDone = 0
        cancelRestTimer()
        stopTimer()
        stopLocationUpdates()
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
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
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
        if isRest {
            distance = 0
        } else if trackingMode == .distanceDistance {
            distance = currentTargetDistanceMeters
        } else {
            distance = currentLapDistanceMeters
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
            averageSpeedMetersPerSecond: avgSpeed,
            averageHeartRateBPM: avgHR,
            lapType: isRest ? .rest : .active,
            source: source
        )
        completedLaps.append(lap)

        // Advance segment if this was an active lap in distance mode
        if !isRest && trackingMode == .distanceDistance {
            advanceSegment()
        }

        // Reset for next lap
        currentLapStartDate = lapEnd
        currentLapDistanceMeters = 0
        currentLapHeartRateSamples = []
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

    private func startAutoRest(seconds: Int) {
        runState = .rest
        restElapsedSeconds = 0
        restDurationSeconds = seconds
        isRestWarningActive = false

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
            }
    }

    private func cancelRestTimer() {
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        restElapsedSeconds = nil
        restDurationSeconds = nil
        isRestWarningActive = false
    }

    /// Change the distance of an already-completed lap.
    func changeLapDistance(id: UUID, newDistanceMeters: Double) {
        guard let index = completedLaps.firstIndex(where: { $0.id == id }) else { return }
        let oldDistance = completedLaps[index].distanceMeters
        completedLaps[index].distanceMeters = newDistanceMeters

        let duration = completedLaps[index].durationSeconds
        completedLaps[index].averageSpeedMetersPerSecond = duration > 0 && newDistanceMeters > 0 ? newDistanceMeters / duration : 0

        cumulativeDistanceMeters = max(0, cumulativeDistanceMeters - oldDistance + newDistanceMeters)
    }

    // MARK: - HealthKit Workout Session

    private func startHealthKitWorkout() async {
        guard let hkManager = healthKitManager else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = trackingMode == .gps ? .outdoor : .indoor

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

    // MARK: - Location

    private func startLocationUpdates() {
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
        cumulativeDistanceMeters += additionalMeters
        currentLapDistanceMeters += additionalMeters

        // Auto-split in distance mode
        if trackingMode == .distanceDistance && runState == .active {
            while currentLapDistanceMeters >= currentTargetDistanceMeters {
                let overflow = currentLapDistanceMeters - currentTargetDistanceMeters
                currentLapDistanceMeters = currentTargetDistanceMeters
                commitCurrentLap(source: .autoDistance)
                currentLapDistanceMeters = overflow
            }
        }
    }

    func handleHeartRateUpdate(bpm: Double) {
        currentHeartRate = bpm
        currentLapHeartRateSamples.append(bpm)
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
            guard self.pauseMode == .autoDetect else { return }
            switch eventType {
            case .motionPaused:
                self.startRest()
            case .motionResumed:
                self.cancelRest()
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
                    if let newCumulative = statistics?.sumQuantity()?.doubleValue(for: .meter()) {
                        let delta = newCumulative - self.cumulativeDistanceMeters
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
                        self.handleDistanceUpdate(additionalMeters: delta)
                    }
                }
                self.lastLocation = location
            }
        }
    }
}
