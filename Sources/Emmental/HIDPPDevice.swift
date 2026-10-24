import Foundation
import IOKit.hid

/// A HID++ 2.0 connection to a Logitech mouse over Bluetooth, through its vendor
/// channel (usage page 0xFF43). Every message is a 20-byte long report: report
/// ID, device index, feature index, function and software ID packed into one
/// byte, then 16 parameter bytes. Responses arrive asynchronously on the main
/// run loop and are matched back to requests by feature and function.
final class HIDPPDevice {
    typealias Response = [UInt8]

    private static let reportID: UInt8 = 0x11
    private static let reportLength = 20
    private static let directDevice: UInt8 = 0xFF  // Bluetooth; receivers use 1–6
    private static let softwareID: UInt8 = 0x0A
    private static let errorFeature: UInt8 = 0xFF

    let device: IOHIDDevice
    private let inputBuffer: UnsafeMutablePointer<UInt8>
    private var pending: [UInt16: [Request]] = [:]
    private var featureIndexes: [UInt16: UInt8] = [:]

    private final class Request {
        let completion: (Response?) -> Void
        init(_ completion: @escaping (Response?) -> Void) { self.completion = completion }
    }

    static func supportsHIDPP(_ device: IOHIDDevice) -> Bool {
        let pairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Int]] ?? []
        return pairs.contains { $0[kIOHIDDeviceUsagePageKey] == 0xFF43 && $0[kIOHIDDeviceUsageKey] == 0x0202 }
    }

    /// Fails when macOS refuses to open the device, which it does until the app
    /// has Input Monitoring permission.
    init?(device: IOHIDDevice) {
        // Open before initializing anything, so a failure never reaches deinit.
        guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return nil }
        self.device = device
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

    /// Looks up where the device keeps a feature (root feature, function 0).
    /// Calls back with nil when the device doesn't support it.
    func featureIndex(of feature: UInt16, completion: @escaping (UInt8?) -> Void) {
        if let index = featureIndexes[feature] { return completion(index) }
        send(feature: 0, function: 0, params: [UInt8(feature >> 8), UInt8(feature & 0xFF)]) { [weak self] response in
            guard let index = response?.first, index != 0 else { return completion(nil) }
            self?.featureIndexes[feature] = index
            completion(index)
        }
    }

    /// Sends a request; `completion` gets the 16 parameter bytes of the reply, or
    /// nil on a HID++ error or after a 2 second timeout.
    func send(feature: UInt8, function: UInt8, params: [UInt8] = [], completion: ((Response?) -> Void)? = nil) {
        var report = [UInt8](repeating: 0, count: Self.reportLength)
        report[0] = Self.reportID
        report[1] = Self.directDevice
        report[2] = feature
        report[3] = function << 4 | Self.softwareID
        report.replaceSubrange(4..<(4 + params.count), with: params)

        let key = UInt16(feature) << 8 | UInt16(report[3])
        let request = Request(completion ?? { _ in })
        pending[key, default: []].append(request)

        let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(Self.reportID), report, report.count)
        guard result == kIOReturnSuccess else { return complete(key, nil, matching: request) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.complete(key, nil, matching: request)
        }
    }

    private func handleReport(_ bytes: [UInt8]) {
        guard bytes.count >= Self.reportLength, bytes[0] == Self.reportID else { return }
        if bytes[2] == Self.errorFeature {
            complete(UInt16(bytes[3]) << 8 | UInt16(bytes[4]), nil)
        } else {
            complete(UInt16(bytes[2]) << 8 | UInt16(bytes[3]), Array(bytes[4..<Self.reportLength]))
        }
    }

    /// Resolves the oldest request for `key`, or exactly `request` if given and
    /// still pending. Unsolicited reports (notifications) match nothing.
    private func complete(_ key: UInt16, _ response: Response?, matching request: Request? = nil) {
        guard var queue = pending[key], !queue.isEmpty else { return }
        let index: Int
        if let request = request {
            guard let match = queue.firstIndex(where: { $0 === request }) else { return }
            index = match
        } else {
            index = 0
        }
        let done = queue.remove(at: index)
        pending[key] = queue.isEmpty ? nil : queue
        done.completion(response)
    }
}
