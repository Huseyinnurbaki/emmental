import AppKit

/// Pointer acceleration in the menu: how much fast movements get boosted, on
/// top of the speed the sensor DPI sets. Reaches past the System Settings cap.
final class AccelerationMenuView: NSStackView {
    var onChange: ((Double) -> Void)?

    private let slider: LabeledSliderView
    private let hint = NSTextField(labelWithString: "")

    init() {
        let range = SpeedControl.pointer.range
        slider = LabeledSliderView(title: "Acceleration", range: range, tickMarks: Int(range.upperBound) + 1,
                                   format: { String(format: "%.1f", $0) })
        super.init(frame: .zero)

        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .tertiaryLabelColor
        slider.onChange = { [weak self] value in
            self?.refreshHint()
            self?.onChange?(value)
        }

        orientation = .vertical
        alignment = .leading
        spacing = 4
        addArrangedSubview(slider)
        addArrangedSubview(hint)
        slider.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(value: Double, enabled: Bool) {
        slider.value = value
        slider.isEnabled = enabled
        refreshHint()
    }

    private func refreshHint() {
        hint.stringValue = slider.value > MouseSpeed.systemPointerMaximum
            ? "Past what System Settings allows"
            : "System Settings tops out at 3.0"
    }
}
