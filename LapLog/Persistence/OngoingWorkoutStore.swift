import Foundation
import SwiftUI

@MainActor
final class OngoingWorkoutStore: ObservableObject {
    @AppStorage("ongoingWorkoutSnapshotJSON") private var ongoingWorkoutSnapshotJSON: String = ""

    @Published private(set) var snapshot: OngoingWorkoutSnapshot?
    @Published private(set) var startupSnapshot: OngoingWorkoutSnapshot?

    init() {
        loadSnapshot()
        startupSnapshot = snapshot
    }

    func save(_ snapshot: OngoingWorkoutSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        ongoingWorkoutSnapshotJSON = json
        self.snapshot = snapshot
    }

    func clear() {
        ongoingWorkoutSnapshotJSON = ""
        snapshot = nil
        startupSnapshot = nil
    }

    func consumeStartupSnapshot() {
        startupSnapshot = nil
    }

    func loadSnapshot() {
        guard !ongoingWorkoutSnapshotJSON.isEmpty,
              let data = ongoingWorkoutSnapshotJSON.data(using: .utf8),
              let decodedSnapshot = try? JSONDecoder().decode(OngoingWorkoutSnapshot.self, from: data) else {
            if !ongoingWorkoutSnapshotJSON.isEmpty {
                ongoingWorkoutSnapshotJSON = ""
            }
            snapshot = nil
            return
        }

        self.snapshot = decodedSnapshot
    }
}