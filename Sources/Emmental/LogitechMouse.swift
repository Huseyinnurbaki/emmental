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

/// A battery reading from the mouse. macOS doesn't expose Logitech batteries,
/// so this only comes over HID++.
struct Battery {
    let percent: Int
    let isCharging: Bool
}

/// How the scroll wheel switches between ratchet (clicky) and free-spin.
struct SmartShift {
    /// The wheel switches to free-spin on its own when flicked fast enough.
    var autoSwitch: Bool
    /// How fast a flick must be to switch, 1–50; lower switches more easily.
    var threshold: Int

    static let thresholdRange = 1...50
}

/// A Logitech mouse reached over HID++, either directly over Bluetooth or
/// through a receiver: sensor DPI, battery, SmartShift and wheel resolution.
final class LogitechMouse {
    private enum Feature {
        static let unifiedBattery: UInt16 = 0x1004
        static let batteryStatus: UInt16 = 0x1000
        static let adjustableDPI: UInt16 = 0x2201
        static let smartShift: UInt16 = 0x2110
        static let hiResWheel: UInt16 = 0x2121
    }

    /// SmartShift's "never switch on its own" value.
    private static let alwaysRatchet: UInt8 = 0xFF
    /// HIRES_WHEEL mode bits. Bit 0 diverts the wheel to HID++ instead of
    /// macOS, which would stop scrolling, so Emmental always keeps it clear.
    private static let wheelDiverted: UInt8 = 0x01
    private static let wheelHighResolution: UInt8 = 0x02

    let connection: HIDPPDevice
    let deviceIndex: UInt8
    private let dpiWriter = LatestWriter()
    private let smartShiftWriter = LatestWriter()

    init(connection: HIDPPDevice, deviceIndex: UInt8) {
        self.connection = connection
        self.deviceIndex = deviceIndex
    }

    // MARK: DPI

    func readDPI(_ completion: @escaping (_ current: Int, _ range: DPIRange) -> Void) {
        withFeature(Feature.adjustableDPI) { index in
            self.send(index, function: 1, params: [0]) { list in
                let range = list.flatMap(DPIRange.init(sensorList:)) ?? .fallback
                self.send(index, function: 2, params: [0]) { reply in
                    guard let reply = reply else { return }
                    completion(Int(reply[1]) << 8 | Int(reply[2]), range)
                }
            }
        }
    }

    func setDPI(_ dpi: Int) {
        dpiWriter.submit { done in
            self.withFeature(Feature.adjustableDPI, orElse: done) { index in
                self.send(index, function: 3, params: [0, UInt8(dpi >> 8), UInt8(dpi & 0xFF)]) { _ in done() }
            }
        }
    }

    // MARK: Battery

    /// Reads the charge via UNIFIED_BATTERY (0x1004), which newer mice like the
    /// MX Master 3S use, falling back to the older BATTERY_STATUS (0x1000).
    /// Calls back only if the mouse answers.
    func readBattery(_ completion: @escaping (Battery) -> Void) {
        connection.featureIndex(of: Feature.unifiedBattery, on: deviceIndex) { [weak self] index in
            guard let self = self else { return }
            guard let index = index else { return self.readLegacyBattery(completion) }
            // get_status: state of charge %, level flags, charging status, external power.
            self.send(index, function: 1) { reply in
                guard let reply = reply else { return }
                let percent = reply[0] != 0 ? Int(reply[0]) : Self.percent(fromLevel: reply[1])
                completion(Battery(percent: percent, isCharging: reply[2] == 1 || reply[2] == 2))
            }
        }
    }

    private func readLegacyBattery(_ completion: @escaping (Battery) -> Void) {
        withFeature(Feature.batteryStatus) { index in
            // GetBatteryLevelStatus: level %, next level %, status.
            self.send(index, function: 0) { reply in
                guard let reply = reply else { return }
                completion(Battery(percent: Int(reply[0]), isCharging: [1, 2, 4].contains(reply[2])))
            }
        }
    }

    /// Some mice report only a coarse level: 8 full, 4 good, 2 low, 1 critical.
    private static func percent(fromLevel flags: UInt8) -> Int {
        if flags & 8 != 0 { return 100 }
        if flags & 4 != 0 { return 60 }
        if flags & 2 != 0 { return 20 }
        return 5
    }

    // MARK: SmartShift

    /// getRatchetControlMode: wheel mode, auto-disengage threshold (0xFF means
    /// never), and the mouse's default threshold.
    func readSmartShift(_ completion: @escaping (SmartShift) -> Void) {
        withFeature(Feature.smartShift) { index in
            self.send(index, function: 0) { reply in
                guard let reply = reply else { return }
                let autoSwitch = reply[1] != Self.alwaysRatchet
                let threshold = Int(autoSwitch ? reply[1] : reply[2])
                completion(SmartShift(autoSwitch: autoSwitch,
                                      threshold: threshold.clamped(to: SmartShift.thresholdRange)))
            }
        }
    }

    /// setRatchetControlMode leaves the current wheel mode alone (0) and only
    /// changes when the wheel switches by itself.
    func setSmartShift(_ smartShift: SmartShift) {
        let threshold = smartShift.autoSwitch
            ? UInt8(smartShift.threshold.clamped(to: SmartShift.thresholdRange))
            : Self.alwaysRatchet
        smartShiftWriter.submit { done in
            self.withFeature(Feature.smartShift, orElse: done) { index in
                self.send(index, function: 1, params: [0, threshold, 0]) { _ in done() }
            }
        }
    }

    // MARK: High-resolution wheel

