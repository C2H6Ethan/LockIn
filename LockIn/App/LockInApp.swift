import LockInPlatform
import SwiftUI

@main
struct LockInApp: App {
    private let environment = AppEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Launch and every return to the foreground re-sync schedules and the Shield.
            if phase == .active { environment.enforcement.refresh(reason: "foreground") }
        }
    }
}
