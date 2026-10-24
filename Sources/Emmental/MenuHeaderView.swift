import AppKit

/// The menu's first line: the connected mouse and, when HID++ can read it, its
/// battery, e.g. "MX Master 3S M   [battery] 85%".
final class MenuHeaderView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var names = ""
    private var battery: Battery?

    init() {
        super.init(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Clears the battery; it arrives separately (and only over HID++) via `setBattery`.
    func update(mice: [Mouse]) {
        names = mice.isEmpty ? "No mouse connected" : mice.map(\.name).joined(separator: ", ")
        battery = nil
        refresh()
    }

    func setBattery(_ battery: Battery) {
        self.battery = battery
        refresh()
    }

    private func refresh() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let text = NSMutableAttributedString(string: names, attributes: attributes)
        if let battery = battery {
            text.append(NSAttributedString(string: "   ", attributes: attributes))
            let config = NSImage.SymbolConfiguration(pointSize: NSFont.smallSystemFontSize, weight: .regular)
                .applying(.init(paletteColors: [.secondaryLabelColor]))
            if let symbol = NSImage(systemSymbolName: battery.symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                let attachment = NSTextAttachment()
                attachment.image = symbol
                attachment.bounds = CGRect(x: 0, y: -2, width: symbol.size.width, height: symbol.size.height)
                text.append(NSAttributedString(attachment: attachment))
            }
            text.append(NSAttributedString(string: " \(battery.percent)%", attributes: attributes))
        }
        label.attributedStringValue = text
    }
}

private extension Battery {
    var symbolName: String {
        if isCharging { return "battery.100.bolt" }
        switch percent {
        case 88...: return "battery.100"
        case 63...: return "battery.75"
        case 38...: return "battery.50"
        case 13...: return "battery.25"
        default: return "battery.0"
        }
    }
}
