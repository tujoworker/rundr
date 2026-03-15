import Foundation

final class ActionButtonCommandObserver {
    private let onCommand: @MainActor () -> Void
    private var isObserving = false

    init(onCommand: @escaping @MainActor () -> Void) {
        self.onCommand = onCommand
    }

    deinit {
        stop()
    }

    func start() {
        guard !isObserving else { return }
        isObserving = true

        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let instance = Unmanaged<ActionButtonCommandObserver>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    instance.onCommand()
                }
            },
            ActionButtonCommandStore.darwinNotificationName.rawValue,
            nil,
            .deliverImmediately
        )
    }

    func stop() {
        guard isObserving else { return }
        isObserving = false

        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            ActionButtonCommandStore.darwinNotificationName,
            nil
        )
    }
}
