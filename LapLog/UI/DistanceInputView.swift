import SwiftUI

struct DistanceInputView: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var onValueChange: (() -> Void)?

    private var distanceValue: Double {
        Double(text) ?? 0
    }

    private var stepSize: Double {
        distanceValue >= 1000 ? 100 : 50
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(label)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

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

                        TextField(placeholder, text: $text)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
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
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .onDisappear {
            onValueChange?()
        }
    }

    private func formatDistanceValue(_ value: Double) -> String {
        value == floor(value) ? String(format: "%.0f", value) : String(format: "%g", value)
    }
}
