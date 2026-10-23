import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBarManager = MenuBarManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager.setup()
    }
}
