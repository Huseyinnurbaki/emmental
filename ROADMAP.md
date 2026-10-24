# Roadmap

What's next for Emmental, roughly in order.

## Day-to-day reliability

- [x] Create a signing identity (`scripts/create-signing-cert.sh`), `make install`,
      and grant Input Monitoring one last time, so DPI and battery survive rebuilds
- [ ] Restart and confirm Emmental opens at login with saved settings applied
- [ ] Live with it for a few days; with DPI around 1900, try pointer speed 2–3

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
- [ ] **Check for updates**: a "Check for Updates" button in the About window that
      asks GitHub Releases (`/repos/Huseyinnurbaki/emmental/releases/latest`) for
      the newest tag and compares it to `CFBundleShortVersionString`. Shows
      "You're up to date" or links to the download. Manual by default, no
      background updater and no auto-install, which is the point of Emmental.
      Needs the repo to be public.

## Open source

- [ ] Pick a license (MIT is the usual choice for small utilities)
- [ ] README polish: screenshots of the menu and the About window, and a short
      "why" (vendor apps are heavy; Emmental is about 8 MB)
- [ ] GitHub link in the About window
- [ ] Release workflow: GitHub Actions builds a zipped `.app` for each version tag
- [ ] Document the "unidentified developer" workaround for downloaded builds
      (right-click › Open, or `xattr -dr com.apple.quarantine`), or sign and
      notarize with an Apple Developer ID
- [ ] Homebrew cask: `brew install --cask emmental`
