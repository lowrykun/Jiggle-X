import Foundation
import os.log

/// Somewhere to record what Jiggle-X is doing.
protocol EventLog {
    func log(_ message: String, category: String)
}

/// A plain-text log file the user can open from the menu (View Log…), mirrored to
/// the unified log at `.notice` so it also persists in Console.app. Rotates to a
/// single `Jiggle-X.1.log` once the file would exceed `maxBytes`.
final class AppLog: EventLog {
    /// Posted (object: the log) after each line is written, so viewers can append
    /// it instead of re-reading the file. `userInfo[lineKey]` is the line written.
    static let didAppend = Notification.Name("\(Constants.bundleIdentifier).AppLog.didAppend")
    static let lineKey = "line"

    static let shared = AppLog(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jiggle-X/Logs", isDirectory: true)
    )

    let fileURL: URL
    private let rotatedURL: URL
    private let maxBytes: Int
    private let clock: NowProvider
    private let formatter: DateFormatter
    private let queue = DispatchQueue(label: "\(Constants.bundleIdentifier).AppLog")

    init(directory: URL, maxBytes: Int = 1_000_000, clock: NowProvider = SystemNowProvider(),
         timeZone: TimeZone = .autoupdatingCurrent) {
        fileURL = directory.appendingPathComponent("Jiggle-X.log")
        rotatedURL = directory.appendingPathComponent("Jiggle-X.1.log")
        self.maxBytes = maxBytes
        self.clock = clock
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }

    func log(_ message: String, category: String) {
        Logger(subsystem: Constants.bundleIdentifier, category: category)
            .notice("\(message, privacy: .public)")
        let line = "\(formatter.string(from: clock.now())) [\(category)] \(message)\n"
        queue.sync { append(Data(line.utf8)) }
        NotificationCenter.default.post(name: Self.didAppend, object: self, userInfo: [Self.lineKey: line])
    }

    /// The last `maxLines` newline-terminated lines of `text`.
    static func tail(of text: String, maxLines: Int) -> String {
        var newlines = 0
        var index = text.endIndex
        while index > text.startIndex {
            let previous = text.index(before: index)
            if text[previous] == "\n", previous != text.index(before: text.endIndex) {
                newlines += 1
                if newlines == maxLines { return String(text[index...]) }
            }
            index = previous
        }
        return text
    }

    func read() -> String {
        queue.sync { (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "" }
    }

    func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: rotatedURL)
        }
    }

    private func append(_ data: Data) {
        let fm = FileManager.default
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let size = (try? fm.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        if size > 0, size + data.count > maxBytes {
            try? fm.removeItem(at: rotatedURL)
            try? fm.moveItem(at: fileURL, to: rotatedURL)
        }

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }
}
