import Foundation
import IOKit.hid
import IOKit.hidsystem

/// A connected external mouse, as seen by the HID event system.
struct Mouse {
    let service: IOHIDServiceClient
    let name: String
}

/// Reads and writes pointer speed on individual mice through the public
/// IOHIDEventSystemClient API. Changes apply to that device only and need no
/// special permissions; macOS resets them when the device reconnects.
enum MouseSpeed {
    /// System Settings › Mouse › Tracking speed stops at 3.0, but the HID event
    /// system accepts higher values, which is where the extra speed comes from.
    static let systemMaximum = 3.0
    static let range = 0.0...8.0

    private static let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)

    static func connectedMice() -> [Mouse] {
        let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] ?? []
        return services.compactMap { service in
            guard intProperty(service, kIOHIDPrimaryUsagePageKey) == kHIDPage_GenericDesktop,
                  intProperty(service, kIOHIDPrimaryUsageKey) == kHIDUsage_GD_Mouse,
                  intProperty(service, kIOHIDBuiltInKey) != 1 else { return nil }
            let name = IOHIDServiceClientCopyProperty(service, kIOHIDProductKey as CFString) as? String
            return Mouse(service: service, name: name ?? "Mouse")
        }
    }

    // HID numeric properties are 16.16 fixed point.
    static func speed(of mouse: Mouse) -> Double? {
        intProperty(mouse.service, kIOHIDMouseAccelerationType).map { Double($0) / 65536 }
    }

    static func setSpeed(_ speed: Double, on mouse: Mouse) {
        IOHIDServiceClientSetProperty(mouse.service, kIOHIDMouseAccelerationType as CFString,
                                      Int(speed * 65536) as CFNumber)
    }

    private static func intProperty(_ service: IOHIDServiceClient, _ key: String) -> Int? {
        IOHIDServiceClientCopyProperty(service, key as CFString) as? Int
    }
}
