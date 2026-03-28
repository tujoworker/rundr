import SwiftUI

struct OngoingWorkoutRecoveryView: View {
    let snapshot: OngoingWorkoutSnapshot
    let accentColor: Color
    let onContinue: () -> Void
    let onDiscard: () -> Void

    private var startedText: String {
        Formatters.historySessionDateTimeString(from: snapshot.sessionStartDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 38)

            VStack(spacing: 16) {
                Text(L10n.recoverWorkoutTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(startedText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Button(action: onContinue) {
                    Text(L10n.resumeWorkout)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }

                Button(role: .destructive, action: onDiscard) {
                    Text(L10n.discardWorkout)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .tint(accentColor)

            Spacer(minLength: 12)
        }
    }
}