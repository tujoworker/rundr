import SwiftUI

struct OngoingWorkoutRecoveryView: View {
    let snapshot: OngoingWorkoutSnapshot
    let accentColor: Color
    let onContinue: () -> Void
    let onDiscard: () -> Void
    @Environment(\.appTheme) private var theme

    private var startedText: String {
        Formatters.historySessionDateTimeString(from: snapshot.sessionStartDate)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    Spacer(minLength: 38)

                    VStack(spacing: 16) {
                        Text(L10n.recoverWorkoutTitle)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(startedText)
                            .font(.system(size: Tokens.FontSize.md, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textBody)
                            .multilineTextAlignment(.center)

                        Button(action: onContinue) {
                            Text(L10n.resumeWorkout)
                                .font(.system(size: Tokens.FontSize.lg, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, Tokens.Spacing.md)
                                .padding(.vertical, Tokens.Spacing.lg)
                        }
                        .accentRoundedButtonChrome(accentColor: accentColor, cornerRadius: Tokens.Radius.xxxl)
                        .buttonStyle(.plain)

                        Button(role: .destructive, action: onDiscard) {
                            Text(L10n.discardWorkout)
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.isDark ? theme.textBody : .red)
                        .background {
                            if !theme.isDark {
                                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                                    .fill(theme.tintedButtonBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                                            .stroke(theme.tintedButtonStroke(.red), lineWidth: Tokens.LineWidth.regular)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .tint(accentColor)

                    Spacer(minLength: Tokens.Spacing.xl)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}