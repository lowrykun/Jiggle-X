# Jiggle-X — Design

Date: 2026-10-22
Status: Approved for v1 build

## 1. Intent

When the owner steps away from the desk during the workday, Microsoft Teams flips
their status to **Away** — even though they're still reachable (phone, Teams mobile).
Jiggle-X is a macOS menu-bar app that keeps the Mac looking "active" **during
user-scheduled working hours only**, so Teams stays green.

Inspired by [Jiggler](https://www.sticksoftware.com/software/Jiggler.html), but
driven by a **time-of-day schedule** instead of a manual on/off switch.

Audience: the owner first, but **every decision is made as if it will ship on the
Mac App Store** (sandboxed, no privileged permissions, App Store-friendly defaults).

## 2. Goals

- During scheduled working hours, the user's Teams status never goes Away due to
  inactivity while Jiggle-X is running.
- Zero interaction on a normal day once the schedule is set.
- At-a-glance state from the menu bar icon.
- Sandbox- and App Store-compatible from day one.

## 3. Non-goals (v1)

- Manually activating outside working hours (explicitly rejected).
- Per-day different hours, or multiple windows per day (e.g. lunch break).
- Localization (English only; strings must be localization-ready — see §8).
- Talking to Teams directly (no Teams API, no Graph, no Teams-specific code).
- Preventing sleep when the lid is closed / on battery-specific behavior.

## 4. Anti-goals (failure even if it "works")

- Requires Accessibility / Input Monitoring permission, or anything that blocks App
  Store distribution.
- Visibly moves or fights the user's cursor while they're using the Mac.
- Keeps the Mac awake outside the configured schedule, or when paused.
- Silently wrong state: icon says active but the user goes Away (or vice versa).

## 5. Core mechanism

> **Amended 2026-10-23 — the sandbox-only mechanism below failed in real use.**
> `IOPMAssertionDeclareUserActivity` keeps the display awake but does **not** reset
> the HID idle time (`CGEventSource` / `HIDIdleTime`) that Teams reads — measured: idle
> 8.3 s → 8.8 s across a successful call, and the owner showed Away. Owner decision:
> Jiggle-X is a personal project; **drop the App Sandbox / App Store goal**. The nudge is
> now a real input event: move the cursor 1 px and back via `CGEvent` posted at the HID
> tap (needs the **Accessibility** permission, requested at launch; status menu shows a
> warning item while missing), plus the existing declare-activity call to wake the
> display. Distribution: Developer ID (outside the App Store). §2's "sandbox-compatible"
> goal and §4's Accessibility anti-goal are withdrawn. Original text kept below for history.

### 5.0 Original mechanism (superseded)

**No real cursor movement.** Posting synthetic mouse events (`CGEvent`) needs the
Accessibility permission, which sandboxed apps can't obtain. Instead Jiggle-X tells
the OS the user is active:

- **Idle detection:** `CGEventSource.secondsSinceLastEventType(.combinedSessionState,
  eventType: .null)` — seconds since the last real HID input. (Builder: if this
  turns out to require a permission under sandbox, fall back to IOKit
  `IOHIDSystem` → `HIDIdleTime`; whichever works sandboxed without prompts.)
- **Nudge:** `IOPMAssertionDeclareUserActivity(..., kIOPMUserActiveLocal, ...)`.
  This resets the system idle timer, keeps the display on, and wakes it if asleep.
  Reuse the returned assertion ID across calls.
- **Loop:** while in an active window and not paused, poll every ~15 s. If idle ≥
  **idle threshold** (default **120 s**), declare user activity.
- **Idle threshold** is a user setting under "Advanced" (range 30 s – 4 min; must
  stay below Teams' ~5 min Away timeout). It is *not* derived from the display
  sleep / screensaver timeout — the user wants to stay green for the whole working
  window, and Teams' timeout is shorter than typical display timeouts.

**Consequences (accepted by owner):** during working hours the screensaver,
display sleep and idle auto-lock will not trigger. If the display is already off
when the window starts, the first nudge wakes it *(my call — consistent with "keep me
green all working hours")*.

**Trailing effect at window end / on pause is acceptable** *(my call)*: a nudge
behaves like a real input event, so after the last nudge (e.g. 5:58 PM) the display
stays on until the normal display-sleep timeout — the same as if the user had
touched the mouse. No lead-time cutoff before `end`. The anti-goal "keeps the Mac
awake outside the schedule" means *no new nudges* outside the window or while paused.

### 5.1 Step 0: validation spike (must happen before the full build)

A throwaway check that the mechanism actually keeps **new Teams for Mac** green:

1. Mac idle, display on → does Teams stay Available past 5 min with nudges? (must pass)
2. Display asleep → does the nudge wake it and keep Teams Available? (must pass)
3. Screen locked manually (Ctrl-Cmd-Q) → does Teams stay Available? (**nice-to-have**;
   if it fails, document "don't lock during working hours" in About and move on)
4. Confirm idle detection + nudge work in a **sandboxed** build with no permission prompts.

If (1) or (2) fail, stop and return to the owner — the sandbox-only approach would
need rethinking (likely a non-App Store, Accessibility-based variant).

## 6. Scheduling

### 6.1 Model

```
Schedule
  days: Set<Weekday>     // default Mon–Fri
  start: TimeOfDay       // hour, minute; default 08:00
  end:   TimeOfDay       // default 18:00
  idleThreshold: TimeInterval  // default 120 s
```

- Times are **local wall-clock time**, re-evaluated on timezone change
  (`NSSystemTimeZoneDidChange`) and on clock change (`NSSystemClockDidChange`).
- Window is `[start, end)` on enabled days. **`end` must be after `start`**;
  overnight windows are not supported in v1 (Settings prevents saving end ≤ start).
- If no days are enabled, the app is permanently "Outside working hours".

### 6.2 Run state

```
RunState
  .active                 // in window, not paused → nudging as needed
  .paused                 // user paused; persists until Resume
  .pausedUntilTomorrow    // auto-clears at the next scheduled window start
  .outsideHours           // not in window (and not paused)
```

- **Pause:** stops nudging until the user clicks Resume. Persists across window
  boundaries and app relaunch *(my call: persisted so a relaunch doesn't
  surprise-resume)*.
- **Pause Until Tomorrow:** stops nudging; clears automatically at the **next
  scheduled window start** (i.e. the next enabled day — on Friday it resumes Monday).
  Persisted across relaunch.
- **Resume:** clears either pause. If outside hours, state becomes `.outsideHours`.
- No manual activation outside hours. Outside hours, **Pause** and **Resume** are
  still available (so a user can pre-pause before a day off), but **Pause Until
  Tomorrow** is shown only while `.active` *(my call)*.
- State transitions are driven by a timer scheduled for the next boundary (window
  start/end) plus re-evaluation on wake from sleep (`NSWorkspace.didWakeNotification`),
  timezone and clock changes. Don't rely solely on a long-lived timer across sleep.

## 7. UI

All surfaces are AppKit `NSStatusItem` + `NSMenu`, SwiftUI for the Settings and
About windows — same approach as Effunde.

### 7.1 Menu bar icon

- SF Symbol mouse (`computermouse.fill` when `.active`, `computermouse` — outline,
  reduced opacity — for paused / outside hours) *(my call)*. Template image so it
  adapts to light/dark menu bar.
- Tooltip mirrors the status line.

### 7.2 Left-click menu (status + control)

```
● Active — keeping you available        (or: Paused / Paused until Mon 8:00 AM /
                                              Outside working hours)
Mon–Fri, 8:00 AM – 6:00 PM
───────────────
Pause                     (when active)
Pause Until Tomorrow      (when active)
Resume                    (when paused / paused until tomorrow)
```

Status and schedule lines are disabled (informational) items.

### 7.3 Right-click menu

```
Settings…
About Jiggle-X
───────────────
Quit Jiggle-X
```

(Quit added — *my call*; an agent app has no other way to quit.)

Left vs right click: status item button `sendAction(on: [.leftMouseUp, .rightMouseUp])`,
inspect `NSApp.currentEvent` and pop up the right `NSMenu`. Control-click behaves as
right-click.

### 7.4 Settings window

- **Working days:** seven toggles (Mon–Sun order follows the user's locale
  `firstWeekday`); default Mon–Fri.
- **Start / End:** time pickers; default 8:00 AM / 6:00 PM. Validation: end > start.
- **Launch at Login:** toggle, **default off** (App Store requirement). Implemented
  with `SMAppService.mainApp` (macOS 13+).
- **Advanced:** idle threshold (stepper or slider, 30 s – 4 min, default 2 min).
- Changes apply immediately (no Save button), re-evaluating run state.

### 7.5 First launch

On first launch (no saved settings), open the Settings window automatically and
run on the defaults immediately *(my call)*. No separate "not configured" state.
A `hasLaunchedBefore` flag in `PersistenceManager` gates this.

### 7.6 About window

App name, version, one-paragraph explanation of how it works, the
"screensaver/auto-lock won't trigger during working hours" note, and the locked-screen
caveat if the spike shows locking still flips Teams to Away. No first-run tutorial in v1.

## 8. Platform, stack, structure (mirrors Effunde)

- macOS 13+, Swift 5, SwiftUI + AppKit, `LSUIElement = true` (no Dock icon).
- **Sandboxed** (`com.apple.security.app-sandbox`), no other entitlements expected.
- Bundle ID: `com.jasonlowry.JiggleX`, team `GT69QL2KK5` — same prefix and team as
  Effunde *(my call)*.
- Product / display name: **Jiggle-X**. Swift module/target: `JiggleX` (no hyphen).
- Settings persisted via a `PersistenceManager` over `UserDefaults` + `Codable`,
  keys in `Constants.swift`, same as Effunde.
- Strings: use `String(localized:)` / SwiftUI `LocalizedStringKey` and a
  `Localizable.xcstrings` with English only, so translation later is additive.
- Git repo in `Jiggle-X/`, with `CLAUDE.md` describing the app like Effunde's.

```
Jiggle-X/
├── JiggleX.xcodeproj
├── JiggleX/
│   ├── JiggleXApp.swift          # @main
│   ├── AppDelegate.swift         # lifecycle
│   ├── MenuBarManager.swift      # status item, left/right menus, icon state
│   ├── Info.plist / JiggleX.entitlements / Localizable.xcstrings
│   └── Views/ SettingsView.swift, AboutView.swift
├── Shared/
│   ├── Constants.swift
│   ├── Models/ Schedule.swift, RunState.swift
│   └── Services/
│       ├── PersistenceManager.swift
│       ├── ScheduleEvaluator.swift   # pure: (schedule, date, calendar) → in window?, next boundary
│       ├── ActivityController.swift  # state machine: pause/resume/boundaries
│       ├── IdleMonitor.swift         # protocol + system impl (idle seconds)
│       └── ActivityNudger.swift      # protocol + IOPM impl (declare activity)
└── JiggleXTests/
```

`IdleMonitor`, `ActivityNudger` and a clock are protocols so the state machine is
unit-testable with fakes.

## 8.1 v1 scope (decided)

v1 = a signed, sandboxed build the owner runs personally: build, launch, test.
**Out of v1:** App Store packaging (app icon artwork, fastlane, ExportOptions,
listing copy, screenshots, privacy-manifest review). A placeholder/SF-Symbol-based
app icon is fine.

## 9. Testing

Unit tests (XCTest) for:
- `ScheduleEvaluator`: in/out of window, day toggles, boundaries exactly at start/end,
  next-boundary across weekends, no days enabled, DST transition days.
- `ActivityController`: every RunState transition; Pause Until Tomorrow clears at
  next window start (incl. Friday → Monday); nudge fires only when active and idle ≥
  threshold; never nudges when paused or outside hours.
- `PersistenceManager`: round-trip of schedule + pause state, defaults on first launch.

Manual QA checklist (in `docs/`): the spike scenarios in §5.1, plus wake-from-sleep
mid-window, Launch at Login, and left/right click menus.

## 10. Risks

- **Teams behavior may differ** from expectations (§5.1 mitigates).
- **App Store review** may question an app whose purpose is defeating idle status.
  Position as a "stay awake during work hours" utility (cf. Amphetamine, which ships
  on the App Store). Not a v1 blocker since v1 is personal use.
- `IOPMAssertionDeclareUserActivity` behavior could change in future macOS versions.

## 11. Left to the builder

- Exact poll interval (~15 s suggested), timer implementation, assertion naming.
- Exact SF Symbol choices / dimming treatment within §7.1's intent.
- Settings window layout and sizing.
- Whether the spike is a branch of the real project or a scratch target.
