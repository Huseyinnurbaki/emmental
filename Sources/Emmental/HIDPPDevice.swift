import Foundation
import IOKit.hid
import os

private let log = Logger(subsystem: "app.emmental.Emmental", category: "HID++")

/// A HID++ 2.0 connection over a Logitech vendor channel: either a mouse
/// connected directly over Bluetooth (usage page 0xFF43), or a Bolt / Unifying
/// receiver (usage page 0xFF00) that relays to up to six paired devices.
///
/// Requests are 20-byte long reports: report ID, device index, feature index,
/// function and software ID packed into one byte, then 16 parameter bytes.
/// Responses arrive asynchronously on the main run loop and are matched back to
/// requests by device index, feature, function and software ID. The software
/// ID rotates per request, so a dropped reply can't shift later replies onto
/// the wrong requests. Mice do drop replies, especially right after waking, so
/// requests that time out are retried.
final class HIDPPDevice {
    typealias Response = [UInt8]

    /// Device index of a mouse connected directly; receivers address paired devices 1–6.
    static let directIndex: UInt8 = 0xFF

    private static let shortReportID: UInt8 = 0x10
    private static let longReportID: UInt8 = 0x11
    private static let shortReportLength = 7
    private static let longReportLength = 20
    private static let timeout: TimeInterval = 1.5
    private static let errorFeature: UInt8 = 0xFF      // HID++ 2.0 error reply
    private static let legacyError: UInt8 = 0x8F       // HID++ 1.0 error, e.g. device offline
    private static let connectionNotice: UInt8 = 0x41  // receiver: a paired device (dis)connected

    let device: IOHIDDevice
    let isReceiver: Bool
    /// Called with a device index when a receiver reports that device coming online.
    var onDeviceConnected: ((UInt8) -> Void)?

    private let inputBuffer: UnsafeMutablePointer<UInt8>
    private var pending: [UInt32: [Request]] = [:]
    private var featureIndexes: [UInt32: UInt8] = [:]
    /// 1–15; 0 is reserved for notifications the device sends on its own.
    private var lastSoftwareID: UInt8 = 0

    private final class Request {
        let completion: (Response?) -> Void
        init(_ completion: @escaping (Response?) -> Void) { self.completion = completion }
    }

    /// Whether `device` speaks HID++: a direct Bluetooth mouse or a receiver.
    static func kind(of device: IOHIDDevice) -> (supported: Bool, isReceiver: Bool) {
        let pairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Int]] ?? []
        func has(_ page: Int, _ usage: Int) -> Bool {
            pairs.contains { $0[kIOHIDDeviceUsagePageKey] == page && $0[kIOHIDDeviceUsageKey] == usage }
        }
        if has(0xFF43, 0x0202) { return (true, false) }
        if has(0xFF00, 0x0002) { return (true, true) }
        return (false, false)
    }

    /// Fails when macOS refuses to open the device, which it does until the app
    /// has Input Monitoring permission.
    init?(device: IOHIDDevice, isReceiver: Bool) {
        // Open before initializing anything, so a failure never reaches deinit.
        guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return nil }
        self.device = device
        self.isReceiver = isReceiver
        inputBuffer = .allocate(capacity: 64)
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, 64, { context, _, _, _, _, report, length in
            let this = Unmanaged<HIDPPDevice>.fromOpaque(context!).takeUnretainedValue()
            this.handleReport(Array(UnsafeBufferPointer(start: report, count: length)))
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    }

    deinit {
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, 64, nil, nil)
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        inputBuffer.deallocate()
    }

    /// Looks up where a device keeps a feature (root feature, function 0).
    /// Calls back with nil when the device doesn't support it or doesn't answer.
    func featureIndex(of feature: UInt16, on deviceIndex: UInt8, completion: @escaping (UInt8?) -> Void) {
        let cacheKey = UInt32(deviceIndex) << 16 | UInt32(feature)
        if let index = featureIndexes[cacheKey] { return completion(index) }
        send(to: deviceIndex, feature: 0, function: 0, params: [UInt8(feature >> 8), UInt8(feature & 0xFF)]) { [weak self] response in
            guard let index = response?.first, index != 0 else { return completion(nil) }
            self?.featureIndexes[cacheKey] = index
            completion(index)
        }
    }

    /// Sends a request; `completion` gets the 16 parameter bytes of the reply, or
    /// nil on a HID++ error. A request that gets no reply is sent again up to
    /// `retries` times before completing with nil.
    func send(to deviceIndex: UInt8, feature: UInt8, function: UInt8, params: [UInt8] = [],
              retries: Int = 2, completion: ((Response?) -> Void)? = nil) {
        lastSoftwareID = lastSoftwareID % 15 + 1
        var report = [UInt8](repeating: 0, count: Self.longReportLength)
        report[0] = Self.longReportID
        report[1] = deviceIndex
        report[2] = feature
        report[3] = function << 4 | lastSoftwareID
        report.replaceSubrange(4..<(4 + params.count), with: params)

        let key = Self.key(deviceIndex, feature, report[3])
        let request = Request(completion ?? { _ in })
        pending[key, default: []].append(request)

        let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(Self.longReportID), report, report.count)
        let wait = result == kIOReturnSuccess ? Self.timeout : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            // Still pending means no reply came (or the write itself failed).
            guard let self = self, self.remove(request, for: key) else { return }
            if retries > 0 {
                self.send(to: deviceIndex, feature: feature, function: function, params: params,
                          retries: retries - 1, completion: request.completion)
            } else {
                log.error("No reply from device \(deviceIndex) to feature \(feature) function \(function)")
                request.completion(nil)
            }
        }
    }

    private static func key(_ deviceIndex: UInt8, _ feature: UInt8, _ functionByte: UInt8) -> UInt32 {
        UInt32(deviceIndex) << 16 | UInt32(feature) << 8 | UInt32(functionByte)
    }

    private func handleReport(_ bytes: [UInt8]) {
        guard bytes.count >= Self.shortReportLength else { return }
        let deviceIndex = bytes[1]
        switch bytes[0] {
        case Self.longReportID where bytes.count >= Self.longReportLength:
            if bytes[2] == Self.errorFeature {
                complete(Self.key(deviceIndex, bytes[3], bytes[4]), nil)
            } else {
                complete(Self.key(deviceIndex, bytes[2], bytes[3]), Array(bytes[4..<Self.longReportLength]))
            }
        case Self.shortReportID:
            if bytes[2] == Self.legacyError {
                complete(Self.key(deviceIndex, bytes[3], bytes[4]), nil)
            } else if bytes[2] == Self.connectionNotice, bytes[4] & 0x40 == 0 {
                // Bit 6 set means the link went down; clear means the device is back.
                onDeviceConnected?(deviceIndex)
            }
        default:
            break
        }
    }

    /// Resolves the oldest request for `key` with a reply (or nil for a HID++
    /// error). Unsolicited reports (notifications) match nothing.
    private func complete(_ key: UInt32, _ response: Response?) {
        guard var queue = pending[key], !queue.isEmpty else { return }
        let done = queue.removeFirst()
        pending[key] = queue.isEmpty ? nil : queue
        done.completion(response)
    }

    /// Removes `request` if it's still waiting; false if it was already answered.
    private func remove(_ request: Request, for key: UInt32) -> Bool {
        guard var queue = pending[key], let index = queue.firstIndex(where: { $0 === request }) else { return false }
        queue.remove(at: index)
        pending[key] = queue.isEmpty ? nil : queue
        return true
    }
}
