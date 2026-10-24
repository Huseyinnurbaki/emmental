import Foundation
import IOKit

/// Calls `onConnect` whenever a HID device appears, so per-device settings can be
/// reapplied after a mouse reconnects or wakes up over Bluetooth.
final class DeviceWatcher {
    private let port: IONotificationPortRef
    private var iterator: io_iterator_t = 0
    private let onConnect: () -> Void

    init(onConnect: @escaping () -> Void) {
        self.onConnect = onConnect
        port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, .main)

        let callback: IOServiceMatchingCallback = { refcon, iterator in
            let watcher = Unmanaged<DeviceWatcher>.fromOpaque(refcon!).takeUnretainedValue()
            DeviceWatcher.drain(iterator)
            watcher.onConnect()
        }
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching(kIOHIDDeviceKey),
                                         callback, Unmanaged.passUnretained(self).toOpaque(), &iterator)
        // Draining arms the notification; devices already connected are handled at launch.
        DeviceWatcher.drain(iterator)
    }

    deinit {
        IOObjectRelease(iterator)
        IONotificationPortDestroy(port)
    }

    private static func drain(_ iterator: io_iterator_t) {
        var device = IOIteratorNext(iterator)
        while device != 0 {
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }
}
