import LockInCore
import LockInPlatform
import ManagedSettings

/// Handles the Shield's buttons. "Lock In" closes it; "Earn access" sends a notification that opens the app.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        if action == .secondaryButtonPressed {
            // Extensions can't open apps directly; a notification is the only route into LockIn.
            UserNotificationPoster().post(
                id: "earn-access",
                title: "Earn your access.",
                body: "Tap to open Lock In.",
                deepLink: DeepLink.bypass.url
            )
            if let storage = UserDefaultsStorage.appGroup() {
                LockInStore(storage: storage).log("Shield: earn access requested", source: .shieldAction)
            }
        }
        return .close
    }
}
