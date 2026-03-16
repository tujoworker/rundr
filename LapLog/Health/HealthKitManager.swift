import Foundation
import HealthKit

final class HealthKitManager: ObservableObject {

    let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationError: String?

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
                self.authorizationError = "Health data not available on this device."
            }
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            await MainActor.run {
                self.isAuthorized = true
            }
        } catch {
            await MainActor.run {
                self.authorizationError = error.localizedDescription
            }
        }
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
    func saveWorkout(session: Session) async throws -> UUID? {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = session.mode == .gps ? .outdoor : .indoor

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

            if lap.lapType != .rest,
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
            if lap.lapType != .rest {
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
            intervalConfig.locationType = session.mode == .gps ? .outdoor : .indoor

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
        return workout?.uuid
    }
}
