import SwiftUI

struct PreStartView: View {
    @EnvironmentObject var settings: SettingsStore
    var onStart: () -> Void

    @State private var distanceText: String = ""

    private var distanceLabel: String {
        switch settings.distanceUnit {
        case .km: return "Lap Distance (meters)"
        case .miles: return "Lap Distance (feet)"
        }
    }

    private var distancePlaceholder: String {
        switch settings.distanceUnit {
        case .km: return "e.g. 400"
        case .miles: return "e.g. 1320"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Button(action: {
                    persistDistance()
                    onStart()
                }) {
                    Text("Start")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(settings.trackingMode == .distanceDistance && (Double(distanceText) ?? 0) <= 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tracking Mode")
                        .font(.caption.bold())

                    Picker("Mode", selection: $settings.trackingMode) {
                        ForEach(TrackingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    if settings.trackingMode == .distanceDistance {
                        Text(distanceLabel)
                            .font(.caption.bold())
                        TextField(distancePlaceholder, text: $distanceText)
                            .multilineTextAlignment(.leading)
                    }

                    Text("Distance Unit")
                        .font(.caption.bold())
                    Picker("Unit", selection: $settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Setup")
        .onAppear {
            distanceText = displayDistance()
        }
        .onChange(of: settings.distanceUnit) {
            distanceText = displayDistance()
        }
    }

    private func displayDistance() -> String {
        let meters = settings.distanceDistanceMeters
        switch settings.distanceUnit {
        case .km:
            return String(format: "%.0f", meters)
        case .miles:
            return String(format: "%.0f", meters * 3.28084)
        }
    }

    private func persistDistance() {
        guard let value = Double(distanceText), value > 0 else { return }
        switch settings.distanceUnit {
        case .km:
            settings.distanceDistanceMeters = value
        case .miles:
            settings.distanceDistanceMeters = value / 3.28084
        }
    }
}
