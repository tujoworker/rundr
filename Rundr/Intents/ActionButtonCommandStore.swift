import Combine
import Foundation

enum ActionButtonCommand: String {
    case startWorkout
    case markLap
}

enum ActionButtonCommandStore {
    private static let sharedDefaultsSuiteName = "group.com.rundr.watchapp"
    private static let pendingCommandKey = "action_button.pending_command"
    private static let notificationName = "com.rundr.watchapp.action-button-command"

    /// In-process signal emitted every time a command is queued.
    /// Provides a reliable trigger when the intent runs in the same process
    /// (openAppWhenRun = true), where Darwin notifications can be unreliable.
    static let commandQueued = PassthroughSubject<Void, Never>()

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: sharedDefaultsSuiteName) ?? .standard
    }

    static func queue(_ command: ActionButtonCommand) {
        defaults.set(command.rawValue, forKey: pendingCommandKey)
        // In-process signal (primary path when intent runs in same process)
        commandQueued.send()
        // Cross-process Darwin notification (fallback for out-of-process intents)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName as CFString),
            nil,
            nil,
            true
        )
    }

    static func pendingCommand() -> ActionButtonCommand? {
        guard let rawValue = defaults.string(forKey: pendingCommandKey),
              let command = ActionButtonCommand(rawValue: rawValue) else {
            return nil
        }

        return command
    }

    static func consumePendingCommand() -> ActionButtonCommand? {
        let command = pendingCommand()
        guard command != nil else { return nil }
        defaults.removeObject(forKey: pendingCommandKey)
        return command
    }

    static func clearPendingCommand() {
        defaults.removeObject(forKey: pendingCommandKey)
    }

    static var darwinNotificationName: CFNotificationName {
        CFNotificationName(notificationName as CFString)
    }
}
