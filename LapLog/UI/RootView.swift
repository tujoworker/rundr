import SwiftUI

struct AppScreenBackground: View {
    let accentColor: Color

    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                accentColor.opacity(0.18)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct RootView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @EnvironmentObject var persistence: PersistenceManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var workoutController: WorkoutSessionController
    @AppStorage("hasCompletedInitialHealthAccessPrompt") private var hasCompletedInitialHealthAccessPrompt = false
    @State private var isRequestingHealthAccess = false
    @State private var hasDismissedHealthAccessPromptThisLaunch = false

    var body: some View {
        ZStack {
            AppScreenBackground(accentColor: settings.primaryAccentColor)

            if shouldShowInitialHealthAccess {
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
                                    healthKitManager: healthKitManager
                                )
                                Task {
                                    await workoutController.start()
                                }
                                coordinator.goToActiveSession()
                            })
                        case .sessionDetail(let sessionID):
                            if let session = persistence.fetchSession(id: sessionID) {
                                SessionDetailView(session: session)
                            } else {
                                Text("Session not found")
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
        !hasCompletedInitialHealthAccessPrompt && !hasDismissedHealthAccessPromptThisLaunch
    }

    private func requestHealthAccess() {
        guard !isRequestingHealthAccess else { return }

        isRequestingHealthAccess = true
        Task {
            await healthKitManager.requestAuthorization()
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.28)) {
                    isRequestingHealthAccess = false
                    hasCompletedInitialHealthAccessPrompt = true
                }
            }
        }
    }

    private func dismissHealthAccessPrompt() {
        withAnimation(.easeInOut(duration: 0.28)) {
            hasDismissedHealthAccessPromptThisLaunch = true
        }
    }
}

private struct HealthAccessPromptView: View {
    let accentColor: Color
    let isRequestingAccess: Bool
    let authorizationError: String?
    let onRequestAccess: () -> Void
    let onContinueWithoutHealth: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Text("LapLog needs:")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Button(action: onRequestAccess) {
                    if isRequestingAccess {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 50)
                    } else {
                        Text("Health Access")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(isRequestingAccess)

                Button("Not now", action: onContinueWithoutHealth)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                if let authorizationError, !authorizationError.isEmpty {
                    Text(authorizationError)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 18)

            Spacer()
        }
    }
}
