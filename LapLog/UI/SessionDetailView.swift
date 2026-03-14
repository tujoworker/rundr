import SwiftUI

struct SessionDetailView: View {
    let session: Session

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.index < $1.index }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(sortedLaps, id: \.id) { lap in
                    LapRowView(lap: lap)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Session")
    }
}

struct LapRowView: View {
    let lap: Lap

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Lap \(lap.index) • \(lap.lapType.displayName)")
                .font(.caption.bold())
            Text("Time: \(Formatters.timeString(from: lap.durationSeconds)) • Dist: \(Formatters.distanceString(meters: lap.distanceMeters))")
                .font(.system(.caption2, design: .monospaced))
            Text("Avg: \(Formatters.speedString(metersPerSecond: lap.averageSpeedMetersPerSecond)) • HR: \(Formatters.heartRateString(bpm: lap.averageHeartRateBPM))")
                .font(.system(.caption2, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(lap.lapType == .rest ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
        .cornerRadius(6)
        .padding(.horizontal, 4)
    }
}
