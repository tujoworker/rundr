import SwiftUI

struct SessionDetailView: View {
    let session: Session
    let onUseSessionSettings: () -> Void
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var persistence: PersistenceManager
    @Environment(\.dismiss) private var dismiss

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.startedAt < $1.startedAt }
    }

    private var headerTitle: String {
        session.startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.session)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                Text(headerTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)

                ForEach(sortedLaps, id: \.id) { lap in
                    LapRowView(lap: lap, distanceUnit: settings.distanceUnit)
                }

                Button(action: onUseSessionSettings) {
                    Text(L10n.useSessionSettings)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
                .padding(.horizontal, 4)

                Button(String(localized: "Delete Session", comment: "Button to delete a saved session"), role: .destructive) {
                    persistence.deleteSession(session)
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 4)
        }
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
