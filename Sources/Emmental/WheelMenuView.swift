import AppKit

/// The scroll wheel section: SmartShift (when the wheel switches to free-spin
/// by itself) and high-resolution scrolling. Shown only once HID++ is available.
final class WheelMenuView: NSView {
    var onSmartShiftChange: ((SmartShift) -> Void)?
    var onHighResolutionChange: ((Bool) -> Void)?

    private let smartShiftRow = SwitchRowView(title: "SmartShift")
    private let thresholdLabel = NSTextField(labelWithString: "")
    private let thresholdSlider = NSSlider(value: 10, minValue: Double(SmartShift.thresholdRange.lowerBound),
                                           maxValue: Double(SmartShift.thresholdRange.upperBound), target: nil, action: nil)
    private let thresholdHint = NSTextField(wrappingLabelWithString: "Lower switches with a gentler flick")
    private let highResolutionRow = SwitchRowView(title: "High-resolution scrolling")
    private let highResolutionHint = NSTextField(wrappingLabelWithString: "Experimental: may scroll much faster")

    init() {
        super.init(frame: .zero)

        for hint in [thresholdHint, highResolutionHint] {
            hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            hint.textColor = .tertiaryLabelColor
            // Wrap inside the row width rather than widening the menu.
            hint.preferredMaxLayoutWidth = 224
        }
        thresholdLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        thresholdLabel.textColor = .secondaryLabelColor
        thresholdLabel.alignment = .right
        thresholdSlider.isContinuous = true
        thresholdSlider.target = self
        thresholdSlider.action = #selector(smartShiftChanged)
        smartShiftRow.onToggle = { [weak self] _ in self?.smartShiftChanged() }
        highResolutionRow.onToggle = { [weak self] isOn in self?.onHighResolutionChange?(isOn) }

        let thresholdHeader = NSStackView(views: [NSTextField(labelWithString: "Free-spin threshold"), thresholdLabel])
        let stack = NSStackView(views: [smartShiftRow, thresholdHeader, thresholdSlider, thresholdHint,
                                        highResolutionRow, highResolutionHint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(10, after: smartShiftRow)
        stack.setCustomSpacing(12, after: thresholdHint)
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 20, bottom: 6, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        var constraints = [
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: 260),
        ]
        constraints += [smartShiftRow, thresholdHeader, thresholdSlider, thresholdHint,
                        highResolutionRow, highResolutionHint].map {
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        }
        NSLayoutConstraint.activate(constraints)
        showHighResolution(nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func showSmartShift(_ smartShift: SmartShift) {
        smartShiftRow.isOn = smartShift.autoSwitch
        thresholdSlider.integerValue = smartShift.threshold
        refreshThreshold()
    }

    /// nil hides the row, for mice without a high-resolution wheel.
    func showHighResolution(_ enabled: Bool?) {
        highResolutionRow.isHidden = enabled == nil
        highResolutionHint.isHidden = enabled == nil
        highResolutionRow.isOn = enabled ?? false
        setFrameSize(fittingSize)
    }

    @objc private func smartShiftChanged() {
        refreshThreshold()
        onSmartShiftChange?(SmartShift(autoSwitch: smartShiftRow.isOn, threshold: thresholdSlider.integerValue))
    }

    private func refreshThreshold() {
        thresholdSlider.integerValue = Int(thresholdSlider.doubleValue.rounded())
        thresholdLabel.stringValue = String(thresholdSlider.integerValue)
        thresholdSlider.isEnabled = smartShiftRow.isOn
    }
}
