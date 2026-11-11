import SwiftUI

@main
struct LockInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment, router: appDelegate.router)
                .preferredColorScheme(.dark)
                .onOpenURL { appDelegate.router.open($0) }
        }
    }
}
