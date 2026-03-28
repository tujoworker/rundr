import Foundation

enum ActionButtonCommand: String {
    case startWorkout
    case markLap
}

enum ActionButtonCommandStore {
    private static let pendingCommandKey = "action_button.pending_command"
    private static let notificationName = "com.rundr.watchapp.action-button-command"

    static func queue(_ command: ActionButtonCommand) {
        UserDefaults.standard.set(command.rawValue, forKey: pendingCommandKey)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName as CFString),
            nil,
            nil,
            true
        )
    }

    static func consumePendingCommand() -> ActionButtonCommand? {
        guard let rawValue = UserDefaults.standard.string(forKey: pendingCommandKey),
              let command = ActionButtonCommand(rawValue: rawValue) else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: pendingCommandKey)
        return command
    }

    static var darwinNotificationName: CFNotificationName {
        CFNotificationName(notificationName as CFString)
    }
}
