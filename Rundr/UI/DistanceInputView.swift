import SwiftUI

struct DistanceInputView: View {
    let label: String
    let accentColor: Color
    @Binding var text: String
    var onValueChange: (() -> Void)?
    @Environment(\.appTheme) private var theme

    private let defaultDistanceText = "400"
    private let controlHeight: CGFloat = 46
    private let keypadRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    @State private var isEditorPresented = false
    @State private var editorText = ""

    private var distanceValue: Double {
        Double(text) ?? 0
    }

    private var stepSize: Double {
        distanceValue >= 1000 ? 100 : 50
    }

    private var displayText: String {
        text.isEmpty ? defaultDistanceText : text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Tokens.Spacing.xs)
                .padding(.top, Tokens.Spacing.md)

            HStack(spacing: Tokens.Spacing.md) {
                Button {
                    let current = max(distanceValue, stepSize)
                    text = formatDistanceValue(max(stepSize, current - stepSize))
                    onValueChange?()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(theme.surfaceCard))
                        .foregroundStyle(theme.textPrimary)
                }
                .buttonStyle(.plain)

                Button {
                    editorText = displayText
                    isEditorPresented = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                            .fill(theme.surfaceInput)

                        Text(displayText)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundStyle(theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: controlHeight)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)

                Button {
                    text = formatDistanceValue(distanceValue + stepSize)
                    onValueChange?()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(theme.surfaceCard))
                        .foregroundStyle(theme.textPrimary)
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
        .sheet(isPresented: Binding(
            get: { isEditorPresented },
            set: { presented in
                if !presented {
                    commitEditorText()
                } else {
                    isEditorPresented = true
                }
            }
        )) {
            NumericKeypadEditorScreen(
                title: label,
                accentColor: accentColor,
                keypadRows: keypadRows,
                text: $editorText,
                onTapKey: tapKey,
                onDone: {
                    commitEditorText()
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func commitEditorText() {
        let normalizedText = normalizedInput(editorText)
        text = normalizedText.isEmpty ? defaultDistanceText : normalizedText
        isEditorPresented = false
        onValueChange?()
    }

    private func normalizedInput(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return "" }

        let normalizedDecimal = trimmedValue.hasSuffix(".") ? String(trimmedValue.dropLast()) : trimmedValue
        guard let numericValue = Double(normalizedDecimal) else {
            return displayText
        }

        return formatDistanceValue(numericValue)
    }

    private func formatDistanceValue(_ value: Double) -> String {
        value == floor(value) ? String(format: "%.0f", value) : String(format: "%g", value)
    }
}

struct NumericKeypadEditorScreen: View {
    let title: String
    let accentColor: Color
    let keypadRows: [[String]]
    @Binding var text: String
    let onTapKey: (String, inout String) -> Void
    let onDone: () -> Void

    private let headerContentHeight: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top

            ZStack(alignment: .top) {
                AppScreenBackground(accentColor: accentColor)

                VStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        Rectangle()
                            .fill(.ultraThinMaterial)

                        Color.black.opacity(0.18)

                        accentColor.opacity(0.12)

                        Text(text.isEmpty ? " " : text)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .padding(.horizontal, Tokens.Spacing.xl)
                            .padding(.bottom, Tokens.Spacing.sm)
                            .offset(y: -8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: topInset + headerContentHeight)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(accentColor.opacity(0.6))
                            .frame(height: 2)
                    }

                    ScrollView {
                        VStack(spacing: Tokens.Spacing.lg) {
                            Text(title)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(spacing: Tokens.Spacing.sm) {
                                ForEach(0..<keypadRows.count, id: \.self) { rowIndex in
                                    HStack(spacing: 6) {
                                        ForEach(keypadRows[rowIndex], id: \.self) { key in
                                            NumericKeypadButton(key: key) {
                                                var nextText = text
                                                onTapKey(key, &nextText)
                                                text = nextText
                                            }
                                        }
                                    }
                                }
                            }

                            Button(L10n.done) {
                                onDone()
                            }
                            .padding(.top, Tokens.Spacing.xs)
                        }
                        .padding(.horizontal, Tokens.Spacing.xl)
                        .padding(.vertical, Tokens.Spacing.xl)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

}

func distanceFieldTapKey(_ key: String, text: inout String) {
    if key == "⌫" {
        if !text.isEmpty {
            text.removeLast()
        }
        return
    }

    if key == "." {
        if text.isEmpty {
            text = "0."
        } else if !text.contains(".") {
            text += key
        }
        return
    }

    if text == "0" {
        text = key
    } else {
        text += key
    }
}

private extension DistanceInputView {
    func tapKey(_ key: String, text: inout String) {
        distanceFieldTapKey(key, text: &text)
    }
}

private struct NumericKeypadButton: View {
    let key: String
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                        .fill(theme.surfaceCard)
                )
        }
        .buttonStyle(.plain)
    }
}

private extension DistanceInputView {
    func tapKey(_ key: String) {
        var nextText = text
        tapKey(key, text: &nextText)
        text = nextText
    }
}
