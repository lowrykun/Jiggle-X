import SwiftUI

@main
struct JiggleXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty Settings scene — Jiggle-X is a menu-bar-only agent app.
        // All UI is driven from the status item (see MenuBarManager).
        Settings {
            EmptyView()
        }
    }
}
