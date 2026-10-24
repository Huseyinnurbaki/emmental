import Foundation
import IOKit.hid
import IOKit.hidsystem

/// A connected external mouse, as seen by the HID event system.
struct Mouse {
    let service: IOHIDServiceClient
    let name: String
}

/// A speed macOS keeps on each mouse's HID service.
enum SpeedControl: CaseIterable {
    case pointer, scroll

    var title: String {
        switch self {
        case .pointer: return "Pointer speed"
        case .scroll: return "Scroll speed"
        }
    }

    /// The pointer range reaches past the System Settings cap; the HID event
    /// system accepts the higher values.
    var range: ClosedRange<Double> {
        switch self {
        case .pointer: return 0...8
        case .scroll: return 0...5
        }
    }

    fileprivate var hidKey: String {
        switch self {
        case .pointer: return kIOHIDMouseAccelerationType
        case .scroll: return kIOHIDMouseScrollAccelerationKey
        }
    }
}

/// Reads and writes speeds on individual mice through the public
/// IOHIDEventSystemClient API. Changes apply to that device only and need no
/// special permissions; macOS resets them when the device reconnects.
enum MouseSpeed {
    /// Where System Settings › Mouse › Tracking speed tops out.
    static let systemPointerMaximum = 3.0

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
    static func value(of control: SpeedControl, on mouse: Mouse) -> Double? {
        intProperty(mouse.service, control.hidKey).map { Double($0) / 65536 }
    }

    static func set(_ value: Double, for control: SpeedControl, on mouse: Mouse) {
        IOHIDServiceClientSetProperty(mouse.service, control.hidKey as CFString, Int(value * 65536) as CFNumber)
    }

    private static func intProperty(_ service: IOHIDServiceClient, _ key: String) -> Int? {
        IOHIDServiceClientCopyProperty(service, key as CFString) as? Int
    }
}
