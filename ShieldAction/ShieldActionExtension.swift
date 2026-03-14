import ManagedSettings
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    // MARK: - Private

    private func handleAction(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            scheduleBypassNotification()
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    private func scheduleBypassNotification() {
        let store = SharedStore(suiteName: Constants.AppGroup.id)
        let steps = store.stepsRequired
        let content = UNMutableNotificationContent()
        content.title = "Earn your access."
        content.body = "\(steps) steps to unlock."
        content.userInfo = ["url": Constants.Stepping.deepLink]
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Constants.Stepping.notificationID,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
