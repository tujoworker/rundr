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
        VStack(spacing: 0) {
            Spacer(minLength: 38)

            VStack(spacing: 16) {
                Text(L10n.recoverWorkoutTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text.neutral)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(startedText)
                    .font(.system(size: Tokens.FontSize.md, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.text.subtle)
                    .multilineTextAlignment(.center)

                Button(action: onContinue) {
                    Text(L10n.resumeWorkout)
                        .font(.system(size: Tokens.FontSize.lg, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Spacing.lg)
                }
                .accentRoundedButtonChrome(accentColor: accentColor)
                .buttonStyle(.plain)

                Button(role: .destructive, action: onDiscard) {
                    Text(L10n.discardWorkout)
                        .font(.system(size: Tokens.FontSize.lg, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Spacing.md)
                }
                .destructiveFillButtonChrome(tintColor: .red)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: Tokens.Spacing.xl)
        }
    }
}