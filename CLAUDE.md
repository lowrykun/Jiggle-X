# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

Jiggle-X is a macOS **menu bar utility** that keeps your Microsoft Teams status
Available during your working hours. Inspired by
[Jiggler](https://www.sticksoftware.com/software/Jiggler.html), but driven by a
weekly schedule (default Mon–Fri, 8:00 AM – 6:00 PM) instead of a manual switch.

Menu-bar-only agent app (`LSUIElement`), Swift/SwiftUI + AppKit, macOS 13+,
**sandboxed** with no other entitlements — every decision is made as if it will ship
on the Mac App Store. English only, but all strings go through `String(localized:)`
so translations can be added to `JiggleX/Localizable.xcstrings` later.

Spec: [`docs/superpowers/specs/2026-10-22-jiggle-x-design.md`](docs/superpowers/specs/2026-10-22-jiggle-x-design.md)
Manual QA: [`docs/manual-qa.md`](docs/manual-qa.md)

## Build Commands

```bash
# Test
xcodebuild test -project JiggleX.xcodeproj -scheme JiggleX -destination 'platform=macOS' -derivedDataPath build

# Build + run
xcodebuild build -project JiggleX.xcodeproj -scheme JiggleX -derivedDataPath build
open build/Build/Products/Debug/Jiggle-X.app

# Logs
log stream --info --predicate 'subsystem == "com.jasonlowry.JiggleX"'
```

The Xcode project is hand-authored (objectVersion 77, file-system-synchronized
groups): new files under `JiggleX/`, `Shared/` or `JiggleXTests/` are picked up
automatically — no pbxproj edits needed.

## How it keeps you Available

No cursor movement (that needs Accessibility, which the sandbox forbids). Instead,
every 15 s while **active**, if the user has been idle ≥ the idle threshold (default
2 min, 30 s–4 min, below Teams' ~5 min Away timeout), `PowerAssertionNudger` calls
`IOPMAssertionDeclareUserActivity`. That resets the system idle timer (what Teams
watches), keeps the display on and wakes it if asleep.

Consequence: during working hours the screensaver, display sleep and idle auto-lock
don't trigger. Outside hours or while paused, no new nudges are made.

## Architecture

```
JiggleX/                         # App target (module JiggleX, product "Jiggle-X.app")
├── JiggleXApp.swift             # @main, empty Settings scene
├── AppDelegate.swift            # builds ActivityController + MenuBarManager; first launch
├── MenuBarManager.swift         # status item; left-click status menu, right-click app menu; windows
├── MenuContent.swift            # pure: status title + actions per RunState
└── Views/ SettingsView.swift, AboutView.swift
Shared/
├── Constants.swift              # bundle id, UserDefaults keys
├── Models/ Schedule.swift (Weekday, TimeOfDay, summary), PauseState.swift, RunState.swift
└── Services/
    ├── ScheduleEvaluator.swift  # pure: isInWindow, nextWindowStart
    ├── ActivityController.swift # state machine, 15 s tick, wake/clock/timezone observers
    ├── SystemServices.swift     # IdleMonitor / ActivityNudger / NowProvider + system impls
    ├── PersistenceManager.swift # UserDefaults + JSON; invalid data → defaults
    ├── FirstLaunch.swift        # open Settings once on first launch
    └── LaunchAtLogin.swift      # SMAppService.mainApp (default off)
```

`ActivityController` re-derives its state on every tick from the schedule, pause
state and clock instead of scheduling boundary timers, so sleep/wake and clock
changes need nothing beyond an extra tick.

Run states: `.active`, `.paused` (until Resume), `.pausedUntil(date)` ("Pause Until
Tomorrow" — clears at the next window start, e.g. Friday → Monday 8:00),
`.outsideHours`. Pause states persist across relaunch.

Under XCTest the app delegate does nothing (the app is the test host).
