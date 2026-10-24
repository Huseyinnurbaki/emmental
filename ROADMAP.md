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

- [ ] Universal release build (`swift build --arch arm64 --arch x86_64`) so one
      download runs natively on Intel and Apple silicon. Until then, an Intel
      build runs on Apple silicon through Rosetta, which macOS offers to install
      on first launch.
- [ ] Test on an Apple silicon Mac: acceleration and scroll speed, HID++ (DPI,
      battery, SmartShift), Input Monitoring, open at login and sleep

## Features

- [x] Acceleration past the System Settings maximum (up to 8.0)
- [x] Scroll speed
- [x] Speed: sensor DPI over HID++ (`0x2201`)
- [x] Battery level next to the mouse name (HID++ `0x1004`, falling back to `0x1000`)
- [x] SmartShift (HID++ `0x2110`): auto-switch on or off, and the free-spin threshold
- [x] High-resolution scrolling (HID++ `0x2121`), experimental
- [x] Bolt / Unifying receiver support: device indexes 1–6, discovery by
      adjustable DPI, reapply on the receiver's reconnect notification
- [x] `--diagnose` mode: dumps what Emmental reads over HID++, read-only
- [x] Menu with Speed, Acceleration and Scroll speed; a Settings window (⌘,) for
      SmartShift, high-res scrolling and open at login; app icon
- [ ] Decide on high-resolution scrolling: if macOS doesn't scale the 15× steps
      down, drop it, or scale wheel events ourselves (needs Accessibility)
- [ ] Test receiver support on real hardware
- [ ] **Check for Updates** button in Settings. Reads `version.json` from the
      website and compares it to `CFBundleShortVersionString`; shows "You're up
      to date" or links to the download. Manual only: no background updater, no
      auto-install. Works even while the repo is private.

## Website (emmental.artichoke.monster)

- [x] Landing page in `landing/`: a Mac desktop with the real menu, a cheese
      pointer that shows Speed and Acceleration, windows opened from the Dock,
      a Wi-Fi menu and an easter egg
- [x] SEO and link previews: meta and Open Graph tags, JSON-LD, robots.txt,
      sitemap.xml, llms.txt, `og.png` (`make og`)
- [x] Cloudflare deploy from the repo (`wrangler.jsonc`); pushes to `main` redeploy
- [ ] Add the custom domain `emmental.artichoke.monster` in Cloudflare and check
      the link preview card
- [ ] Make the Download button work: point it at the latest GitHub release's
      `Emmental.zip` (`/releases/latest/download/Emmental.zip`)
- [ ] Pick the wallpaper (cheese moon today, glass waves suggested). If the moon
      goes, move the easter egg.

## Open source

- [x] License: MIT
- [x] CONTRIBUTING.md, SECURITY.md, and issue forms (mouse report, bug, feature)
- [x] "Open Anyway" steps for builds that aren't notarized, in the website's
      Install window
- [ ] Make the repo public, then enable **Private vulnerability reporting**
      (Settings › Code security) so SECURITY.md's link works
- [ ] Release workflow: GitHub Actions builds a universal, zipped `.app` for each
      version tag and attaches it to the release
- [ ] CHANGELOG.md, starting with the first release
- [ ] README: screenshots of the menu and the Settings window, plus the "Open
      Anyway" steps
- [ ] Website or GitHub link in the Settings window
- [ ] Compatibility list in the README, built from mouse reports
- [ ] Homebrew cask: `brew install --cask emmental`
- [ ] Optional: Apple Developer ID and notarization, so downloads open without
      the "Open Anyway" step

## After updating Xcode

- [ ] Switch open at login to `SMAppService` (macOS 13 SDK) instead of writing a
      LaunchAgent plist
- [ ] Fix anything the newer Swift compiler flags