    /// Calls back with nil when the mouse has no high-resolution wheel.
    func readHighResolutionScrolling(_ completion: @escaping (Bool?) -> Void) {
        connection.featureIndex(of: Feature.hiResWheel, on: deviceIndex) { [weak self] index in
            guard let self = self, let index = index else { return completion(nil) }
            self.send(index, function: 1) { reply in
                completion(reply.map { $0[0] & Self.wheelHighResolution != 0 })
            }
        }
    }

    func setHighResolutionScrolling(_ enabled: Bool) {
        withFeature(Feature.hiResWheel) { index in
            self.send(index, function: 1) { reply in
                guard let mode = reply?[0] else { return }
                var newMode = mode & ~(Self.wheelDiverted | Self.wheelHighResolution)
                if enabled { newMode |= Self.wheelHighResolution }
                self.send(index, function: 2, params: [newMode])
            }
        }
    }

    // MARK: Diagnostics

    /// The raw reply to one read-only request, as hex, for `--diagnose`.
    func describe(feature: UInt16, function: UInt8, params: [UInt8] = [], _ completion: @escaping (String) -> Void) {
        let read: (UInt8) -> Void = { index in
            self.send(index, function: function, params: params) { reply in
                completion(reply.map { $0.map { String(format: "%02X", $0) }.joined(separator: " ") } ?? "no reply")
            }
        }
        // The root feature is always at index 0, which a lookup reports as "missing".
        if feature == 0 { return read(0) }
        connection.featureIndex(of: feature, on: deviceIndex) { index in
            guard let index = index else { return completion("not supported") }
            read(index)
        }
    }

    // MARK: Plumbing

    private func withFeature(_ feature: UInt16, orElse fallback: (() -> Void)? = nil,
                             _ body: @escaping (UInt8) -> Void) {
        connection.featureIndex(of: feature, on: deviceIndex) { index in
            guard let index = index else { fallback?(); return }
            body(index)
        }
    }

    private func send(_ feature: UInt8, function: UInt8, params: [UInt8] = [],
                      completion: ((HIDPPDevice.Response?) -> Void)? = nil) {
        connection.send(to: deviceIndex, feature: feature, function: function, params: params, completion: completion)
    }
}

/// Slider drags produce many values. This keeps one write in flight at a time
/// and only the latest pending value, so a slow wireless link never backs up.
private final class LatestWriter {
    private var isWriting = false
    private var queued: ((_ done: @escaping () -> Void) -> Void)?

    func submit(_ write: @escaping (_ done: @escaping () -> Void) -> Void) {
        queued = write
        writeNext()
    }

    private func writeNext() {
        guard !isWriting, let write = queued else { return }
        queued = nil
        isWriting = true
        write { [weak self] in
            self?.isWriting = false
            self?.writeNext()
        }
    }
}

/// Keeps a HID++ connection open to each Logitech mouse: directly connected
/// Bluetooth mice, and mice paired to a Bolt or Unifying receiver.
final class LogitechMice {
    private(set) var mice: [LogitechMouse] = []
    /// Called when a mouse appears or a receiver reports one reconnecting, so
    /// saved settings can be applied to it.
    var onMouseAvailable: ((LogitechMouse) -> Void)?

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var connections: [UInt64: HIDPPDevice] = [:]
    /// Receivers address paired devices by index; Bolt and Unifying allow six.
    private static let receiverSlots: [UInt8] = Array(1...6)
    private static let adjustableDPI: UInt16 = 0x2201

    init() {
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x046D] as CFDictionary)
    }

    /// Re-scans connected devices, reusing connections that are still valid.
    /// Mice behind a newly found receiver arrive later via `onMouseAvailable`.
    /// `blocked` is true when a device is present but macOS refused to open
    /// it, which happens until Input Monitoring is granted and the app relaunches.
    @discardableResult
    func refresh() -> (mice: [LogitechMouse], blocked: Bool) {
        var blocked = false
        var seen = Set<UInt64>()

        for device in IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? [] {
            let kind = HIDPPDevice.kind(of: device)
            guard kind.supported else { continue }
            var id: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id)
            seen.insert(id)
            if connections[id] != nil { continue }

            guard let connection = HIDPPDevice(device: device, isReceiver: kind.isReceiver) else {
                blocked = true
                continue
            }
            connections[id] = connection
            if kind.isReceiver {
                connection.onDeviceConnected = { [weak self, weak connection] index in
                    guard let self = self, let connection = connection else { return }
                    self.deviceConnected(at: index, on: connection)
                }
                Self.receiverSlots.forEach { discover(at: $0, on: connection) }
            } else {
                mice.append(LogitechMouse(connection: connection, deviceIndex: HIDPPDevice.directIndex))
            }
        }

        // Drop connections to devices that are gone, and the mice behind them.
        for (id, connection) in connections where !seen.contains(id) {
            connections[id] = nil
            mice.removeAll { $0.connection === connection }
        }
        return (mice, blocked)
    }

    /// A paired device counts as a mouse if it has adjustable DPI, which
    /// keyboards on the same receiver don't. Empty or offline slots just fail.
    private func discover(at index: UInt8, on connection: HIDPPDevice) {
        connection.featureIndex(of: Self.adjustableDPI, on: index) { [weak self] feature in
            guard let self = self, feature != nil,
                  !self.mice.contains(where: { $0.connection === connection && $0.deviceIndex == index }) else { return }
            let mouse = LogitechMouse(connection: connection, deviceIndex: index)
            self.mice.append(mouse)
            self.onMouseAvailable?(mouse)
        }
    }

    /// A mouse waking up behind a receiver keeps the same connection, so the
    /// device watcher never sees it; the receiver's notification is the cue.
    private func deviceConnected(at index: UInt8, on connection: HIDPPDevice) {
        if let mouse = mice.first(where: { $0.connection === connection && $0.deviceIndex == index }) {
            onMouseAvailable?(mouse)
        } else {
            discover(at: index, on: connection)
        }
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

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
