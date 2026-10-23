import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = ActivityController(
        persistence: .shared,
        idleMonitor: SystemIdleMonitor(),
        nudger: PowerAssertionNudger(),
        clock: SystemNowProvider()
    )
    private lazy var menuBarManager = MenuBarManager(controller: controller)

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager.setup()
        controller.onStateChange = { [weak self] state in
            self?.menuBarManager.updateIcon(for: state)
        }
        controller.start()
        menuBarManager.updateIcon(for: controller.state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }
}
