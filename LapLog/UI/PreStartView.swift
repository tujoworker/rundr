import SwiftUI

struct PreStartView: View {
    @EnvironmentObject var settings: SettingsStore
    var onStart: () -> Void

    @State private var distanceText: String = ""

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
                        Text("Lap Distance (meters)")
                            .font(.caption.bold())
                        TextField("e.g. 400", text: $distanceText)
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
            distanceText = String(format: "%.0f", settings.distanceDistanceMeters)
        }
    }

    private func persistDistance() {
        if let value = Double(distanceText), value > 0 {
            settings.distanceDistanceMeters = value
        }
    }
}
