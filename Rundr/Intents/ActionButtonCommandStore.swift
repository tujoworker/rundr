import Foundation

enum ActionButtonCommand: String {
    case startWorkout
    case markLap
}

enum ActionButtonCommandStore {
    private static let sharedDefaultsSuiteName = "group.com.rundr.watchapp"
    private static let pendingCommandKey = "action_button.pending_command"
    private static let notificationName = "com.rundr.watchapp.action-button-command"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: sharedDefaultsSuiteName) ?? .standard
    }

    static func queue(_ command: ActionButtonCommand) {
        defaults.set(command.rawValue, forKey: pendingCommandKey)
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
