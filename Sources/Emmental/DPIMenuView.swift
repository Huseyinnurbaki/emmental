import AppKit

/// The DPI section of the menu. DPI lives on the mouse and is set over HID++,
/// which needs Input Monitoring, so the section starts switched off and walks
/// the user through granting access before showing the slider.
final class DPIMenuView: NSView {
    enum State {
        case off, needsPermission, needsRelaunch, noMouse
        /// `dpi` is nil while the current value is still being read from the mouse.
        case ready(dpi: Int?, range: DPIRange)
    }

    enum Action { case turnOn, openSettings, relaunch }

    var onChange: ((Int) -> Void)?
    var onAction: ((Action) -> Void)?

    private let valueLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let button = NSButton(title: "", target: nil, action: nil)
    private let slider = NSSlider(value: 1000, minValue: 200, maxValue: 8000, target: nil, action: nil)
    private var state = State.off
    private var step = DPIRange.fallback.step

    init() {
        super.init(frame: .zero)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        messageLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.preferredMaxLayoutWidth = 224
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.target = self
        button.action = #selector(buttonClicked)
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)

        let header = NSStackView(views: [NSTextField(labelWithString: "Sensor DPI"), valueLabel])
        let stack = NSStackView(views: [header, slider, messageLabel, button])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 20, bottom: 6, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: 260),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            slider.widthAnchor.constraint(equalTo: header.widthAnchor),
            messageLabel.widthAnchor.constraint(equalTo: header.widthAnchor),
        ])
        show(.off)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show(_ state: State) {
        self.state = state
        var message = ""
        var buttonTitle: String?
        var dpi: Int?

        switch state {
        case .off:
            message = "Change your Logitech mouse's sensor speed and see its battery. Needs Input Monitoring permission."
            buttonTitle = "Turn on DPI control"
        case .needsPermission:
            message = "Allow Emmental in Privacy & Security › Input Monitoring."
            buttonTitle = "Open Input Monitoring"
        case .needsRelaunch:
            message = "Relaunch Emmental to finish turning on DPI control."
            buttonTitle = "Relaunch Emmental"
        case .noMouse:
            message = "No Logitech mouse found."
        case let .ready(current, range):
            dpi = current
            step = range.step
            slider.minValue = Double(range.min)
            slider.maxValue = Double(range.max)
            if let current = current { slider.doubleValue = Double(current) }
        }

        let isReady: Bool
        if case .ready = state { isReady = true } else { isReady = false }
        slider.isHidden = !isReady
        slider.isEnabled = dpi != nil
        valueLabel.stringValue = isReady ? (dpi.map(String.init) ?? "…") : ""
        messageLabel.stringValue = message
        messageLabel.isHidden = message.isEmpty
        button.title = buttonTitle ?? ""
        button.isHidden = buttonTitle == nil
        setFrameSize(fittingSize)
    }

    @objc private func sliderChanged() {
        let dpi = Int((slider.doubleValue / Double(step)).rounded()) * step
        slider.doubleValue = Double(dpi)
        valueLabel.stringValue = String(dpi)
        onChange?(dpi)
    }

    @objc private func buttonClicked() {
        enclosingMenuItem?.menu?.cancelTracking()
        switch state {
        case .off: onAction?(.turnOn)
        case .needsPermission: onAction?(.openSettings)
        case .needsRelaunch: onAction?(.relaunch)
        case .noMouse, .ready: break
        }
    }
}
