import Foundation

/// Persistent activity log. Writes timestamped entries with full state snapshots to a file
/// in the App Group container so it survives app relaunches.
/// Call `ActivityLog.log("ACTION", store: SharedStore.shared)` from anywhere in the main app.
final class ActivityLog {

    static let shared = ActivityLog()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.ethanbaumgartner.lockin.activitylog", qos: .utility)
    private let maxLines = 1000
    private let trimTo   = 800

    private init() {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.AppGroup.id
        ) ?? FileManager.default.temporaryDirectory
        fileURL = container.appendingPathComponent("activity.log")
    }

    // MARK: - Public

    static func log(_ action: String, store: SharedStore = .shared) {
        #if DEBUG
        shared.write(action: action, snapshot: store.stateSnapshot)
        #endif
    }

    func readAll() -> String {
        #if DEBUG
        return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "(empty)"
        #else
        return ""
        #endif
    }

    func clear() {
        #if DEBUG
        queue.async { try? "".write(to: self.fileURL, atomically: true, encoding: .utf8) }
        #endif
    }

    var shareURL: URL { fileURL }

    // MARK: - Private

    private func write(action: String, snapshot: String) {
        queue.async {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let ts = formatter.string(from: Date())
            let line = "[\(ts)] \(action)\n          \(snapshot)\n"

            var existing = (try? String(contentsOf: self.fileURL, encoding: .utf8)) ?? ""
            existing.append(line)

            // Trim if over limit
            var lines = existing.components(separatedBy: "\n")
            if lines.count > self.maxLines {
                lines = Array(lines.suffix(self.trimTo))
                existing = lines.joined(separator: "\n")
            }

            try? existing.write(to: self.fileURL, atomically: true, encoding: .utf8)
        }
    }
}
