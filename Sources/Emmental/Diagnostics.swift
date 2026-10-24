import Foundation

/// `Emmental --diagnose <file>` writes what Emmental can see over HID++ to a
/// file and exits. It only sends read requests, so nothing on the mouse changes.
/// Launch it through `open` so macOS applies Emmental's own Input Monitoring
/// permission:
///
///     open -n /Applications/Emmental.app --args --diagnose ~/emmental-diagnose.txt
enum Diagnostics {
    private static let reads: [(name: String, feature: UInt16, function: UInt8, params: [UInt8])] = [
        ("protocol version (root)", 0x0000, 1, [0, 0, 0x5A]),
        ("battery, unified (0x1004 get_status)", 0x1004, 1, []),
        ("battery, legacy (0x1000)", 0x1000, 0, []),
        ("DPI sensor list (0x2201)", 0x2201, 1, [0]),
        ("DPI current (0x2201)", 0x2201, 2, [0]),
        ("SmartShift (0x2110 get mode)", 0x2110, 0, []),
        ("hi-res wheel capability (0x2121)", 0x2121, 0, []),
        ("hi-res wheel mode (0x2121)", 0x2121, 1, []),
    ]

    static func run(writingTo path: String) -> Never {
        var lines = ["Emmental diagnostics", "Input Monitoring: \(InputMonitoring.isGranted ? "granted" : "NOT granted")"]
        var results: [String: String] = [:]

        func query(_ mouse: LogitechMouse) {
            let label = mouse.deviceIndex == HIDPPDevice.directIndex
                ? "direct" : "receiver slot \(mouse.deviceIndex)"
            for (order, read) in reads.enumerated() {
                mouse.describe(feature: read.feature, function: read.function, params: read.params) { reply in
                    results["\(label) \(order)"] = "[\(label)] \(read.name): \(reply)"
                }
            }
        }

        let mice = LogitechMice()
        mice.onMouseAvailable = query
        let (found, blocked) = mice.refresh()
        lines.append("Direct HID++ mice: \(found.count)\(blocked ? " (a device was blocked)" : "")")
        found.forEach(query)

        // Replies arrive on the main run loop; receivers may need a moment to
        // answer for every slot.
        RunLoop.main.run(until: Date().addingTimeInterval(6))

        lines += results.keys.sorted().compactMap { results[$0] }
        let text = lines.joined(separator: "\n") + "\n"
        FileManager.default.createFile(atPath: (path as NSString).expandingTildeInPath, contents: text.data(using: .utf8))
        exit(0)
    }
}
