import SwiftUI

struct DistanceInputView: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var onValueChange: (() -> Void)?

    private let keypadRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(label)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(text.isEmpty ? placeholder : text)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(text.isEmpty ? .white.opacity(0.5) : .white)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )

                VStack(spacing: 6) {
                    ForEach(0..<keypadRows.count, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            ForEach(keypadRows[rowIndex], id: \.self) { key in
                                KeypadButton(key: key) {
                                    tapKey(key)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .onDisappear {
            onValueChange?()
        }
    }

    private func tapKey(_ key: String) {
        if key == "⌫" {
            if !text.isEmpty {
                text.removeLast()
            }
        } else if key == "." {
            if !text.contains(".") {
                text += key
            }
        } else {
            text += key
        }
        onValueChange?()
    }
}

private struct KeypadButton: View {
    let key: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}
