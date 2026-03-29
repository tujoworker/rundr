import SwiftUI

struct AppScreenBackground: View {
    let accentColor: Color
    @Environment(\.appTheme) private var theme

    var body: some View {
        LinearGradient(
            colors: [
                theme.screenGradientStart,
                theme.screenGradientEnd(accent: accentColor)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
            .ignoresSafeArea()
    }
}

struct AccentRoundedButtonChrome: ViewModifier {
    let accentColor: Color
    var cornerRadius: CGFloat = Tokens.Radius.xxxl
    var lineWidth: CGFloat = Tokens.LineWidth.regular
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(theme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.accentFill(accentColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.accentStroke(accentColor), lineWidth: lineWidth)
            )
    }
}

extension View {
    func accentRoundedButtonChrome(
        accentColor: Color,
        cornerRadius: CGFloat = Tokens.Radius.xxxl,
        lineWidth: CGFloat = Tokens.LineWidth.regular
    ) -> some View {
        modifier(
            AccentRoundedButtonChrome(
                accentColor: accentColor,
                cornerRadius: cornerRadius,
                lineWidth: lineWidth
            )
        )
    }
}

enum HealthAccessPolicy {
    static func shouldShowInitialPrompt(
        hasCompletedInitialPrompt: Bool,
        hasDismissedPromptThisLaunch: Bool,
        isAuthorized: Bool
    ) -> Bool {
        !isAuthorized && !hasCompletedInitialPrompt && !hasDismissedPromptThisLaunch
    }

    static func shouldCompleteInitialPromptAfterRequest(isAuthorized: Bool) -> Bool {
        isAuthorized
    }
}

struct SelectionToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? theme.toggleSelectedForeground : theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                        .fill(isSelected ? theme.toggleSelectedBackground : theme.surfaceInput)
                )
        }
        .buttonStyle(.plain)
    }
}

