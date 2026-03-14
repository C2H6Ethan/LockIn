import Foundation
import FamilyControls
import Observation

@Observable
final class SettingsViewModel {

    // MARK: - App picker state

    var showingAppPicker = false
    private(set) var selectedAppsCount: Int

    // MARK: - Task management state

    private(set) var tasks: [Task] = []
    var showingAddTask = false

    // MARK: - Lock state

    var showingLockSheet = false
    private(set) var isLocked: Bool = false
    private(set) var lockExpiresAt: Date? = nil

    // MARK: - Reminder state

    private(set) var reminderSummary: String = ""

    // MARK: - Dependencies

    private let store: SharedStore
    private let blocking: BlockingService
    private var notificationObserver: (any NSObjectProtocol)?

    // MARK: - Init

    init(store: SharedStore = .shared, blocking: BlockingService = .shared) {
        self.store = store
        self.blocking = blocking
        self.selectedAppsCount = store.selectedApps.applicationTokens.count
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .habitsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sync()
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        sync()
    }

    // MARK: - App picker actions

    func saveSelectedApps(_ selection: FamilyActivitySelection) {
        if store.isLocked {
            var enforced = selection
            if let lockedTokens = store.lockedAppTokens {
                enforced.applicationTokens = selection.applicationTokens.union(lockedTokens.applicationTokens)
                enforced.webDomainTokens = selection.webDomainTokens.union(lockedTokens.webDomainTokens)
            }
            store.selectedApps = enforced
            store.lockedAppTokens = enforced  // grow snapshot to include newly added apps
            selectedAppsCount = enforced.applicationTokens.count
        } else {
            store.selectedApps = selection
            selectedAppsCount = selection.applicationTokens.count
        }
        blocking.updateShieldsForCurrentHabitState()
    }

    var appSelectionSummary: String {
        if selectedAppsCount == 0 { return "No apps selected" }
        return "\(selectedAppsCount) app\(selectedAppsCount == 1 ? "" : "s") selected"
    }

    // MARK: - Lock actions

    func activateLock(days: Int) {
        store.lockExpiresAt = Calendar.current.date(byAdding: .day, value: days, to: Date())
        store.lockedAppTokens = store.selectedApps
        sync()
    }

    var lockedUntilSummary: String {
        guard let date = lockExpiresAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Locked until \(formatter.string(from: date))"
    }

    // MARK: - Task actions

    func deleteTask(id: UUID) {
        store.removeTask(id: id)
        blocking.updateShieldsForCurrentHabitState()
        NotificationCenter.default.post(name: .habitsDidChange, object: nil)
        sync()
    }

    func updateTask(_ task: Task) {
        store.updateTask(task)
        blocking.updateShieldsForCurrentHabitState()
        NotificationCenter.default.post(name: .habitsDidChange, object: nil)
        sync()
    }

    // MARK: - Private

    // Mon–Sun order: 2,3,4,5,6,7,1
    private let weekdayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]

    private func sync() {
        tasks = store.tasks.sorted { a, b in
            // Weekly tasks sort first (by earliest weekday), once tasks sort last (by start date)
            let aIdx = weekdayOrder.firstIndex(where: { a.activeDays.contains($0) }) ?? Int.max
            let bIdx = weekdayOrder.firstIndex(where: { b.activeDays.contains($0) }) ?? Int.max
            if aIdx != bIdx { return aIdx < bIdx }
            // Both once tasks: sort by start date then alphabetically
            if a.isOnce && b.isOnce {
                let aDate = a.onceStartDate ?? ""
                let bDate = b.onceStartDate ?? ""
                if aDate != bDate { return aDate < bDate }
            }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        isLocked = store.isLocked
        lockExpiresAt = store.lockExpiresAt
        reminderSummary = Self.formatReminderTime(store.dailyReminderTime)
    }

    private static func formatReminderTime(_ time: Date?) -> String {
        guard let time else { return "Never" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: time)
    }
}
