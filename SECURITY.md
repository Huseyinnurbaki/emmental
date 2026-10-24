# Security Policy

## Supported Versions

Security fixes go into the latest release. Please update before reporting.

| Version | Supported |
| ------- | --------- |
| 0.1.x   | ✅        |

## Reporting a Vulnerability

**Please don't open a public issue for security problems.**

Report them privately through
[GitHub](https://github.com/Huseyinnurbaki/emmental/security/advisories/new)
(repo → **Security** → **Advisories** → *Report a vulnerability*), and keep the
details confidential while it's being fixed.

Please include:

- What the problem is and what it could let someone do
- Steps to reproduce it, ideally with a minimal proof of concept
- The Emmental and macOS versions affected

You can expect an acknowledgement within a few days, updates while it's being
fixed, and credit in the advisory if you'd like.

## What Emmental can access

Emmental runs on your Mac with your user's permissions. This is what it touches,
so you can judge reports, and the app, against it.

- **Acceleration and scroll speed** use the public `IOHIDEventSystemClient` API to
  set two values on external mice. No permission is needed.
- **The Logitech features (DPI, battery, SmartShift) are optional** and off until
  you turn them on. They need **Input Monitoring**, because macOS requires it to
  open a HID device directly. Emmental only opens Logitech devices with a HID++
  vendor channel (usage page `0xFF43` over Bluetooth, `0xFF00` on receivers) and
  only sends HID++ settings requests. macOS delivers every report the opened
  device sends, including ordinary mouse movement; Emmental only processes
  HID++ replies (report IDs `0x10` and `0x11`) and drops everything else without
  storing it. It doesn't open keyboards or any other devices.
- **No network access.** Emmental makes no network connections: no analytics,
  no crash reporting, no updater.
- **Open at login** writes one file, `~/Library/LaunchAgents/app.emmental.Emmental.plist`,
  and deletes it when you turn the setting off.
- **Settings** are stored in Emmental's own preferences (`app.emmental.Emmental`).

Anything that makes Emmental read input it doesn't need, touch devices other
than the ones above, reach the network, or run code it shouldn't is in scope.
