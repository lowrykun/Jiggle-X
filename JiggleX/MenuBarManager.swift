import AppKit

/// Owns the menu bar status item.
@MainActor
final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "Jiggle-X")
        image?.isTemplate = true
        statusItem?.button?.image = image
    }
}
