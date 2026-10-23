import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = ActivityController(
        persistence: .shared,
        idleMonitor: SystemIdleMonitor(),
        nudger: PowerAssertionNudger(),
        clock: SystemNowProvider(),
        napPreventer: SystemNapPreventer()
    )
    private lazy var menuBarManager = MenuBarManager(controller: controller)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests use the app as their host; don't nudge, show windows or
        // consume the first-launch flag while they run.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        menuBarManager.setup()
        controller.onStateChange = { [weak self] state in
            self?.menuBarManager.updateIcon(for: state)
        }
        controller.start()
        menuBarManager.updateIcon(for: controller.state)

        if FirstLaunch.shouldShowSettings(.shared) {
            menuBarManager.openSettings()
            FirstLaunch.markLaunched(.shared)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }
}
