# Emmental

A tiny macOS menu bar app for tuning your mouse, without the weight of vendor
software like Logi Options+. Built for the Logitech MX Master 3S; works with any
external mouse.

- **Pointer speed** per mouse, including speeds past the System Settings maximum
- Lives in the menu bar, no Dock icon, no background services, no updater
- About 8 MB of memory
- Uses public IOKit APIs only, so it needs no special permissions

## Build and run

Requires Xcode command line tools (Swift 5.6+) and macOS 12 or later.

```bash
make run       # build build/Emmental.app and launch it
make install   # copy it to /Applications
```

## How it works

macOS keeps a pointer acceleration value on each HID device. System Settings
writes the same value to every mouse and caps it at 3.0. Emmental writes it to
external mice only, through `IOHIDEventSystemClient`, and allows values up to 8.0.

macOS resets the value when a mouse reconnects, so Emmental reapplies your
speed when a device appears and when the Mac wakes. Until you move the slider,
Emmental changes nothing.

## Roadmap

- Scroll speed
- Real DPI and SmartShift on Logitech mice via HID++
- Launch at login
