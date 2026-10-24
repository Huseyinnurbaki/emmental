# Roadmap

What's next for Emmental, roughly in order.

## Day-to-day reliability

- [x] Signing identity (`scripts/create-signing-cert.sh`), so Input Monitoring
      survives rebuilds
- [x] Survive sleep and reconnects: staged reapply (1/3/8 s) after wake, unlock
      and reconnect; fresh HID++ connections and a fresh device list each time;
      unresponsive connections replaced; HID++ requests get unique IDs and are
      retried; 15-second drift check for acceleration and scroll speed; logging
- [x] Verified with a mouse power cycle: DPI and SmartShift come back on their own
- [ ] Verify after a real sleep (5–10 min), then read
      `/usr/bin/log show --last 30m --predicate 'subsystem == "app.emmental.Emmental"'`
- [ ] Restart and confirm Emmental opens at login with saved settings applied
- [ ] Live with it for a few days; with DPI around 1900, try acceleration 2–3

## Apple silicon

- [x] Universal release build (`make release`): one download runs natively on
      Intel and Apple silicon. Local `make` builds are still for the Mac they're
      built on.
- [ ] Test on an Apple silicon Mac: acceleration and scroll speed, HID++ (DPI,
      battery, SmartShift), Input Monitoring, open at login and sleep

## Features

- [x] Acceleration past the System Settings maximum (up to 8.0)
- [x] Scroll speed
- [x] Speed: sensor DPI over HID++ (`0x2201`)
- [x] Battery level next to the mouse name (HID++ `0x1004`, falling back to `0x1000`)
- [x] SmartShift (HID++ `0x2110`): auto-switch on or off, and the free-spin threshold
- [x] High-resolution scrolling (HID++ `0x2121`)
- [x] Bolt / Unifying receiver support: device indexes 1–6, discovery by
      adjustable DPI, reapply on the receiver's reconnect notification
- [x] `--diagnose` mode: dumps what Emmental reads over HID++, read-only
- [x] Menu with Speed, Acceleration and Scroll speed; a Settings window (⌘,) for
      SmartShift, high-res scrolling and open at login; app icon
- [x] High-resolution scrolling verified on the MX Master 3S: macOS scales the 15×
      steps, so the distance per notch stays the same and it's just smoother
- [ ] Test receiver support on real hardware
- [x] **Check for Updates** in Settings: reads the website's `version.json` and
      compares it with the app's version; "You're up to date" or Install Update.
      Manual only, no cookies, no background checks.

## Website (emmental.artichoke.monster)

- [x] Landing page in `landing/`: a Mac desktop with the real menu, a cheese
      pointer that shows Speed and Acceleration, windows opened from the Dock,
      a Wi-Fi menu and an easter egg
- [x] SEO and link previews: meta and Open Graph tags, JSON-LD, robots.txt,
      sitemap.xml, llms.txt, `og.png` (`make og`)
- [x] Cloudflare deploy from the repo (`wrangler.jsonc`); pushes to `main` redeploy
- [x] Custom domain `emmental.artichoke.monster` live on Cloudflare; every file
      and the link preview tags checked
- [x] Download button points at the latest GitHub release's `Emmental.zip`
      (works once the repo is public and the first release exists)
- [ ] Pick the wallpaper (cheese moon today, glass waves suggested). If the moon
      goes, move the easter egg.

## Open source

- [x] License: MIT
- [x] CONTRIBUTING.md, SECURITY.md, and issue forms (mouse report, bug, feature)
- [x] "Open Anyway" steps for builds that aren't notarized, in the website's
      Install window
- [ ] Make the repo public, then enable **Private vulnerability reporting**
      (Settings › Code security) so SECURITY.md's link works
- [x] Release workflow (`.github/workflows/release.yml`): on each `v*` tag, builds
      a universal app signed with the Emmental Dev identity (from the
      `SIGNING_P12` secrets) and attaches `Emmental.zip` to a GitHub release
- [x] First release: v0.1.0, built and signed by the workflow
- [x] `make bump VERSION=x.y.z` sets the version in the app, `version.json` and the
      page; the workflow refuses a tag that doesn't match the app's version
- [ ] CHANGELOG.md, starting with the first release
- [ ] README: screenshots of the menu and the Settings window, plus the "Open
      Anyway" steps
- [ ] Website or GitHub link in the Settings window
- [ ] Compatibility list in the README, built from mouse reports
- [ ] Homebrew cask: `brew install --cask emmental`
- [ ] Optional: Apple Developer ID and notarization, so downloads open without
      the "Open Anyway" step

## Installing

- [x] Only one copy runs: a starting copy quits any other
- [x] "Move to Applications?" on first launch from anywhere else (Downloads,
      App Translocation), so open at login points at a stable path
- [x] Uninstall steps in the README and the website's FAQ
- [x] Move prompt tested with a real v0.2.2 download on an Apple silicon Mac
- [x] **Install Update** in Settings: downloads the release zip, checks it's signed
      by the same developer and is the announced version, swaps the app (old copy to
      the Trash) and relaunches, so updates skip the Open Anyway step. Manual only.
      Tested with genuine, impostor, wrong-version and missing downloads
- [ ] Install Update tested end to end with a real release (first from 0.2.3 on)

## After updating Xcode

- [ ] Switch open at login to `SMAppService` (macOS 13 SDK) instead of writing a
      LaunchAgent plist
- [ ] Fix anything the newer Swift compiler flags
