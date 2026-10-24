import AppKit

/// The controls shown inside the menu: which mouse is connected and a slider
/// for each speed.
final class SpeedMenuView: NSView {
    var onChange: ((_ control: SpeedControl, _ value: Double) -> Void)?

    private let deviceLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private var rows: [SpeedControl: SliderRow] = [:]
    private var deviceNames = ""
    private var battery: Battery?

    init() {
        super.init(frame: .zero)

        deviceLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        deviceLabel.textColor = .secondaryLabelColor
        hintLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [deviceLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(8, after: deviceLabel)
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 20, bottom: 6, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for control in SpeedControl.allCases {
            let row = SliderRow(control: control)
            row.onChange = { [weak self] value in
                self?.refreshHint()
                self?.onChange?(control, value)
            }
            rows[control] = row
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36).isActive = true
            if control == .pointer {
                stack.addArrangedSubview(hintLabel)
                stack.setCustomSpacing(12, after: hintLabel)
            }
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: 260),
        ])
        setFrameSize(fittingSize)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Clears the battery; it arrives separately (and only over HID++) via `setBattery`.
    func update(mice: [Mouse], values: [SpeedControl: Double]) {
        deviceNames = mice.isEmpty ? "No mouse connected" : mice.map(\.name).joined(separator: ", ")
        battery = nil
        refreshDeviceLabel()
        for (control, row) in rows {
            row.update(value: values[control] ?? 1, enabled: !mice.isEmpty)
        }
        refreshHint()
    }

    func setBattery(_ battery: Battery) {
        self.battery = battery
        refreshDeviceLabel()
    }

    /// "MX Master 3S M   [battery] 85%", with the symbol tinted like the text.
    private func refreshDeviceLabel() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let text = NSMutableAttributedString(string: deviceNames, attributes: attributes)
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
        deviceLabel.attributedStringValue = text
    }

    private func refreshHint() {
        let pointer = rows[.pointer]?.value ?? 0
        hintLabel.stringValue = pointer > MouseSpeed.systemPointerMaximum
            ? "Faster than System Settings allows"
            : "System Settings tops out at 3.0"
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

/// A titled slider with its current value on the right.
private final class SliderRow: NSStackView {
    var onChange: ((Double) -> Void)?
    var value: Double { slider.doubleValue }

    private let valueLabel = NSTextField(labelWithString: "")
    private let slider: NSSlider

    init(control: SpeedControl) {
        slider = NSSlider(value: control.range.lowerBound, minValue: control.range.lowerBound,
                          maxValue: control.range.upperBound, target: nil, action: nil)
        super.init(frame: .zero)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right

        slider.numberOfTickMarks = Int(control.range.upperBound - control.range.lowerBound) + 1
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)

        let header = NSStackView(views: [NSTextField(labelWithString: control.title), valueLabel])
        orientation = .vertical
        alignment = .leading
        spacing = 4
        addArrangedSubview(header)
        addArrangedSubview(slider)
        header.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        slider.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(value: Double, enabled: Bool) {
        slider.doubleValue = value
        slider.isEnabled = enabled
        refreshLabel()
    }

    @objc private func sliderChanged() {
        refreshLabel()
        onChange?(slider.doubleValue)
    }

    private func refreshLabel() {
        valueLabel.stringValue = String(format: "%.1f", slider.doubleValue)
    }
}
