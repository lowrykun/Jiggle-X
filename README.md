# Jiggle-X

A macOS menu bar utility that keeps your Microsoft Teams status **Available** during
your working hours, and does nothing outside them.

Inspired by [Jiggler](https://www.sticksoftware.com/software/Jiggler.html) from Stick
Software. Jiggler has a manual on/off switch; Jiggle-X follows a weekly schedule
(default Mon–Fri, 8:00 AM – 6:00 PM), so you never have to remember to turn it on or off.

## Download

Get the latest signed and notarized `.dmg` from
[Releases](https://github.com/lowrykun/Jiggle-X/releases/latest), open it, and drag
**Jiggle-X** to Applications. Requires macOS 13 Ventura or later.

On first launch, grant **Accessibility** permission (System Settings › Privacy &
Security › Accessibility). Jiggle-X needs it to post mouse events. Until you grant
it, the menu shows a warning item that opens that settings pane.

## How it works

- Every 15 seconds during your working hours, Jiggle-X checks how long you've been idle.
- If you've been idle longer than the threshold (default 2 min, adjustable from 30 s
  to 4 min, below Teams' ~5 minute Away timeout), it moves the cursor 1 pixel and
  straight back. Teams sees that as real input.
- **Left-click** the menu bar icon to see the status and Pause, Pause Until Tomorrow,
  or Resume. **Right-click** for Settings, View Log, About and Quit.
- Optional Launch at Login.

Why real mouse events? macOS's `IOPMAssertionDeclareUserActivity` wakes the display,
but it doesn't reset the HID idle time that Teams reads, so Teams still goes Away.
Posting events needs Accessibility, so Jiggle-X can't be sandboxed or sold on the Mac
App Store. It's distributed as a Developer ID–signed, notarized download.

> **Note:** while Jiggle-X is active, your screensaver, display sleep and idle
> auto-lock won't trigger. Lock your Mac manually (⌃⌘Q) when you step away. Check your
> employer's policies before using presence tools on a work machine.

## Building

```bash
xcodebuild test  -project JiggleX.xcodeproj -scheme JiggleX -destination 'platform=macOS' -derivedDataPath build
xcodebuild build -project JiggleX.xcodeproj -scheme JiggleX -derivedDataPath build
open build/Build/Products/Debug/Jiggle-X.app
```

To build with your own signing team, change `DEVELOPMENT_TEAM` (and, if you like,
the bundle identifier) in the Xcode project. `scripts/make-dmg.sh` builds a signed,
notarized release DMG.

## License

[MIT](LICENSE) © 2026 Jason Lowry
