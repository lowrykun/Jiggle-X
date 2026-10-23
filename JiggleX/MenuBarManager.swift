import AppKit
import SwiftUI
import os.log

/// Owns the menu bar status item. Left-click shows status and Pause/Resume;
/// right-click (or control-click) shows Settings, About and Quit.
@MainActor
final class MenuBarManager: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private let controller: ActivityController
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "MenuBar")

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
        logger.info("Menu bar set up")
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
        // Filled in with SettingsView (Task 6).
    }

    @objc func openAbout() {
        // Filled in with AboutView (Task 6).
    }
}
