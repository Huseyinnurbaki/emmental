import AppKit

/// The controls shown inside the menu: which mouse is connected and a slider
/// for each speed.
final class SpeedMenuView: NSView {
    var onChange: ((_ control: SpeedControl, _ value: Double) -> Void)?

    private let deviceLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private var rows: [SpeedControl: SliderRow] = [:]

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

    func update(mice: [Mouse], values: [SpeedControl: Double]) {
        deviceLabel.stringValue = mice.isEmpty ? "No mouse connected" : mice.map(\.name).joined(separator: ", ")
        for (control, row) in rows {
            row.update(value: values[control] ?? 1, enabled: !mice.isEmpty)
        }
        refreshHint()
    }

    private func refreshHint() {
        let pointer = rows[.pointer]?.value ?? 0
        hintLabel.stringValue = pointer > MouseSpeed.systemPointerMaximum
            ? "Faster than System Settings allows"
            : "System Settings tops out at 3.0"
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
