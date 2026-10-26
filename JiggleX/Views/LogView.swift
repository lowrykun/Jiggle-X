import AppKit
import SwiftUI

/// Shows the tail of Jiggle-X's log file and appends new lines as they're written.
struct LogView: View {
    @StateObject private var console: LogConsole

    init(log: AppLog) {
        _console = StateObject(wrappedValue: LogConsole(log: log))
    }

    var body: some View {
        VStack(spacing: 0) {
            LogTextView(scrollView: console.scrollView)
            Divider()
            HStack {
                Spacer()
                Button("Show in Finder") { console.showInFinder() }
                Button("Copy") { console.copy() }
                Button("Clear") { console.clear() }
                Button("Refresh") { console.reload() }
                    .keyboardShortcut("r")
            }
            .padding(8)
        }
        .frame(minWidth: 640, minHeight: 360)
    }
}

private struct LogTextView: NSViewRepresentable {
    let scrollView: NSScrollView

    func makeNSView(context: Context) -> NSScrollView { scrollView }
    func updateNSView(_ nsView: NSScrollView, context: Context) {}
}

/// Owns the log's text view. Loads the file's tail once, then appends each line
/// AppLog announces, so an open log window costs nothing between log lines.
@MainActor
final class LogConsole: ObservableObject {
    /// Laying out a whole 1 MB file is slow; the tail is what matters.
    static let maxLines = 2_000

    let scrollView = NSTextView.scrollableTextView()
    private let log: AppLog
    private let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
        .foregroundColor: NSColor.textColor,
    ]
    private var showingPlaceholder = false
    private var appendedLines = 0
    private var observer: NSObjectProtocol?

    private var textView: NSTextView { scrollView.documentView as! NSTextView }

    init(log: AppLog) {
        self.log = log
        textView.isEditable = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        reload()
        observer = NotificationCenter.default.addObserver(forName: AppLog.didAppend, object: log, queue: .main) {
            [weak self] note in
            guard let line = note.userInfo?[AppLog.lineKey] as? String else { return }
            MainActor.assumeIsolated { self?.append(line) }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reload() {
        let tail = AppLog.tail(of: log.read(), maxLines: Self.maxLines)
        showingPlaceholder = tail.isEmpty
        appendedLines = 0
        let text = tail.isEmpty ? String(localized: "The log is empty.") : tail
        textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attributes))
        textView.scrollToEndOfDocument(nil)
    }

    func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([log.fileURL])
    }

    func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(log.read(), forType: .string)
    }

    func clear() {
        log.clear()
        reload()
    }

    private func append(_ line: String) {
        // Re-trim from the file once enough lines have piled up past the tail.
        if showingPlaceholder || appendedLines >= Self.maxLines { return reload() }
        appendedLines += 1
        let wasAtBottom = scrollView.documentVisibleRect.maxY >= textView.bounds.maxY - 1
        textView.textStorage?.append(NSAttributedString(string: line, attributes: attributes))
        if wasAtBottom { textView.scrollToEndOfDocument(nil) }
    }
}