struct RootView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var ongoingWorkoutStore: OngoingWorkoutStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var workoutController: WorkoutSessionController
    @AppStorage("hasCompletedInitialHealthAccessPrompt") private var hasCompletedInitialHealthAccessPrompt = false
    @State private var isRequestingHealthAccess = false
    @State private var hasDismissedHealthAccessPromptThisLaunch = false
    @State private var hasHandledWorkoutRecoveryPromptThisLaunch = false

    var body: some View {
        ZStack {
            AppScreenBackground(accentColor: settings.primaryAccentColor)

            if let recoverySnapshot = recoverySnapshotToOffer {
                OngoingWorkoutRecoveryView(
                    snapshot: recoverySnapshot,
                    accentColor: settings.primaryAccentColor,
                    onContinue: continueRecoveredWorkout,
                    onDiscard: discardRecoveredWorkout
                )
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            } else if shouldShowInitialHealthAccess {
                HealthAccessPromptView(
                    accentColor: settings.primaryAccentColor,
                    isRequestingAccess: isRequestingHealthAccess,
                    authorizationError: healthKitManager.authorizationError,
                    onRequestAccess: requestHealthAccess,
                    onContinueWithoutHealth: dismissHealthAccessPrompt
                )
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                NavigationStack(path: $coordinator.path) {
                    HomeView(
                        onGetReady: {
                            workoutController.getReady()
                            coordinator.goToPreStart()
                        },
                        onSelectSession: { session in
                            coordinator.goToSessionDetail(id: session.id)
                        }
                    )
                    .navigationDestination(for: AppScreenState.self) { state in
                        switch state {
                        case .preStart:
                            PreStartView(onStart: {
                                workoutController.configure(
                                    trackingMode: settings.trackingMode,
                                    distanceLapDistanceMeters: settings.distanceDistanceMeters,
                                    distanceSegments: settings.distanceSegments,
                                    restMode: settings.restMode,
                                    healthKitManager: healthKitManager
                                )
                                workoutController.lapAlertsEnabled = settings.lapAlerts
                                workoutController.restAlertsEnabled = settings.restAlerts
                                Task {
                                    await workoutController.start()
                                }
                                coordinator.goToActiveSession()
                            })
                        case .intervalLibrary:
                            IntervalLibraryView()
                        case .sessionDetail(let sessionID):
                            if let session = persistence.fetchSession(id: sessionID) {
                                SessionDetailView(
                                    session: session,
                                    onUseSessionSettings: {
                                        coordinator.goToHistorySetup(id: session.id)
                                    }
                                )
                            } else {
                                Text(L10n.sessionNotFound)
                            }
                        case .historySetup(let sessionID):
                            if let session = persistence.fetchSession(id: sessionID) {
                                HistorySessionSetupView(
                                    session: session,
                                    onContinue: { workoutPlan in
                                        settings.apply(workoutPlan: workoutPlan)
                                        workoutController.getReady()
                                        coordinator.goToPreStart(replacingPath: true)
                                    }
                                )
                            } else {
                                Text(L10n.sessionNotFound)
                            }
                        case .home:
                            EmptyView()
                        }
                    }
                }
                .background(Color.clear)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: shouldShowInitialHealthAccess)
        .fullScreenCover(isPresented: $coordinator.isShowingActiveSession) {
            ActiveSessionView(onSessionEnded: {
                coordinator.sessionEnded()
            })
        }
    }

    private var shouldShowInitialHealthAccess: Bool {
        HealthAccessPolicy.shouldShowInitialPrompt(
            hasCompletedInitialPrompt: hasCompletedInitialHealthAccessPrompt,
            hasDismissedPromptThisLaunch: hasDismissedHealthAccessPromptThisLaunch,
            isAuthorized: healthKitManager.isAuthorized
        )
    }

    private var recoverySnapshotToOffer: OngoingWorkoutSnapshot? {
        guard !hasHandledWorkoutRecoveryPromptThisLaunch else { return nil }
        return ongoingWorkoutStore.startupSnapshot
    }

    private func requestHealthAccess() {
        guard !isRequestingHealthAccess else { return }

        isRequestingHealthAccess = true
        Task {
            await healthKitManager.requestAuthorization()
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.28)) {
                    isRequestingHealthAccess = false
                    hasCompletedInitialHealthAccessPrompt = HealthAccessPolicy.shouldCompleteInitialPromptAfterRequest(
                        isAuthorized: healthKitManager.isAuthorized
                    )
                }
            }
        }
    }

    private func dismissHealthAccessPrompt() {
        withAnimation(.easeInOut(duration: 0.28)) {
            hasDismissedHealthAccessPromptThisLaunch = true
        }
    }

    private func continueRecoveredWorkout() {
        guard let snapshot = ongoingWorkoutStore.startupSnapshot else { return }

        ongoingWorkoutStore.consumeStartupSnapshot()
        workoutController.restore(snapshot: snapshot, healthKitManager: healthKitManager)
        workoutController.lapAlertsEnabled = settings.lapAlerts
        workoutController.restAlertsEnabled = settings.restAlerts
        coordinator.goToActiveSession()

        withAnimation(.easeInOut(duration: 0.28)) {
            hasHandledWorkoutRecoveryPromptThisLaunch = true
        }
    }

    private func discardRecoveredWorkout() {
        ongoingWorkoutStore.clear()
        workoutController.resetForNextSession()

        withAnimation(.easeInOut(duration: 0.28)) {
            hasHandledWorkoutRecoveryPromptThisLaunch = true
        }
    }
}

private struct HealthAccessPromptView: View {
    let accentColor: Color
    let isRequestingAccess: Bool
    let authorizationError: String?
    let onRequestAccess: () -> Void
    let onContinueWithoutHealth: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Tokens.Spacing.xxl) {
                Text(L10n.rundrNeeds)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textBody)
                    .multilineTextAlignment(.center)

                Button(action: onRequestAccess) {
                    if isRequestingAccess {
                        ProgressView()
                            .tint(theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    } else {
                        Text(L10n.healthAccess)
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                }
                .accentRoundedButtonChrome(accentColor: accentColor, cornerRadius: Tokens.Radius.pill, lineWidth: Tokens.LineWidth.thick)
                .buttonStyle(.plain)
                .disabled(isRequestingAccess)

                Button(L10n.notNow, action: onContinueWithoutHealth)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)

                if let authorizationError, !authorizationError.isEmpty {
                    Text(authorizationError)
                        .font(.caption2)
                        .foregroundStyle(theme.errorText)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Tokens.Spacing.xxxl)

            Spacer()
        }
    }
}
