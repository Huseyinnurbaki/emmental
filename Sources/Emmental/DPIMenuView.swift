import AppKit

/// Speed in the menu, which is the sensor DPI. DPI lives on the mouse and is
/// set over HID++, which needs Input Monitoring, so this starts switched off
/// and walks the user through granting access before showing the slider.
final class DPIMenuView: NSStackView {
    enum State {
        case off, needsPermission, needsRelaunch, noMouse
        /// `dpi` is nil while the current value is still being read from the mouse.
        case ready(dpi: Int?, range: DPIRange)
    }

    enum Action { case turnOn, openSettings, relaunch }

    var onChange: ((Int) -> Void)?
    var onAction: ((Action) -> Void)?
    /// Called when the view's height changes, so its menu item can resize.
    var onResize: (() -> Void)?

    private let slider: LabeledSliderView
    private let title = NSTextField(labelWithString: "Speed")
    private let message = NSTextField(wrappingLabelWithString: "")
    private let button = NSButton(title: "", target: nil, action: nil)
    private var state = State.off

    init() {
        let fallback = DPIRange.fallback
        slider = LabeledSliderView(title: "Speed", range: Double(fallback.min)...Double(fallback.max),
                                   step: Double(fallback.step), format: { "\(Int($0)) DPI" })
        super.init(frame: .zero)

        message.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        message.textColor = .secondaryLabelColor
        message.preferredMaxLayoutWidth = MenuItemContainer.width - 36
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.target = self
        button.action = #selector(buttonClicked)
        slider.onChange = { [weak self] value in self?.onChange?(Int(value)) }

        orientation = .vertical
        alignment = .leading
        spacing = 6
        [title, slider, message, button].forEach(addArrangedSubview)
        slider.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        message.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        show(.off)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show(_ state: State) {
        self.state = state
        var text = ""
        var buttonTitle: String?

        switch state {
        case .off:
            text = "Set your Logitech mouse's speed, see its battery, and tune its scroll wheel. Needs Input Monitoring permission."
            buttonTitle = "Turn on"
        case .needsPermission:
            text = "Allow Emmental in Privacy & Security › Input Monitoring."
            buttonTitle = "Open Input Monitoring"
        case .needsRelaunch:
            text = "Relaunch Emmental to finish turning this on."
            buttonTitle = "Relaunch Emmental"
        case .noMouse:
            text = "No Logitech mouse found."
        case let .ready(dpi, range):
            slider.setRange(Double(range.min)...Double(range.max), step: Double(range.step))
            if let dpi = dpi {
                slider.value = Double(dpi)
            } else {
                slider.showPlaceholder("…")
            }
            slider.isEnabled = dpi != nil
        }

        let isReady: Bool
        if case .ready = state { isReady = true } else { isReady = false }
        // The slider carries its own "Speed" title; other states need the bare one.
        title.isHidden = isReady
        slider.isHidden = !isReady
        message.stringValue = text
        message.isHidden = text.isEmpty
        button.title = buttonTitle ?? ""
        button.isHidden = buttonTitle == nil
        onResize?()
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
