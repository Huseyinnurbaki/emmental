# Emmental

A tiny macOS menu bar app for tuning your mouse, without the weight of vendor
software like Logi Options+. Built for the Logitech MX Master 3S; works with any
external mouse.

- **Pointer speed** per mouse, including speeds past the System Settings maximum
- **Scroll speed** per mouse
- **Sensor DPI** on Logitech mice over Bluetooth (200–8000 on the MX Master 3S)
- Lives in the menu bar, no Dock icon, no background services, no updater
- About 8 MB of memory
- Uses public IOKit APIs only. Pointer and scroll speed need no permissions;
  DPI is opt-in and needs Input Monitoring

## Build and run

Requires Xcode command line tools (Swift 5.6+) and macOS 12 or later.

```bash
make run       # build build/Emmental.app and launch it
make install   # copy it to /Applications
```

## How it works

macOS keeps pointer and scroll acceleration values (`HIDMouseAcceleration`,
`HIDMouseScrollAcceleration`) on each HID device. System Settings writes the
same values to every mouse and caps pointer speed at 3.0. Emmental writes them
to external mice only, through `IOHIDEventSystemClient`, and allows pointer
speeds up to 8.0.

macOS resets these values when a mouse reconnects, so Emmental reapplies your
speeds when a device appears and when the Mac wakes. A slider you haven't
moved changes nothing.

### DPI

DPI is a setting on the mouse itself, not in macOS. Emmental sets it with
Logitech's HID++ 2.0 protocol (feature `0x2201`, ADJUSTABLE_DPI) over the
mouse's vendor HID channel. macOS only lets apps open that channel with Input
Monitoring permission, so DPI control is off until you turn it on in the menu.
Emmental only sends HID++ requests to read and set DPI.

Only Bluetooth connections are supported for now. Mice on a Bolt or Unifying
receiver use a different addressing scheme.

While developing: the app is ad-hoc signed, so macOS may treat each rebuild as
a new app and drop its Input Monitoring permission. Toggle it off and on in
System Settings after rebuilding.

## Roadmap

- SmartShift and high-resolution scrolling on Logitech mice via HID++
- Bolt receiver support
- Launch at login
