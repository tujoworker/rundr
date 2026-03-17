import SwiftUI

struct DistanceInputView: View {
    let label: String
    @Binding var text: String
    var onValueChange: (() -> Void)?

    private let defaultDistanceText = "400"

    private var distanceValue: Double {
        Double(text) ?? 0
    }

    private var stepSize: Double {
        distanceValue >= 1000 ? 100 : 50
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 4)
                .padding(.top, 8)

            HStack(spacing: 8) {
                Button {
                    let current = max(distanceValue, stepSize)
                    text = formatDistanceValue(max(stepSize, current - stepSize))
                    onValueChange?()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.12))

                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)

                Button {
                    text = formatDistanceValue(distanceValue + stepSize)
                    onValueChange?()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .onDisappear {
            if text.isEmpty {
                text = defaultDistanceText
            }
            onValueChange?()
        }
    }

    private func formatDistanceValue(_ value: Double) -> String {
        value == floor(value) ? String(format: "%.0f", value) : String(format: "%g", value)
    }
}
