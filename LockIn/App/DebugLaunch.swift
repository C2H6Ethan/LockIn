#if DEBUG
import Foundation

/// Debug launch arguments for screenshots and manual checks.
enum DebugLaunch {
    /// `-openNewTask` opens the Task form on launch.
    static var opensNewTask: Bool { ProcessInfo.processInfo.arguments.contains("-openNewTask") }
    /// `-openSettings` pushes Settings on launch.
    static var opensSettings: Bool { ProcessInfo.processInfo.arguments.contains("-openSettings") }
    /// `-openBypass` opens the walk screen on launch.
    static var opensBypass: Bool { ProcessInfo.processInfo.arguments.contains("-openBypass") }
    /// `-openLockSheet` pushes Settings and opens the Lock Mode sheet.
    static var opensLockSheet: Bool { ProcessInfo.processInfo.arguments.contains("-openLockSheet") }
    /// `-openEdit "Walk"` opens the Task form for the Task with that title.
    static var editsTaskTitled: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-openEdit"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    /// `-openTasks` pushes the Tasks screen on launch.
    static var opensTasks: Bool { ProcessInfo.processInfo.arguments.contains("-openTasks") }
    /// The simulator can't approve Screen Time, so seeded screenshots assume it's allowed;
    /// `-seedNoScreenTime` shows the missing-access state. `nil` asks the system.
    static var screenTimeAllowed: Bool? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-seedNoScreenTime") { return false }
        return args.contains(where: { $0.hasPrefix("-seed") }) ? true : nil
    }
}
#endif
