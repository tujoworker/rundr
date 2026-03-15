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
    @Published var completedLaps: [Lap] = []
    @Published var isGPSActive: Bool = false

    // MARK: - Settings Snapshot

    private(set) var trackingMode: TrackingMode = .gps
    private(set) var distanceLapDistanceMeters: Double = 400

    // MARK: - Internal

    private var sessionStartDate: Date?
    private var currentLapStartDate: Date?
    private var currentLapDistanceMeters: Double = 0
    private var currentLapHeartRateSamples: [Double] = []

    private var timerCancellable: AnyCancellable?
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
        healthKitManager: HealthKitManager
    ) {
        self.trackingMode = trackingMode
        self.distanceLapDistanceMeters = distanceLapDistanceMeters
        self.healthKitManager = healthKitManager
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

    func markLap(source: LapSource = .distanceTap) {
        guard runState == .active || runState == .rest || runState == .ending else { return }
        if runState != .ending {
            commitCurrentLap(source: source)
        } else {
            currentLapStartDate = Date()
            currentLapDistanceMeters = 0
            currentLapHeartRateSamples = []
            lapElapsedSeconds = 0
        }
        runState = .active
        startTimer()
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
        runState = .rest
        playHaptic(.notification)
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
        let avgSpeed = duration > 0 ? totalDist / duration : 0

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

    private func commitCurrentLap(source: LapSource) {
        guard let lapStart = currentLapStartDate else { return }
        let lapEnd = Date()
        let duration = lapEnd.timeIntervalSince(lapStart)
        guard duration > 0.1 else { return }

        let isRest = (runState == .rest || runState == .ending)
        var distance: Double
        if isRest {
            distance = 0
        } else if trackingMode == .distanceDistance {
            distance = distanceLapDistanceMeters
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

        // Reset for next lap
        currentLapStartDate = lapEnd
        currentLapDistanceMeters = 0
        currentLapHeartRateSamples = []
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
            print("Failed to start HK workout: \(error)")
        }
    }

    private func stopHealthKitWorkout(endDate: Date) async {
        guard let session = hkWorkoutSession, let builder = hkLiveBuilder else { return }
        session.end()
        do {
            try await builder.endCollection(at: endDate)
            builder.discardWorkout()
        } catch {
            print("Failed to stop HK live session: \(error)")
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
            while currentLapDistanceMeters >= distanceLapDistanceMeters {
                let overflow = currentLapDistanceMeters - distanceLapDistanceMeters
                currentLapDistanceMeters = distanceLapDistanceMeters
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
        didFailWithError error: Error
    ) {
        print("Workout session error: \(error)")
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
