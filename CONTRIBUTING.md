# Contributing to Emmental

Thanks for helping. Emmental stays small on purpose: a few mouse settings people
actually use, nothing running in the background, no network access beyond the
manual update check. Changes that
keep it that way are the easiest to merge.

## Reporting how your mouse works

The most useful contribution needs no code: a
[mouse report](https://github.com/Huseyinnurbaki/emmental/issues/new?template=mouse_report.yml)
for any mouse other than the MX Master 3S. Successes count as much as problems.

## Building

You need Xcode command line tools (Swift 5.6+) and macOS 12 or later.

```bash
scripts/create-signing-cert.sh   # once: a local signing identity
make install                     # build, sign, copy to /Applications
open /Applications/Emmental.app
```

Run the signing script before your first build. Without a stable signing
identity, macOS treats every rebuild as a new app and drops its Input Monitoring
permission, so the Logitech features stop working until you grant it again.

Other targets: `make run` builds and launches from `build/`, `make icon`
regenerates the app icon, `make og` re-renders the landing page's preview card.

## Where things are

| Path | What |
|---|---|
| `Sources/Emmental/MouseSpeed.swift` | Acceleration and scroll speed, through `IOHIDEventSystemClient` |
| `Sources/Emmental/HIDPPDevice.swift` | HID++ 2.0 transport: reports, request matching, retries |
| `Sources/Emmental/LogitechMouse.swift` | DPI, battery, SmartShift, hi-res wheel; finding mice and receivers |
| `Sources/Emmental/AppDelegate.swift` | Menu, settings window, reapplying after wake and reconnect |
| `Sources/Emmental/Diagnostics.swift` | The read-only `--diagnose` mode |
| `landing/` | The website, a single static page deployed by Cloudflare |

## Debugging

Emmental logs waking, reconnecting, reapplying and failed requests:

```bash
/usr/bin/log show --last 30m --predicate 'subsystem == "app.emmental.Emmental"' --style compact
```

Use `/usr/bin/log`: zsh has its own built-in `log` command that shadows it.

To see what Emmental reads from a Logitech mouse, without changing anything:

```bash
open -n /Applications/Emmental.app --args --diagnose ~/emmental-diagnose.txt; cat ~/emmental-diagnose.txt
```

## Working with the mouse protocol

When adding a HID++ feature:

- **Read before you write.** Add the feature's read to `--diagnose` first and
  check the real values on a real mouse before sending any set request.
- **Look features up, never assume them.** Feature indexes differ between models
  and firmware; ask the root feature for the index every time (it's cached).
- **Leave unchanged settings alone.** A setting the user hasn't touched stays as
  the mouse has it. Only saved values are applied.
- **Never divert input away from macOS.** For example, HIRES_WHEEL's divert bit
  would stop the wheel from scrolling, so Emmental always keeps it clear.

## Pull requests

- Keep changes focused, and match the style of the surrounding code.
- Say what you tested it on: the mouse, the connection and the Mac.
- New features should stay optional and leave the system untouched until used.
