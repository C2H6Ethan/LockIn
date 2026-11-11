import SwiftUI

@main
struct LockInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView(environment: appDelegate.environment, router: appDelegate.router)
                .preferredColorScheme(.dark)
                .onOpenURL { appDelegate.router.open($0) }
        }
    }
}
