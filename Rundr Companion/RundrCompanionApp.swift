import SwiftUI
import UniformTypeIdentifiers
import UIKit

@main
struct RundrCompanionApp: App {
    @StateObject private var persistence = PersistenceManager()
    @StateObject private var syncManager = WatchConnectivitySyncManager()
    @StateObject private var settings = SettingsStore()
    @StateObject private var transferCoordinator = CompanionTransferCoordinator()

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tabBarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.72)
        tabBarAppearance.shadowColor = UIColor.separator.withAlphaComponent(0.12)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithTransparentBackground()
        navigationBarAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
    }

    var body: some Scene {
        WindowGroup {
            CompanionRootView()
            .withAppTheme()
            .environmentObject(persistence)
            .environmentObject(syncManager)
            .environmentObject(settings)
            .environmentObject(transferCoordinator)
            .modelContainer(persistence.modelContainer)
            .task {
                syncManager.attachPersistence(persistence)
                syncManager.attachSettings(settings)
                syncManager.activate()
            }
            .onChange(of: settings.currentWorkoutPlan) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.distanceUnit) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.primaryColor) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.appearanceMode) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.syncAppearanceMode) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.lapAlerts) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.restAlerts) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
            .onChange(of: settings.intervalPresets) { _, _ in
                syncManager.publishSettingsSnapshot()
            }
        }
    }
}

@MainActor
final class CompanionTransferCoordinator: ObservableObject {
    @Published var sharePayload: CompanionSharePayload?
    @Published var isImporterPresented = false
    @Published var notice: CompanionTransferNotice?

    func presentImporter() {
        isImporterPresented = true
    }

    func sharePlan(workoutPlan: WorkoutPlanSnapshot, title: String?, description: String?, settings: SettingsStore) {
        let resolvedTitle = IntervalPreset.sanitizeTitle(title) ?? settings.title(for: workoutPlan)
        let sharedAt = Date()
        let payload = RundrPlanTransfer(
            autor: planAutor(for: workoutPlan),
            title: resolvedTitle,
            description: IntervalPreset.sanitizeDescription(description),
            sharedAt: sharedAt,
            workoutPlan: workoutPlan
        )
        if share(payload, suggestedName: resolvedTitle, pathExtension: "rundrplan") {
            settings.recordPresetShare(for: workoutPlan, sharedAt: sharedAt)
        }
    }

    func shareSession(_ session: Session) {
        let sharedAt = Date()
        let payload = RundrSessionTransfer(
            autor: UIDevice.current.name,
            sharedAt: sharedAt,
            session: SessionSyncRecord(session: session)
        )
        share(payload, suggestedName: sessionFileName(for: session), pathExtension: "rundrsession")
    }

    func handleImportResult(
        _ result: Result<URL, Error>,
        settings: SettingsStore,
        persistence: PersistenceManager
    ) {
        switch result {
        case let .success(url):
            importTransfer(from: url, settings: settings, persistence: persistence)

        case let .failure(error):
            guard (error as NSError).code != NSUserCancelledError else { return }
            notice = CompanionTransferNotice(
                title: L10n.transferFailedTitle,
                message: L10n.transferFailedMessage
            )
        }
    }

    func importTransfer(from url: URL, settings: SettingsStore, persistence: PersistenceManager) {
        do {
            let data = try readData(from: url)

            if let planTransfer = try? JSONDecoder().decode(RundrPlanTransfer.self, from: data) {
                guard settings.saveIntervalPreset(
                    planTransfer.workoutPlan,
                    customTitle: planTransfer.title,
                    importedAt: Date(),
                    customDescription: planTransfer.description,
                    updatesDescription: true
                ) != nil else {
                    throw CompanionTransferError.invalidPlan
                }

                notice = CompanionTransferNotice(
                    title: L10n.planImportedTitle,
                    message: L10n.planImportedMessage
                )
                return
            }

            if let sessionTransfer = try? JSONDecoder().decode(RundrSessionTransfer.self, from: data) {
                persistence.upsertSessionRecord(sessionTransfer.session)
                notice = CompanionTransferNotice(
                    title: L10n.sessionImportedTitle,
                    message: L10n.sessionImportedMessage
                )
                return
            }

            throw CompanionTransferError.unsupportedFile
        } catch {
            notice = CompanionTransferNotice(
                title: L10n.transferFailedTitle,
                message: L10n.transferFailedMessage
            )
        }
    }

    func cleanupSharedFile() {
        guard let url = sharePayload?.url else { return }
        try? FileManager.default.removeItem(at: url)
        sharePayload = nil
    }

    @discardableResult
    private func share<T: Encodable>(_ payload: T, suggestedName: String, pathExtension: String) -> Bool {
        do {
            cleanupSharedFile()

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(sanitizedFileName(suggestedName))
                .appendingPathExtension(pathExtension)

            try data.write(to: url, options: .atomic)
            sharePayload = CompanionSharePayload(url: url)
            return true
        } catch {
            notice = CompanionTransferNotice(
                title: L10n.shareFailedTitle,
                message: L10n.shareFailedMessage
            )
            return false
        }
    }

    private func readData(from url: URL) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try Data(contentsOf: url)
    }

    private func sessionFileName(for session: Session) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd HH-mm"
        return "Rundr Session \(formatter.string(from: session.startedAt))"
    }

    private func planAutor(for workoutPlan: WorkoutPlanSnapshot) -> String {
        let signature = IntervalPresetSignature(workoutPlan: workoutPlan)

        if SettingsStore.predefinedIntervalPresets.contains(where: { $0.signature == signature }) {
            return "preset"
        }

        return UIDevice.current.name
    }

    private func sanitizedFileName(_ value: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        let cleanedScalars = value.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : "-"
        }
        let cleaned = String(cleanedScalars)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -"))

        return cleaned.isEmpty ? "Rundr" : cleaned
    }
}

private enum CompanionTransferError: Error {
    case invalidPlan
    case unsupportedFile
}

struct CompanionSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

struct CompanionTransferNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct CompanionShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension UTType {
    static let rundrPlan = UTType(exportedAs: "com.rundr.plan")
    static let rundrSession = UTType(exportedAs: "com.rundr.session")
}
