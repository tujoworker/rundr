import Foundation
import HealthKit
import CoreLocation

final class HealthKitManager: ObservableObject {

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationError: String?

    init() {
        refreshAuthorizationState()
    }

    var supportsLiveWorkoutSessions: Bool {
        !Self.isRunningTests && HKHealthStore.isHealthDataAvailable()
    }

    // Types we read
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    // Types we write
    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        types.insert(HKObjectType.workoutType())
        types.insert(HKSeriesType.workoutRoute())
        return types
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            await MainActor.run {
                self.authorizationError = L10n.healthDataNotAvailable
                self.isAuthorized = false
            }
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            let isAuthorized = await Self.waitForWorkoutAuthorization {
                self.healthStore.authorizationStatus(for: HKObjectType.workoutType())
            }
            await MainActor.run {
                self.isAuthorized = isAuthorized
                self.authorizationError = isAuthorized ? nil : L10n.healthAccessDenied
            }
        } catch {
            await MainActor.run {
                self.isAuthorized = false
                self.authorizationError = Self.presentableAuthorizationError(from: error.localizedDescription)
            }
        }
    }

    static func presentableAuthorizationError(from message: String) -> String {
        let normalizedMessage = message.lowercased()
        if normalizedMessage.contains("com.apple.developer.healthkit") ||
            normalizedMessage.contains("healthkit entitlement") {
            return L10n.healthAccessMissingEntitlement
        }
        return message
    }

    func refreshAuthorizationState() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }

        let workoutAuthorization = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        isAuthorized = workoutAuthorization == .sharingAuthorized
    }

    static func waitForWorkoutAuthorization(
        maxAttempts: Int = 5,
        retryDelay: Duration = .milliseconds(150),
        authorizationStatusProvider: @escaping () -> HKAuthorizationStatus
    ) async -> Bool {
        guard maxAttempts > 0 else { return false }

        for attempt in 0..<maxAttempts {
            if authorizationStatusProvider() == .sharingAuthorized {
                return true
            }

            if attempt < maxAttempts - 1 {
                try? await Task.sleep(for: retryDelay)
            }
        }

        return false
    }

    /// Fetches the most recent body mass (weight) in kg for calorie estimation.
    func fetchMostRecentWeightKg() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable(),
              let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }

        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: nil,
                limit: 1,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                guard error == nil,
                      let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            self.healthStore.execute(query)
        }
    }

    func fetchMostRecentHeartRate() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-15 * 60), end: nil)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                guard error == nil,
                      let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }

            self.healthStore.execute(query)
        }
    }

    /// Save a completed session to HealthKit as an HKWorkout with interval activities.
    func saveWorkout(session: Session, routeLocations: [CLLocation] = []) async throws -> UUID? {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = session.mode.usesGPSDistance ? .outdoor : .indoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        try await builder.beginCollection(at: session.startedAt)

        let weightKg = await fetchMostRecentWeightKg() ?? 70

        // Add distance, heart rate, and energy samples per lap
        var samples: [HKQuantitySample] = []
        for lap in session.laps.sorted(by: { $0.startedAt < $1.startedAt }) {
            if lap.distanceMeters > 0,
               let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                let quantity = HKQuantity(unit: .meter(), doubleValue: lap.distanceMeters)
                let sample = HKQuantitySample(
                    type: distanceType,
                    quantity: quantity,
                    start: lap.startedAt,
                    end: lap.endedAt
                )
                samples.append(sample)
            }

            if let bpm = lap.averageHeartRateBPM,
               let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let unit = HKUnit.count().unitDivided(by: .minute())
                let quantity = HKQuantity(unit: unit, doubleValue: bpm)
                let sample = HKQuantitySample(
                    type: hrType,
                    quantity: quantity,
                    start: lap.startedAt,
                    end: lap.endedAt
                )
                samples.append(sample)
            }

                if lap.lapType == .active,
               let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let hours = lap.durationSeconds / 3600
                let kcal = 8 * weightKg * hours
                if kcal > 0 {
                    let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
                    let sample = HKQuantitySample(
                        type: energyType,
                        quantity: quantity,
                        start: lap.startedAt,
                        end: lap.endedAt
                    )
                    samples.append(sample)
                }
            }
        }

        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }

        // Add segment events for active laps
        for lap in session.laps.sorted(by: { $0.startedAt < $1.startedAt }) {
            if lap.lapType == .active {
                let segmentEvent = HKWorkoutEvent(
                    type: .segment,
                    dateInterval: DateInterval(start: lap.startedAt, end: lap.endedAt),
                    metadata: [
                        "lapIndex": lap.index,
                        "lapType": lap.lapTypeRaw
                    ]
                )
                try await builder.addWorkoutEvents([segmentEvent])
            }
        }

        // Add interval workout activities for each lap so Fitness shows them
        for lap in session.laps.sorted(by: { $0.startedAt < $1.startedAt }) {
            let intervalConfig = HKWorkoutConfiguration()
            intervalConfig.activityType = .running
            intervalConfig.locationType = session.mode.usesGPSDistance ? .outdoor : .indoor

            var meta: [String: Any] = [
                "lapIndex": lap.index,
                "lapType": lap.lapTypeRaw
            ]
            if let bpm = lap.averageHeartRateBPM {
                meta["averageHeartRate"] = bpm
            }
            if lap.distanceMeters > 0 {
                meta["distanceMeters"] = lap.distanceMeters
            }
            if let gpsDistanceMeters = lap.gpsDistanceMeters, gpsDistanceMeters > 0 {
                meta["gpsDistanceMeters"] = gpsDistanceMeters
            }
            let activity = HKWorkoutActivity(
                workoutConfiguration: intervalConfig,
                start: lap.startedAt,
                end: lap.endedAt,
                metadata: meta
            )
            try await builder.addWorkoutActivity(activity)
        }

        try await builder.endCollection(at: session.endedAt)
        let workout = try await builder.finishWorkout()

        // Attach GPS route so Activity app can display a map when sharing
        if let workout, !routeLocations.isEmpty {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            try await routeBuilder.insertRouteData(routeLocations)
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }

        return workout?.uuid
    }
}
