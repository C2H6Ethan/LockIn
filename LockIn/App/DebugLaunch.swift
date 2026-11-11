#if DEBUG
import Foundation

/// Debug launch arguments for screenshots and manual checks.
enum DebugLaunch {
    /// `-openNewTask` opens the Task form on launch.
    static var opensNewTask: Bool { ProcessInfo.processInfo.arguments.contains("-openNewTask") }
    /// `-openSettings` pushes Settings on launch.
    static var opensSettings: Bool { ProcessInfo.processInfo.arguments.contains("-openSettings") }
}
#endif
