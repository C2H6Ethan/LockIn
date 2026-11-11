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
            let store = UserDefaultsStorage.appGroup().map { LockInStore(storage: $0) }
            let steps = store.map { $0.read(.bypasses).nextStepCost(on: DayKey(Date(), calendar: .current), calendar: .current) }
            UserNotificationPoster().post(
                id: "earn-access",
                title: "Earn a Bypass.",
                body: steps.map { "Walk \($0) steps to lift the Shield for 15 minutes." } ?? "Tap to open Lock In.",
                deepLink: DeepLink.bypass.url
            )
            store?.log("Shield: Bypass requested", source: .shieldAction)
        }
        return .close
    }
}
