import AppKit
import SwiftUI

/// Shows the tail of Jiggle-X's log file, refreshing every few seconds.
struct LogView: View {
    let log: AppLog

    /// Rendering a whole 1 MB file in a Text view is slow; the tail is what matters.
    private static let maxLines = 2_000

    @State private var text = ""
    @State private var autoRefresh = true
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    Text(text.isEmpty ? String(localized: "The log is empty.") : text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .onChange(of: text) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
                .onAppear { reload(); proxy.scrollTo("bottom", anchor: .bottom) }
            }
            Divider()
            HStack {
                Toggle("Auto-refresh", isOn: $autoRefresh)
                Spacer()
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([log.fileURL])
                }
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.read(), forType: .string)
                }
                Button("Clear") {
                    log.clear()
                    reload()
                }
                Button("Refresh") { reload() }
                    .keyboardShortcut("r")
            }
            .padding(8)
        }
        .frame(minWidth: 640, minHeight: 360)
        .onReceive(timer) { _ in if autoRefresh { reload() } }
    }

    private func reload() {
        let lines = log.read().split(separator: "\n", omittingEmptySubsequences: false)
        let tail = lines.suffix(Self.maxLines).joined(separator: "\n")
        if tail != text { text = tail }
    }
}
