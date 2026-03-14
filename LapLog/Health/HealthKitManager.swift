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
        if let routeType = HKSeriesType.workoutRoute() as? HKSampleType {
            types.insert(routeType)
        }
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

    /// Save a completed session to HealthKit as an HKWorkout with interval activities.
    func saveWorkout(session: Session) async throws -> UUID? {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = session.mode == .gps ? .outdoor : .indoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        try await builder.beginCollection(at: session.startedAt)

        // Add distance and heart rate samples per lap
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
        }

        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }

        // Add workout events (pause/resume for rest, segment for active laps)
        for lap in session.laps.sorted(by: { $0.startedAt < $1.startedAt }) {
            if lap.lapType == .rest {
                let pauseEvent = HKWorkoutEvent(
                    type: .pause,
                    dateInterval: DateInterval(start: lap.startedAt, duration: 0),
                    metadata: nil
                )
                let resumeEvent = HKWorkoutEvent(
                    type: .resume,
                    dateInterval: DateInterval(start: lap.endedAt, duration: 0),
                    metadata: nil
                )
                try await builder.addWorkoutEvents([pauseEvent, resumeEvent])
            } else {
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
            intervalConfig.activityType = lap.lapType == .rest ? .running : .running
            intervalConfig.locationType = session.mode == .gps ? .outdoor : .indoor

            let activity = HKWorkoutActivity(
                workoutConfiguration: intervalConfig,
                start: lap.startedAt,
                end: lap.endedAt,
                metadata: [
                    "lapIndex": lap.index,
                    "lapType": lap.lapTypeRaw
                ]
            )
            try await builder.addWorkoutActivity(activity)
        }

        try await builder.endCollection(at: session.endedAt)
        let workout = try await builder.finishWorkout()
        return workout?.uuid
    }
}
