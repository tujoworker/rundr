import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @EnvironmentObject var settings: SettingsStore

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(sortedLaps, id: \.id) { lap in
                    LapRowView(lap: lap, distanceUnit: settings.distanceUnit)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle(L10n.session)
        .background(Color.clear)
    }
}

struct LapRowView: View {
    let lap: Lap
    var distanceUnit: DistanceUnit = .km

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if lap.lapType == .rest {
                Text(L10n.rest)
                    .font(.caption.bold())
            } else {
                Text(L10n.lapIndex(lap.index))
                    .font(.caption.bold())
            }
            HStack {
                Text(Formatters.compactTimeString(from: lap.durationSeconds))
                    .font(.system(.caption2, design: .monospaced))
                if lap.lapType != .rest && lap.distanceMeters > 0 {
                    Text("•")
                        .font(.caption2)
                    Text(Formatters.paceString(distanceMeters: lap.distanceMeters, durationSeconds: lap.durationSeconds, unit: distanceUnit))
                        .font(.system(.caption2, design: .monospaced))
                }
                if let bpm = lap.averageHeartRateBPM {
                    Text("•")
                        .font(.caption2)
                    Text(Formatters.heartRateString(bpm: bpm))
                        .font(.system(.caption2, design: .monospaced))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(lap.lapType == .rest ? Color.white.opacity(0.9) : Color.white.opacity(0.15))
        .foregroundColor(lap.lapType == .rest ? .black : .white)
        .cornerRadius(6)
        .padding(.horizontal, 4)
    }
}
