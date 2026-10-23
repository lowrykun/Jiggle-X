import AppKit
import SwiftUI

/// Owns the menu bar status item. Left-click shows status and Pause/Resume;
/// right-click (or control-click) shows Settings, About and Quit.
@MainActor
final class MenuBarManager: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var logWindow: NSWindow?
    private let controller: ActivityController

    init(controller: ActivityController) {
        self.controller = controller
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon(for: controller.state)
        AppLog.shared.log("Menu bar set up", category: "MenuBar")
    }

    /// Reflect the run state in the icon: solid mouse while keeping you available,
    /// dimmed outline otherwise.
    func updateIcon(for state: RunState) {
        guard let button = statusItem?.button else { return }
        let isActive = state == .active
        let image = NSImage(systemSymbolName: isActive ? "computermouse.fill" : "computermouse",
                            accessibilityDescription: "Jiggle-X")
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = !isActive
        button.toolTip = MenuContent.statusTitle(state)
    }

    // MARK: - Click handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isSecondary = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        show(isSecondary ? makeAppMenu() : makeStatusMenu())
    }

    /// Attach the menu just long enough to pop it up, so the next click is routed
    /// back to `statusItemClicked` instead of always opening this menu.
    private func show(_ menu: NSMenu) {
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func makeStatusMenu() -> NSMenu {
        controller.refresh()
        let menu = NSMenu()
        menu.addItem(disabledItem(MenuContent.statusTitle(controller.state)))
        menu.addItem(disabledItem(PersistenceManager.shared.schedule.summary()))
        menu.addItem(.separator())
        for action in MenuContent.actions(for: controller.state) {
            switch action {
            case .pause:
                menu.addItem(item(String(localized: "Pause"), #selector(pause)))
            case .pauseUntilTomorrow:
                menu.addItem(item(String(localized: "Pause Until Tomorrow"), #selector(pauseUntilTomorrow)))
            case .resume:
                menu.addItem(item(String(localized: "Resume"), #selector(resume)))
            }
        }
        return menu
    }

    private func makeAppMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(String(localized: "Settings…"), #selector(openSettings), key: ","))
        menu.addItem(item(String(localized: "View Log…"), #selector(openLog)))
        menu.addItem(item(String(localized: "About Jiggle-X"), #selector(openAbout)))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Quit Jiggle-X"), #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Actions

    @objc private func pause() { controller.pause() }
    @objc private func pauseUntilTomorrow() { controller.pauseUntilTomorrow() }
    @objc private func resume() { controller.resume() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func openSettings() {
        let controller = self.controller
        settingsWindow = present(settingsWindow, title: String(localized: "Jiggle-X Settings")) {
            SettingsView(onScheduleChange: { controller.refresh() })
        }
    }

    @objc func openAbout() {
        aboutWindow = present(aboutWindow, title: String(localized: "About Jiggle-X")) {
            AboutView()
        }
    }

    @objc func openLog() {
        logWindow = present(logWindow, title: String(localized: "Jiggle-X Log"), resizable: true) {
            LogView(log: .shared)
        }
    }

    // MARK: - Windows

    /// Bring an existing window forward, or create one hosting `content`.
    private func present<Content: View>(_ existing: NSWindow?, title: String, resizable: Bool = false,
                                        content: () -> Content) -> NSWindow {
        let window = existing ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.title = title
            window.styleMask = resizable ? [.titled, .closable, .resizable, .miniaturizable] : [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            // Agent apps have no Dock icon to bring windows forward, so always
            // open on the Space the user is looking at.
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.center()
            return window
        }()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // Activation can be refused (e.g. at launch while another app is frontmost);
        // still show the window rather than leaving it ordered out.
        window.orderFrontRegardless()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Drop closed windows so Settings re-reads persisted state next time.
        if notification.object as? NSWindow === settingsWindow { settingsWindow = nil }
        if notification.object as? NSWindow === aboutWindow { aboutWindow = nil }
        if notification.object as? NSWindow === logWindow { logWindow = nil }
    }
}
