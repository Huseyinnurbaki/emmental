import AppKit

/// A title with the current value beside it and a slider underneath. Used in
/// the menu and the Settings window. The caller sets its width.
final class LabeledSliderView: NSStackView {
    var onChange: ((Double) -> Void)?

    var value: Double {
        get { slider.doubleValue }
        set {
            slider.doubleValue = newValue
            refreshLabel()
        }
    }

    var isEnabled: Bool {
        get { slider.isEnabled }
        set { slider.isEnabled = newValue }
    }

    private let valueLabel = NSTextField(labelWithString: "")
    private let slider: NSSlider
    private var step: Double?
    private let format: (Double) -> String

    /// `step` snaps dragged values (for example 50 for DPI); `tickMarks` draws
    /// that many evenly spaced marks under the slider.
    init(title: String, range: ClosedRange<Double>, tickMarks: Int = 0, step: Double? = nil,
         format: @escaping (Double) -> String) {
        slider = NSSlider(value: range.lowerBound, minValue: range.lowerBound, maxValue: range.upperBound,
                          target: nil, action: nil)
        self.step = step
        self.format = format
        super.init(frame: .zero)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        slider.numberOfTickMarks = tickMarks
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)

        let header = NSStackView(views: [NSTextField(labelWithString: title), valueLabel])
        orientation = .vertical
        alignment = .leading
        spacing = 4
        addArrangedSubview(header)
        addArrangedSubview(slider)
        header.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        slider.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        refreshLabel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setRange(_ range: ClosedRange<Double>, step: Double? = nil) {
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        if let step = step { self.step = step }
    }

    /// Shown in place of a value that's still loading, e.g. "…".
    func showPlaceholder(_ text: String) {
        valueLabel.stringValue = text
    }

    @objc private func sliderChanged() {
        if let step = step {
            slider.doubleValue = (slider.doubleValue / step).rounded() * step
        }
        refreshLabel()
        onChange?(slider.doubleValue)
    }

    private func refreshLabel() {
        valueLabel.stringValue = format(slider.doubleValue)
    }
}
