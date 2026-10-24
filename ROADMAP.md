# Roadmap

What's next for Emmental, roughly in order.

## Day-to-day reliability

- [x] Create a signing identity (`scripts/create-signing-cert.sh`), `make install`,
      and grant Input Monitoring one last time, so DPI and battery survive rebuilds
- [ ] Restart and confirm Emmental opens at login with saved settings applied
- [x] Survive sleep: staged reapply (1/3/8 s) after wake, unlock and reconnect;
      15-second drift check for acceleration and scroll speed; HID++ requests
      get unique IDs and are retried; key events are logged
- [ ] Verify with a real sleep (5–10 min) that DPI and SmartShift come back, then
      read `/usr/bin/log show --last 30m --predicate 'subsystem == "app.emmental.Emmental"'`
- [ ] Live with it for a few days; with DPI around 1900, try pointer speed 2–3

## Apple silicon

- [ ] Universal release build (`swift build --arch arm64 --arch x86_64`) so one
      download runs natively on Intel and Apple silicon. Until then, an Intel
      build runs on Apple silicon through Rosetta, which macOS offers to install
      on first launch.
- [ ] Test on an Apple silicon Mac: acceleration and scroll speed, HID++ (DPI,
      battery, SmartShift), Input Monitoring, open at login and sleep

## Features

- [x] Pointer speed past the System Settings maximum
- [x] Scroll speed
- [x] Sensor DPI over HID++
- [x] Battery level next to the mouse name (HID++ `0x1004`, falling back to `0x1000`)
- [x] **SmartShift** (HID++ `0x2110`): how hard a flick switches the wheel to
      free-spin, or turn auto-switching off. Reapplied on reconnect like DPI.
- [x] **High-resolution scrolling** (HID++ `0x2121`), experimental
- [ ] Decide on high-resolution scrolling: if macOS doesn't scale the 15× steps
      down, either drop it or scale wheel events ourselves (needs Accessibility)
- [x] **Bolt / Unifying receiver support**: HID++ device indexes 1–6, discovery by
      adjustable DPI, reapply on the receiver's reconnect notification
- [ ] Test receiver support on real hardware
- [x] `--diagnose` mode: dumps what Emmental reads over HID++, read-only
- [x] Slim menu (Speed, Acceleration) plus a Settings window for set-and-forget
      options; DPI renamed Speed, pointer speed renamed Acceleration
- [ ] **Check for updates**: a "Check for Updates" button in the About window that
      asks GitHub Releases (`/repos/Huseyinnurbaki/emmental/releases/latest`) for
      the newest tag and compares it to `CFBundleShortVersionString`. Shows
      "You're up to date" or links to the download. Manual by default, no
      background updater and no auto-install, which is the point of Emmental.
      Needs the repo to be public.

## Open source

- [x] License: MIT
- [ ] README polish: screenshots of the menu and the About window, and a short
      "why" (vendor apps are heavy; Emmental is about 8 MB)
- [ ] GitHub link in the About window
- [ ] Release workflow: GitHub Actions builds a zipped `.app` for each version tag
- [ ] Document the "unidentified developer" workaround for downloaded builds
      (right-click › Open, or `xattr -dr com.apple.quarantine`), or sign and
      notarize with an Apple Developer ID
- [ ] Homebrew cask: `brew install --cask emmental`
