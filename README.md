# 🧀 Emmental

A tiny macOS menu bar app for tuning your mouse, without the weight of vendor
software like Logi Options+. Acceleration and scroll speed work with any
external mouse; the Logitech extras work with Logitech mice that speak HID++.

Built and tested on an MX Master 3S. Emmental doesn't check the model: it asks
the mouse which HID++ features it has (DPI, SmartShift, battery) and shows the
ones it finds, so other recent Logitech mice like the MX Master 3, newer MX
Masters and MX Anywhere 3 / 3S should work too. They're untested so far, so
[reports are welcome](https://github.com/Huseyinnurbaki/emmental/issues).

**In the menu**, for things you change often:

- **Speed**: the sensor DPI on Logitech mice (200–8000 on the MX Master 3S)
- **Acceleration**: how much fast movements get boosted, per mouse, past the
  System Settings maximum if you like
- **Scroll speed** per mouse
- **Battery level** next to the mouse name on Logitech mice

**In Settings** (⌘, from the menu), for set-and-forget options:

- **SmartShift**: whether the wheel switches to free-spin by itself when you
  flick it, and how hard a flick it takes
- **High-resolution scrolling** (experimental)
- **Open at login**

Also:

- Logitech mice over **Bluetooth or a Bolt / Unifying receiver**
- Lives in the menu bar, no Dock icon, no background services, no updater
- A 1.4 MB app using under 25 MB of memory (about 9 MB on Intel, 23 MB on an M1)
- Uses public IOKit APIs only. Acceleration and scroll speed need no
  permissions; the Logitech features are opt-in and need Input Monitoring

## Build and run

Requires Xcode command line tools (Swift 5.6+) and macOS 12 or later.

`make` builds for the Mac you're on. Emmental is developed and tested on an
Intel Mac, so far; testing on Apple silicon is on the [roadmap](ROADMAP.md).

```bash
make release   # universal (Intel + Apple silicon), signed: build/release/Emmental.zip
```

Releases are built by GitHub Actions. To publish one:

```bash
make bump VERSION=0.2.0   # app, website and version.json all say 0.2.0
git commit -am "Release 0.2.0" && git push
git tag -a v0.2.0 -m "Emmental 0.2.0" && git push origin v0.2.0
```

The tag runs `.github/workflows/release.yml`, which builds the universal zip and
attaches it to a GitHub release. The website's Download button always points at
the latest, and **Check for Updates** in the app reads the website's
`version.json`. The workflow stops if the tag doesn't match the app's version.

```bash
make run       # build build/Emmental.app and launch it
make install   # copy it to /Applications
make icon      # regenerate Resources/AppIcon.icns after changing the wedge
```

### Signing (recommended if you use DPI)

Without a certificate, builds are signed ad hoc, and macOS treats every rebuild
as a new app: DPI's Input Monitoring permission stops working and you have to
remove and re-add Emmental in System Settings. Create a free self-signed
identity once and the permission sticks:

```bash
scripts/create-signing-cert.sh
```

It adds an "Emmental Dev" code signing certificate to your login keychain and
asks for your password to trust it. After that, `make` signs with it
automatically (or pass `SIGN_IDENTITY="Your Cert"`). Grant Input Monitoring
once more after the first signed build. Pointer and scroll speed work either
way.

## How it works

macOS keeps pointer and scroll acceleration values (`HIDMouseAcceleration`,
`HIDMouseScrollAcceleration`) on each HID device. System Settings writes the
same values to every mouse and caps pointer speed at 3.0. Emmental writes them
to external mice only, through `IOHIDEventSystemClient`, and allows pointer
speeds up to 8.0.

macOS resets these values when a mouse reconnects, so Emmental reapplies your
speeds when a device appears and when the Mac wakes. A slider you haven't
moved changes nothing.

### Logitech features (DPI, battery, scroll wheel)

These live on the mouse itself, not in macOS. Emmental talks to the mouse with
Logitech's HID++ 2.0 protocol over its vendor HID channel:

| Feature | HID++ feature |
|---|---|
| Sensor DPI | `0x2201` ADJUSTABLE_DPI |
| Battery | `0x1004` UNIFIED_BATTERY, or `0x1000` BATTERY_STATUS |
| SmartShift | `0x2110` SMART_SHIFT |
| High-resolution scrolling | `0x2121` HIRES_WHEEL |

macOS only lets apps open that channel with Input Monitoring permission, so
these are off until you turn them on in the menu. Settings you haven't changed
are left as the mouse has them, and changed ones are reapplied when the mouse
reconnects.

Mice connect directly over Bluetooth (device index `0xFF`) or through a Bolt or
Unifying receiver (paired devices 1–6; anything with adjustable DPI counts as a
mouse). Receiver support is untested on real hardware so far.

High-resolution scrolling makes the wheel send 15 finer steps per notch on the
MX Master 3S. macOS may not scale those back down, so it's marked experimental.

To see what Emmental reads from your mouse, without changing anything:

```bash
open -n /Applications/Emmental.app --args --diagnose ~/emmental-diagnose.txt
```

If DPI asks for permission again after a rebuild, see [Signing](#signing-recommended-if-you-use-dpi).

### Open at login

Turning it on writes `~/Library/LaunchAgents/app.emmental.Emmental.plist`,
which starts Emmental when you log in; turning it off deletes the file.
Emmental rewrites the file on each launch, so it always points at the copy
you're running. Install to `/Applications` first (`make install`) so it
doesn't point into `build/`.

## Install and uninstall

Download from [emmental.artichoke.monster](https://emmental.artichoke.monster/).
Emmental isn't notarized by Apple yet, so the first launch of each downloaded
version is blocked: open **System Settings › Privacy & Security** and click
**Open Anyway**. It then offers to move itself into Applications, which open
at login needs. Input Monitoring, for the Logitech features, is granted once and
carries over to new versions.

To uninstall, turn off **Open at login** in Settings (⌘,), choose **Quit
Emmental**, and drag the app to the Trash. If you already deleted it, this
removes what's left (the login item, preferences, and the Input Monitoring entry):

```bash
rm -f ~/Library/LaunchAgents/app.emmental.Emmental.plist; defaults delete app.emmental.Emmental; tccutil reset ListenEvent app.emmental.Emmental
```

Mouse settings go back to the macOS defaults the next time the mouse reconnects
or the Mac restarts.

## Roadmap

See [ROADMAP.md](ROADMAP.md).

## Contributing

Mouse reports, bug reports and pull requests are welcome; see
[CONTRIBUTING.md](CONTRIBUTING.md). Please report security issues privately, as
described in [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
