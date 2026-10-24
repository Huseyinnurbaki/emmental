import AppKit

/// The controls shown inside the menu: which mouse is connected and a speed
/// slider that reaches past the System Settings maximum.
final class SpeedMenuView: NSView {
    var onChange: ((_ speed: Double) -> Void)?

    private let deviceLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private let slider = NSSlider(value: 1, minValue: MouseSpeed.range.lowerBound,
                                  maxValue: MouseSpeed.range.upperBound, target: nil, action: nil)

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 104))

        deviceLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        deviceLabel.textColor = .secondaryLabelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        hintLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.textColor = .tertiaryLabelColor

        slider.numberOfTickMarks = Int(MouseSpeed.range.upperBound) + 1
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)

        let speedRow = NSStackView(views: [NSTextField(labelWithString: "Pointer speed"), valueLabel])

        let stack = NSStackView(views: [deviceLabel, speedRow, slider, hintLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(8, after: deviceLabel)
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 20, bottom: 6, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            speedRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            slider.widthAnchor.constraint(equalTo: speedRow.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(mice: [Mouse], speed: Double) {
        deviceLabel.stringValue = mice.isEmpty ? "No mouse connected" : mice.map(\.name).joined(separator: ", ")
        slider.doubleValue = speed
        slider.isEnabled = !mice.isEmpty
        refreshLabels()
    }

    @objc private func sliderChanged() {
        refreshLabels()
        onChange?(slider.doubleValue)
    }

    private func refreshLabels() {
        valueLabel.stringValue = String(format: "%.1f", slider.doubleValue)
        hintLabel.stringValue = slider.doubleValue > MouseSpeed.systemMaximum
            ? "Faster than System Settings allows"
            : "System Settings tops out at 3.0"
    }
}
