import Foundation
import FamilyControls
import Observation

@Observable
final class SettingsViewModel {

    // MARK: - App picker state

    var showingAppPicker = false
    private(set) var selectedCount: Int

    // MARK: - Task management state

    private(set) var tasks: [Task] = []
    var showingAddTask = false

    // MARK: - Lock state

    var showingLockSheet = false
    private(set) var isLocked: Bool = false
    private(set) var lockExpiresAt: Date? = nil

    // MARK: - Custom URL state

    private(set) var customDomains: [String] = []

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
        let sel = store.selectedApps
        self.selectedCount = sel.applicationTokens.count + sel.webDomainTokens.count
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

    // MARK: - Picker actions

    func saveSelectedApps(_ selection: FamilyActivitySelection) {
        // Strip category tokens only — app and web domain tokens both contribute to blocking.
        var cleaned = selection
        cleaned.categoryTokens = []

        if store.isLocked {
            var enforced = cleaned
            if let locked = store.lockedAppTokens {
                enforced.applicationTokens = cleaned.applicationTokens.union(locked.applicationTokens)
                enforced.webDomainTokens = cleaned.webDomainTokens.union(locked.webDomainTokens)
            }
            store.selectedApps = enforced
            store.lockedAppTokens = enforced
            selectedCount = enforced.applicationTokens.count + enforced.webDomainTokens.count
        } else {
            store.selectedApps = cleaned
            selectedCount = cleaned.applicationTokens.count + cleaned.webDomainTokens.count
        }
        blocking.updateShieldsForCurrentHabitState()
    }

    var appSelectionSummary: String {
        selectedCount == 0 ? "None" : "\(selectedCount) selected"
    }

    func clearAllBlocked() {
        store.selectedApps = FamilyActivitySelection()
        store.lockedAppTokens = nil
        selectedCount = 0
        blocking.updateShieldsForCurrentHabitState()
    }

    // MARK: - Custom URL actions

    var customDomainSummary: String {
        customDomains.isEmpty ? "None" : "\(customDomains.count) domain\(customDomains.count == 1 ? "" : "s")"
    }

    func addCustomDomain(_ raw: String) {
        var domain = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip scheme
        for scheme in ["https://", "http://"] {
            if domain.hasPrefix(scheme) { domain = String(domain.dropFirst(scheme.count)) }
        }
        // Strip www. prefix only (not mid-string)
        if domain.hasPrefix("www.") { domain = String(domain.dropFirst(4)) }
        // Strip path component
        if let slashIndex = domain.firstIndex(of: "/") { domain = String(domain[domain.startIndex..<slashIndex]) }
        guard !domain.isEmpty, !customDomains.contains(domain), customDomains.count < 50 else { return }
        var domains = store.selectedWebDomains
        domains.append(domain)
        store.selectedWebDomains = domains
        if store.isLocked { store.lockedWebDomains = domains }
        blocking.updateShieldsForCurrentHabitState()
        sync()
    }

    func removeCustomDomain(_ domain: String) {
        guard !store.isLocked else { return }
        var domains = store.selectedWebDomains
        domains.removeAll { $0 == domain }
        store.selectedWebDomains = domains
        blocking.updateShieldsForCurrentHabitState()
        sync()
    }

    func clearCustomDomains() {
        guard !store.isLocked else { return }
        store.selectedWebDomains = []
        store.lockedWebDomains = nil
        blocking.updateShieldsForCurrentHabitState()
        sync()
    }

    // MARK: - Lock actions

    func activateLock(days: Int) {
        store.lockExpiresAt = Calendar.current.date(byAdding: .day, value: days, to: Date())
        store.lockedAppTokens = store.selectedApps  // snapshot includes app + web tokens
        store.lockedWebDomains = store.selectedWebDomains
        sync()
    }

    var lockedUntilSummary: String {
        guard let date = lockExpiresAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Locked until \(formatter.string(from: date))"
    }

    // MARK: - Task actions

    func deleteAllTasks() {
        for task in store.tasks {
            store.removeTask(id: task.id)
        }
        blocking.updateShieldsForCurrentHabitState()
        NotificationCenter.default.post(name: .habitsDidChange, object: nil)
        ActivityLog.log("ALL_TASKS_DELETED")
        sync()
    }

    func deleteTask(id: UUID) {
        let title = store.tasks.first(where: { $0.id == id })?.title ?? "unknown"
        store.removeTask(id: id)
        blocking.updateShieldsForCurrentHabitState()
        NotificationCenter.default.post(name: .habitsDidChange, object: nil)
        ActivityLog.log("TASK_DELETED: \"\(title)\"")
        sync()
    }

    func updateTask(_ task: Task) {
        let stStr = task.blockingStartTime.map { "\($0.hour ?? 0):\(String(format: "%02d", $0.minute ?? 0))" } ?? "nil"
        store.updateTask(task)
        blocking.updateShieldsForCurrentHabitState()
        SchedulingService.shared.scheduleBlockingStartTimeMonitors(for: store.tasks)
        NotificationCenter.default.post(name: .habitsDidChange, object: nil)
        ActivityLog.log("TASK_EDITED: \"\(task.title)\" blocksApps=\(task.blocksApps) startTime=\(stStr)")
        sync()
    }

    // MARK: - Private

    // Mon–Sun order: 2,3,4,5,6,7,1
    private let weekdayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]

    private func sync() {
        tasks = store.tasks.sorted { a, b in
            // Once tasks first
            if a.isOnce != b.isOnce { return a.isOnce }
            // Within once tasks: sort by date
            if a.isOnce && b.isOnce {
                let aDate = a.onceStartDate ?? ""
                let bDate = b.onceStartDate ?? ""
                if aDate != bDate { return aDate < bDate }
            }
            // Within recurring tasks: sort by earliest active weekday
            let aIdx = weekdayOrder.firstIndex(where: { a.activeDays.contains($0) }) ?? Int.max
            let bIdx = weekdayOrder.firstIndex(where: { b.activeDays.contains($0) }) ?? Int.max
            if aIdx != bIdx { return aIdx < bIdx }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        let sel = store.selectedApps
        selectedCount = sel.applicationTokens.count + sel.webDomainTokens.count
        isLocked = store.isLocked
        lockExpiresAt = store.lockExpiresAt
        customDomains = store.selectedWebDomains
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
