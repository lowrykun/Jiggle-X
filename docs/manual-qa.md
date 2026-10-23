# Jiggle-X v1 — Manual QA

Run the app: `open build/Build/Products/Debug/Jiggle-X.app`
Watch logs: `log stream --info --predicate 'subsystem == "com.jasonlowry.JiggleX"'`

To test outside your real hours, temporarily set an all-day schedule with a 30 s
threshold (quit the app first), then restore defaults afterwards:

```bash
pkill -f "Jiggle-X.app/Contents/MacOS"
defaults write com.jasonlowry.JiggleX schedule -data $(printf '%s' '{"days":[1,2,3,4,5,6,7],"start":{"hour":0,"minute":0},"end":{"hour":23,"minute":59},"idleThreshold":30}' | xxd -p | tr -d '\n')
open build/Build/Products/Debug/Jiggle-X.app
# ...test...
defaults delete com.jasonlowry.JiggleX schedule
```

Useful while idle-testing (run over SSH or just read afterwards in the log):
`pmset -g assertions | grep -i jiggle` and
`ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1e9) "s"; exit}'`.
Note: a Bluetooth input device can keep idle time at ~0 on its own — if idle never
climbs, Jiggle-X correctly never nudges.

## Validation spike (spec §5.1)

- [ ] **1. Idle, display on:** in working hours, leave the Mac untouched 10 min.
      Teams stays **Available** (check from your phone). Log shows
      `declared activity (ok: true)`.
- [ ] **2. Display asleep:** let the display sleep (or `pmset displaysleepnow`), wait.
      The next nudge wakes it; Teams stays Available.
- [ ] **3. Locked (nice-to-have):** Ctrl-Cmd-Q, walk away 10 min. Teams status: ____.
      If Away, note "don't lock during working hours" in AboutView.
- [ ] **4. Sandbox:** no permission prompts appeared at any point.
- [ ] **5. App Nap:** in working hours, Activity Monitor › CPU › "App Nap" column
      shows **No** for Jiggle-X (it shows Yes outside hours / while paused — fine).

If 1 or 2 fail, stop: the sandbox-only approach needs rethinking.

## UI

- [ ] Left-click: status line, schedule ("Mon–Fri, 8:00 AM – 6:00 PM"), Pause /
      Pause Until Tomorrow (active) or Resume (paused) or Pause (outside hours).
- [ ] Right-click and Control-click: Settings…, About Jiggle-X, Quit Jiggle-X.
- [ ] Icon: solid mouse when active; dimmed outline when paused / outside hours.
- [ ] Pause Until Tomorrow on a Friday → "Paused until Mon 8:00 AM".
- [ ] Settings: day toggles, start/end, end-before-start shows the error and isn't
      saved; idle stepper 30 s–4 min; changes apply immediately (icon updates).
- [ ] Launch at Login: off by default; toggle on → appears in System Settings ›
      General › Login Items; toggle off removes it.
- [ ] First launch (`defaults delete com.jasonlowry.JiggleX`) opens Settings on the
      current Space.
- [ ] Sleep the Mac mid-window, wake after the window ends → outside hours, no nudge.
