import AppKit
import IOKit.hid

/// The DPI values a sensor accepts, from HID++ ADJUSTABLE_DPI's sensor list.
struct DPIRange {
    let min: Int
    let max: Int
    let step: Int

    static let fallback = DPIRange(min: 200, max: 8000, step: 50)

    /// The list is big-endian 16-bit values after the sensor index, ending at 0.
    /// A value with the top three bits set is a step size between its neighbours.
    init?(sensorList: [UInt8]) {
        var values: [Int] = []
        var step = 50
        var i = 1
        while i + 1 < sensorList.count {
            let value = Int(sensorList[i]) << 8 | Int(sensorList[i + 1])
            if value == 0 { break }
            if value & 0xE000 == 0xE000 { step = value & 0x1FFF } else { values.append(value) }
            i += 2
        }
        guard let first = values.first, let last = values.last, first < last else { return nil }
        self.init(min: first, max: last, step: step)
    }

    init(min: Int, max: Int, step: Int) {
        self.min = min
        self.max = max
        self.step = step
    }
}

/// A Logitech mouse whose sensor DPI can be read and set over HID++
/// (feature 0x2201, ADJUSTABLE_DPI, sensor 0).
final class LogitechMouse {
    private static let adjustableDPI: UInt16 = 0x2201

    let registryID: UInt64
    private let hidpp: HIDPPDevice
    private var isWriting = false
    private var queuedDPI: Int?

    init(hidpp: HIDPPDevice, registryID: UInt64) {
        self.hidpp = hidpp
        self.registryID = registryID
    }

    func readDPI(_ completion: @escaping (_ current: Int, _ range: DPIRange) -> Void) {
        hidpp.featureIndex(of: Self.adjustableDPI) { [weak self] index in
            guard let self = self, let index = index else { return }
            self.hidpp.send(feature: index, function: 1, params: [0]) { list in
                let range = list.flatMap(DPIRange.init(sensorList:)) ?? .fallback
                self.hidpp.send(feature: index, function: 2, params: [0]) { reply in
                    guard let reply = reply else { return }
                    completion(Int(reply[1]) << 8 | Int(reply[2]), range)
                }
            }
        }
    }

    /// Slider drags produce many values; only one write is in flight at a time
    /// and the latest value wins, so a slow Bluetooth link never backs up.
    func setDPI(_ dpi: Int) {
        queuedDPI = dpi
        writeQueuedDPI()
    }

    private func writeQueuedDPI() {
        guard !isWriting, let dpi = queuedDPI else { return }
        queuedDPI = nil
        isWriting = true
        hidpp.featureIndex(of: Self.adjustableDPI) { [weak self] index in
            guard let self = self else { return }
            guard let index = index else { self.isWriting = false; return }
            self.hidpp.send(feature: index, function: 3, params: [0, UInt8(dpi >> 8), UInt8(dpi & 0xFF)]) { _ in
                self.isWriting = false
                self.writeQueuedDPI()
            }
        }
    }
}

/// Keeps a HID++ connection open to each connected Logitech mouse that has one.
final class LogitechMice {
    private(set) var mice: [LogitechMouse] = []
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    init() {
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x046D] as CFDictionary)
    }

    /// Re-scans connected devices, reusing connections that are still valid.
    /// `blocked` is true when a mouse is present but macOS refused to open it,
    /// which happens until Input Monitoring is granted and the app relaunches.
    @discardableResult
    func refresh() -> (mice: [LogitechMouse], blocked: Bool) {
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []).filter(HIDPPDevice.supportsHIDPP)
        var blocked = false
        mice = devices.compactMap { device in
            var id: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id)
            if let existing = mice.first(where: { $0.registryID == id }) { return existing }
            guard let hidpp = HIDPPDevice(device: device) else {
                blocked = true
                return nil
            }
            return LogitechMouse(hidpp: hidpp, registryID: id)
        }
        return (mice, blocked)
    }
}

/// macOS gates direct HID access, which HID++ needs, behind Input Monitoring.
enum InputMonitoring {
    static var isGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Shows the system prompt the first time and adds Emmental to the list in
    /// System Settings; later calls do nothing visible.
    static func request() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
}
