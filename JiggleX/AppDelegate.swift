import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = ActivityController(
        persistence: .shared,
        idleMonitor: SystemIdleMonitor(),
        nudger: PowerAssertionNudger(),
        clock: SystemNowProvider(),
        napPreventer: SystemNapPreventer(),
        eventLog: AppLog.shared
    )
    private lazy var menuBarManager = MenuBarManager(controller: controller)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests use the app as their host; don't nudge, show windows or
        // consume the first-launch flag while they run.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        AppLog.shared.log("Jiggle-X \(version) launched; schedule: \(PersistenceManager.shared.schedule.summary())", category: "App")
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
        AppLog.shared.log("Quitting", category: "App")
        controller.stop()
    }
}
